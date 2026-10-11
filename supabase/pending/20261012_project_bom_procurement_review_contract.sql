-- SOURCE-ONLY, UNDEPLOYED PROPOSAL. DO NOT APPLY.
--
-- This additive contract creates a protected Procurement analysis request from
-- a committed project BOM. It never creates or edits components, BOM rows,
-- stock, locations, substitutes, purchase orders, sourcing records, or a
-- released/approved BOM. "ALLOW_FOR_HARDWARE_SELECTION" is not a technical
-- approval or procurement order authorization.
--
-- Prerequisite: the separately reviewed project/BOM submission predicate must
-- be accepted for this installation. The caller owns no submitted values other
-- than the selected existing component IDs, new-part details, quantities,
-- references, and manual notes. Component MPN/manufacturer are re-read from
-- the authorized catalog while the BOM is locked.

CREATE TABLE public.project_bom_procurement_review_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.projects(id) ON DELETE RESTRICT,
  project_bom_id uuid NOT NULL REFERENCES public.project_boms(id) ON DELETE RESTRICT,
  pinned_bom_number text NOT NULL,
  pinned_bom_revision text NULL,
  status text NOT NULL DEFAULT 'PENDING_PROCUREMENT_ANALYSIS'
    CHECK (status IN ('PENDING_PROCUREMENT_ANALYSIS', 'ALLOWED_PENDING_HARDWARE_SELECTION', 'DENIED')),
  submitted_by uuid NOT NULL,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  decided_by uuid NULL,
  decided_at timestamptz NULL,
  decision_note text NULL,
  CHECK (
    (status = 'PENDING_PROCUREMENT_ANALYSIS' AND decided_by IS NULL AND decided_at IS NULL AND decision_note IS NULL)
    OR (status IN ('ALLOWED_PENDING_HARDWARE_SELECTION', 'DENIED') AND decided_by IS NOT NULL AND decided_at IS NOT NULL AND char_length(btrim(decision_note)) BETWEEN 1 AND 500)
  )
);
GRANT SELECT ON public.project_bom_procurement_review_requests TO authenticated;
GRANT ALL ON public.project_bom_procurement_review_requests TO service_role;
ALTER TABLE public.project_bom_procurement_review_requests ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.project_bom_procurement_review_request_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.project_bom_procurement_review_requests(id) ON DELETE RESTRICT,
  line_number integer NOT NULL CHECK (line_number > 0),
  source_kind text NOT NULL CHECK (source_kind IN ('EXISTING_COMPONENT', 'NEW_PART')),
  component_id uuid NULL REFERENCES public.components(id) ON DELETE RESTRICT,
  mpn text NOT NULL,
  manufacturer text NULL,
  description text NOT NULL,
  reference_designators text NOT NULL,
  quantity numeric NOT NULL CHECK (quantity > 0),
  manual_note text NULL,
  UNIQUE (request_id, line_number),
  CHECK ((source_kind = 'EXISTING_COMPONENT' AND component_id IS NOT NULL) OR (source_kind = 'NEW_PART' AND component_id IS NULL))
);
GRANT SELECT ON public.project_bom_procurement_review_request_lines TO authenticated;
GRANT ALL ON public.project_bom_procurement_review_request_lines TO service_role;
ALTER TABLE public.project_bom_procurement_review_request_lines ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.project_bom_procurement_review_analyses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_line_id uuid NOT NULL UNIQUE REFERENCES public.project_bom_procurement_review_request_lines(id) ON DELETE RESTRICT,
  availability_state text NOT NULL CHECK (availability_state IN ('PENDING', 'AVAILABLE', 'UNAVAILABLE', 'TBC')),
  cost_state text NOT NULL CHECK (cost_state IN ('PENDING', 'AVAILABLE', 'UNAVAILABLE', 'TBC')),
  sourcing_state text NOT NULL CHECK (sourcing_state IN ('PENDING', 'AVAILABLE', 'UNAVAILABLE', 'TBC')),
  observed_unit_cost numeric NULL CHECK (observed_unit_cost >= 0),
  currency text NULL CHECK (currency IS NULL OR char_length(btrim(currency)) BETWEEN 3 AND 12),
  supplier_name text NULL,
  lead_time_days integer NULL CHECK (lead_time_days >= 0),
  alternate_component_id uuid NULL REFERENCES public.components(id) ON DELETE RESTRICT,
  analysis_note text NOT NULL CHECK (char_length(btrim(analysis_note)) BETWEEN 1 AND 1000),
  analyzed_by uuid NOT NULL,
  analyzed_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.project_bom_procurement_review_analyses TO authenticated;
GRANT ALL ON public.project_bom_procurement_review_analyses TO service_role;
ALTER TABLE public.project_bom_procurement_review_analyses ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.project_bom_procurement_review_receipts (
  request_key uuid PRIMARY KEY,
  requested_by uuid NOT NULL,
  action text NOT NULL CHECK (action IN ('SUBMIT', 'ANALYZE', 'ALLOW', 'DENY')),
  request_id uuid NOT NULL REFERENCES public.project_bom_procurement_review_requests(id) ON DELETE RESTRICT,
  payload_hash text NOT NULL CHECK (btrim(payload_hash) <> ''),
  result jsonb NOT NULL CHECK (jsonb_typeof(result) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.project_bom_procurement_review_receipts TO service_role;
GRANT ALL ON public.project_bom_procurement_review_receipts TO service_role;
ALTER TABLE public.project_bom_procurement_review_receipts ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.project_bom_procurement_review_audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.project_bom_procurement_review_requests(id) ON DELETE RESTRICT,
  event_type text NOT NULL CHECK (event_type IN ('SUBMITTED', 'ANALYZED', 'ALLOWED_PENDING_HARDWARE_SELECTION', 'DENIED')),
  actor_user_id uuid NOT NULL,
  event_data jsonb NOT NULL CHECK (jsonb_typeof(event_data) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.project_bom_procurement_review_audit_events TO service_role;
GRANT ALL ON public.project_bom_procurement_review_audit_events TO service_role;
ALTER TABLE public.project_bom_procurement_review_audit_events ENABLE ROW LEVEL SECURITY;

-- Intended protected function signatures. All take the actor from auth.uid(),
-- lock project -> BOM -> request key, authorize before replay and immediately
-- before write, re-check the pinned BOM number/revision, and append audit plus
-- receipt atomically. EXECUTE remains intentionally ungranted until separate
-- caller-authenticated acceptance has proved the scopes below.
--
-- submit_project_bom_procurement_review(
--   p_project_id uuid, p_project_bom_id uuid, p_expected_bom_revision text,
--   p_rows jsonb, p_request_key uuid)
--   Project manager + active project-team member only. Existing component IDs
--   are RLS-visible and their MPN/manufacturer are server-derived; a new part
--   needs non-empty MPN and description. Quantity/reference/manual-note are
--   canonicalized. No caller cost, availability, supplier, alternate, or
--   lead-time value is accepted.
--
-- analyze_project_bom_procurement_review(
--   p_request_id uuid, p_request_line_id uuid, p_analysis jsonb,
--   p_request_key uuid)
--   Active Purchase department employee with procurement.manage only. The line
--   must belong to a pending request in the reviewer’s active project scope.
--   Analysis records MPN-focused availability, cost, sourcing, lead time, and
--   explicit alternate component ID, where unknown is PENDING/TBC/UNAVAILABLE
--   rather than zero or implied availability.
--
-- decide_project_bom_procurement_review(
--   p_request_id uuid, p_expected_bom_revision text, p_decision text,
--   p_decision_note text, p_request_key uuid)
--   Same scoped Procurement authority only. ALLOW requires an analysis row for
--   every submitted line; DENY may occur while analysis is incomplete. The
--   result is only an allowed handoff to a separately authorized Hardware
--   selection contract. It never selects a technical part, creates inventory,
--   mutates a BOM, creates an order, reserves stock, or releases anything.

-- Intended caller read policies (all TO authenticated, exact project scope):
-- submitter/project manager may read own requests and immutable lines; assigned
-- Procurement reviewers may read pending request/line/analysis data; Hardware
-- receives only ALLOWED_PENDING_HARDWARE_SELECTION projections. Receipts and
-- audit actor internals remain private. No anon policy is permitted.
--
-- Intended ACL hardening before any grant:
-- REVOKE ALL ON FUNCTION public.submit_project_bom_procurement_review(uuid, uuid, text, jsonb, uuid) FROM PUBLIC, anon, authenticated, service_role;
-- REVOKE ALL ON FUNCTION public.analyze_project_bom_procurement_review(uuid, uuid, jsonb, uuid) FROM PUBLIC, anon, authenticated, service_role;
-- REVOKE ALL ON FUNCTION public.decide_project_bom_procurement_review(uuid, text, text, text, uuid) FROM PUBLIC, anon, authenticated, service_role;
-- Grant EXECUTE only after accepted authenticated caller tests prove project
-- manager submission, Procurement reviewer allow/deny, unauthorized denial,
-- stale-BOM denial, exact replay, changed replay conflict, revoke-after-wait,
-- and all-or-nothing rollback.
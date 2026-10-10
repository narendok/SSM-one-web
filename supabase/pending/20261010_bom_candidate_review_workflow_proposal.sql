-- REVIEW-ONLY, UNAPPLIED CONTRACT PROPOSAL.
-- Do not run this file. It intentionally contains no GRANT, RLS-policy,
-- permission-seed, or executable mutation definition. Existing
-- public.saveComponentWithStock remains unchanged.

/*
AUTHORITATIVE BOUNDARY
1. Existing inventory selection remains the established components SELECT path.
2. New-part submission begins only from an authorized sales opportunity and an
   immutable authorized master_specification_versions row. A committed project
   is optional at submission time and is never inferred.
3. A later project link is separate and proves project.opportunity_id equals the
   candidate opportunity. No title, BOM, name, or null department is evidence.
4. Promotion is the sole path to components and uses a narrow zero-stock adapter;
   it must not invoke stock, location, project-link, substitute, or provenance
   side effects from saveComponentWithStock.
*/

-- Proposed submitted modular ComponentFormDialog snapshot: category_id, name,
-- part_number, manufacturer, footprint, BOM compatibility, ratings, unit_cost,
-- currency, supplier, URLs, and notes. It excludes assumed package, quantity,
-- lead time, stock, sourcing, qualification, and project linkage.
CREATE TABLE public.component_candidates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  opportunity_id uuid NOT NULL REFERENCES public.sales_opportunities(id) ON DELETE RESTRICT,
  master_specification_version_id uuid NOT NULL REFERENCES public.master_specification_versions(id) ON DELETE RESTRICT,
  project_id uuid NULL REFERENCES public.projects(id) ON DELETE RESTRICT,
  status text NOT NULL,
  candidate_revision integer NOT NULL DEFAULT 1,
  candidate_payload jsonb NOT NULL,
  submitted_by uuid NOT NULL,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  linked_project_by uuid NULL,
  linked_project_at timestamptz NULL,
  promoted_component_id uuid NULL REFERENCES public.components(id) ON DELETE RESTRICT,
  promoted_at timestamptz NULL,
  UNIQUE (id, candidate_revision)
);
-- Proposed states only: PENDING_HARDWARE_REVIEW, REJECTED,
-- APPROVED_PENDING_PURCHASE, COST_AMENDED_REQUIRES_HARDWARE_REVIEW,
-- APPROVED_FOR_PROMOTION, PROMOTED. They are not seeded or enabled here.

-- Hardware decisions are append-only. An alternative is an explicit existing
-- component or candidate ID, never a fuzzy name/description match.
CREATE TABLE public.component_candidate_decisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id uuid NOT NULL REFERENCES public.component_candidates(id) ON DELETE RESTRICT,
  candidate_revision integer NOT NULL,
  decision text NOT NULL,
  alternative_component_id uuid NULL REFERENCES public.components(id) ON DELETE RESTRICT,
  alternative_candidate_id uuid NULL REFERENCES public.component_candidates(id) ON DELETE RESTRICT,
  rationale text NOT NULL,
  decided_by uuid NOT NULL,
  decided_at timestamptz NOT NULL DEFAULT now()
);

-- Purchase amendments append currency, unit cost, cost unit, BOM quantity, and
-- the server-read commercial provenance. Amendment invalidates prior approval;
-- it does not mutate or delete earlier decision history.
CREATE TABLE public.component_candidate_cost_amendments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id uuid NOT NULL REFERENCES public.component_candidates(id) ON DELETE RESTRICT,
  candidate_revision integer NOT NULL,
  currency text NOT NULL,
  unit_cost numeric NOT NULL,
  cost_unit text NOT NULL,
  bom_quantity numeric NOT NULL,
  projected_volume numeric NULL,
  commercial_record_id uuid NULL REFERENCES public.sales_commercial_records(id) ON DELETE RESTRICT,
  commercial_revision_number integer NULL,
  submitted_by uuid NOT NULL,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  supersedes_amendment_id uuid NULL REFERENCES public.component_candidate_cost_amendments(id) ON DELETE RESTRICT
);

-- Server-owned evaluation persists unavailable reasons rather than treating
-- missing commercial/volume/currency/unit/quantity inputs as within ceiling.
CREATE TABLE public.component_candidate_cost_evaluations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id uuid NOT NULL REFERENCES public.component_candidates(id) ON DELETE RESTRICT,
  cost_amendment_id uuid NOT NULL REFERENCES public.component_candidate_cost_amendments(id) ON DELETE RESTRICT,
  evaluation_state text NOT NULL,
  currency text NULL,
  per_unit_bom_cost numeric NULL,
  projected_full_bom_cost numeric NULL,
  commercial_ceiling numeric NULL,
  commercial_record_id uuid NULL REFERENCES public.sales_commercial_records(id) ON DELETE RESTRICT,
  commercial_revision_number integer NULL,
  unavailable_reasons jsonb NOT NULL,
  evaluated_at timestamptz NOT NULL DEFAULT now()
);
-- Proposed states only: AVAILABLE_WITHIN_CEILING, AVAILABLE_OVER_CEILING,
-- UNAVAILABLE. Browser-supplied totals and ceilings are not accepted.

-- Private replay receipts and append-only audit; future RLS must not expose
-- internals directly to callers.
CREATE TABLE public.component_candidate_request_receipts (
  request_key uuid PRIMARY KEY,
  requested_by uuid NOT NULL,
  action text NOT NULL,
  candidate_id uuid NOT NULL REFERENCES public.component_candidates(id) ON DELETE RESTRICT,
  payload_hash text NOT NULL,
  result_snapshot jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.component_candidate_audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id uuid NOT NULL REFERENCES public.component_candidates(id) ON DELETE RESTRICT,
  candidate_revision integer NOT NULL,
  event_type text NOT NULL,
  actor_user_id uuid NOT NULL,
  event_data jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

/*
PLANNED PROTECTED OPERATIONS — DESCRIPTIVE ONLY, NOT CALLABLE APIS

submit_component_candidate(opportunity_id, master_version_id, payload,
  expected_source_fingerprint, request_key)
  - Authorize and lock the exact opportunity/version before receipt replay.
  - Canonicalize allowed modular fields. Duplicate-match exact normalized
    manufacturer+MPN, then exact approved internal part number. Return an
    RLS-visible reference for deliberate choice; never auto-merge or replace
    fuzzy name/description/footprint similarity.

link_component_candidate_to_project(candidate_id, project_id, expected_revision,
  request_key)
  - Authorize/lock candidate and committed project; prove identical opportunity;
    reject null, unrelated, stale, or archived source state; audit the link.

amend_component_candidate_cost(candidate_id, expected_revision, cost input,
  request_key)
  - Purchase-scoped only after verified project link and Hardware approval.
  - Server reads verified Sales projected volume plus commercial ceiling/version;
    caller cannot supply either. Per-unit BOM cost = unit_cost × BOM_quantity
    after explicit compatible-unit conversion; full projected BOM cost equals
    per-unit BOM cost × projected_volume. Missing/unknown data is UNAVAILABLE.
  - Append amendment/evaluation/audit and require a new Hardware decision.

decide_component_candidate(candidate_id, expected_revision, decision,
  rationale, explicit_alternative_id, request_key)
  - Hardware-scoped active membership and self-review denial; append decision,
    never overwrite; stale revision is a conflict, not a replacement.

promote_component_candidate(candidate_id, expected_revision, request_key)
  - Lock candidate, exact decision, duplicate source, and receipt; require an
    explicit project link and valid final approval. Call a new narrow component
    adapter exactly once with zero stock and no location/project/substitute/
    provenance side effects; persist component ID, receipt, and audit together.
*/

/*
REQUIRED FUTURE AUTHORIZATION / THREAT BOUNDARIES
- Direct workflow writes denied by default; read queues are security-invoker
  projections with caller RLS. No implicit grants, privileged browser client,
  service key, new department, notification, or storage write is proposed.
- Exact permission keys and Hardware/Purchase membership proof are unresolved
  dependencies. This document neither creates nor assigns them.
- Authorize before receipt lookup; receipt hash covers normalized source IDs,
  expected revision, currency, units, quantity, and alternative reference.
- Stable lock order: source → candidate → current commercial revision → receipt.
  Fail closed for stale/unknown source, duplicate ambiguity, and cost inputs.
*/
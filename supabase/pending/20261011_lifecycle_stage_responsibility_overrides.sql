-- SOURCE-ONLY, UNDEPLOYED PROPOSAL. DO NOT APPLY.
-- Persistent responsibility overrides are distinct from project stage status,
-- template generation, task assignment, handover execution, approval, release,
-- notifications, and document control. This proposal only records a project- and
-- stage-scoped planning responsibility revision after its protected contract is accepted.

CREATE TABLE public.project_stage_responsibility_overrides (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.projects(id) ON DELETE RESTRICT,
  project_stage_record_id uuid NOT NULL REFERENCES public.project_process_stage_records(id) ON DELETE RESTRICT,
  company_process_stage_id uuid NOT NULL REFERENCES public.company_process_stages(id) ON DELETE RESTRICT,
  revision_number integer NOT NULL CHECK (revision_number = 1),
  lead_department_id uuid NOT NULL REFERENCES public.departments(id) ON DELETE RESTRICT,
  coordinating_department_id uuid REFERENCES public.departments(id) ON DELETE RESTRICT,
  participating_department_ids uuid[] NOT NULL DEFAULT '{}'::uuid[],
  source_stage_updated_at timestamptz NOT NULL,
  requested_by uuid NOT NULL,
  requested_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (project_stage_record_id, revision_number)
);
GRANT SELECT ON public.project_stage_responsibility_overrides TO service_role;
ALTER TABLE public.project_stage_responsibility_overrides ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.project_stage_responsibility_override_audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  responsibility_override_id uuid NOT NULL REFERENCES public.project_stage_responsibility_overrides(id) ON DELETE RESTRICT,
  event_type text NOT NULL CHECK (event_type = 'RESPONSIBILITY_OVERRIDE_RECORDED'),
  actor_user_id uuid NOT NULL,
  event_data jsonb NOT NULL CHECK (jsonb_typeof(event_data) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.project_stage_responsibility_override_audit_events TO service_role;
ALTER TABLE public.project_stage_responsibility_override_audit_events ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.project_stage_responsibility_override_request_receipts (
  request_key uuid PRIMARY KEY,
  requested_by uuid NOT NULL,
  payload_hash text NOT NULL CHECK (btrim(payload_hash) <> ''),
  responsibility_override_id uuid NOT NULL REFERENCES public.project_stage_responsibility_overrides(id) ON DELETE RESTRICT,
  result jsonb NOT NULL CHECK (jsonb_typeof(result) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.project_stage_responsibility_override_request_receipts TO service_role;
ALTER TABLE public.project_stage_responsibility_override_request_receipts ENABLE ROW LEVEL SECURITY;

CREATE INDEX project_stage_responsibility_overrides_project_stage_idx
  ON public.project_stage_responsibility_overrides(project_id, project_stage_record_id);

-- Future protected routine requirements, intentionally non-executable here:
-- 1. derive actor from auth.uid(), then lock project -> project-stage record -> request receipt;
-- 2. authorize exact project and owning-department scope before looking up a receipt and repeat after locks;
-- 3. require the stage row to match project/company-stage IDs and expected updated_at exactly;
-- 4. require active, distinct department IDs with all participating IDs deduplicated and project-independent;
-- 5. hash canonical IDs, expected revision, exact department set, and derived actor;
-- 6. replay only the same actor/hash request key; reject any changed actor or payload;
-- 7. insert override, immutable audit, and receipt atomically;
-- 8. never update project_process_stage_records owner/reviewer/status/handover/evidence/completion,
--    project_tasks, sales_project_handovers, templates, notifications, or approval/release records.

REVOKE ALL ON TABLE public.project_stage_responsibility_overrides FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.project_stage_responsibility_override_audit_events FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.project_stage_responsibility_override_request_receipts FROM PUBLIC, anon, authenticated;
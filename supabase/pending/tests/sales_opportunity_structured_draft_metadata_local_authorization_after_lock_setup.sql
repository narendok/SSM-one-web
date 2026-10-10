-- LOCAL DISPOSABLE AUTHORIZATION-AFTER-LOCK FIXTURE ONLY.
\set ON_ERROR_STOP on

CREATE TABLE public.structured_draft_authorization_after_lock_control (
  singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
  holder_ready boolean NOT NULL DEFAULT false,
  released boolean NOT NULL DEFAULT false
);

CREATE TABLE public.structured_draft_authorization_after_lock_results (
  case_name text PRIMARY KEY CHECK (case_name IN ('new_write', 'receipt_replay')),
  outcome text NOT NULL CHECK (outcome IN ('returned', 'error')),
  sqlstate text,
  message text,
  draft_id uuid,
  revision_id uuid,
  revision_number integer,
  replayed boolean,
  CHECK ((outcome = 'returned') = (draft_id IS NOT NULL AND revision_id IS NOT NULL AND revision_number IS NOT NULL AND replayed IS NOT NULL))
);

INSERT INTO public.structured_draft_authorization_after_lock_control (singleton) VALUES (true);

SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', false);
SELECT set_config('request.jwt.claim.role', 'authenticated', false);

-- Seed only the existing-receipt replay case while the fixture actor is authorized.
CREATE TABLE public.structured_draft_authorization_after_lock_seed AS
SELECT * FROM public.save_sales_opportunity_structured_draft_revision(
  '00000000-0000-4000-8000-000000000201',
  '00000000-0000-4000-8000-000000000101',
  '00000000-0000-4000-8000-000000000301',
  '00000000-0000-4000-8000-000000000401',
  'SOR', 0,
  '{"SCOPE_STATEMENT":"Replay seed scope","ACCEPTANCE_CRITERIA":"Replay seed acceptance"}'::jsonb,
  '00000000-0000-4000-8000-000000000801'
);

CREATE TABLE public.structured_draft_authorization_after_lock_snapshot AS
SELECT jsonb_build_object(
  'drafts', coalesce((SELECT jsonb_agg(to_jsonb(draft) ORDER BY draft.id) FROM public.sales_opportunity_structured_drafts AS draft), '[]'::jsonb),
  'revisions', coalesce((SELECT jsonb_agg(to_jsonb(revision) ORDER BY revision.draft_id, revision.revision_number) FROM public.sales_opportunity_structured_draft_revisions AS revision), '[]'::jsonb),
  'requests', coalesce((SELECT jsonb_agg(to_jsonb(request_receipt) ORDER BY request_receipt.request_key) FROM public.sales_opportunity_structured_draft_requests AS request_receipt), '[]'::jsonb)
) AS contents;

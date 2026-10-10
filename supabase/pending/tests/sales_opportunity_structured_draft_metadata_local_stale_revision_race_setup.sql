-- LOCAL DISPOSABLE TWO-WORKER STALE-REVISION RACE FIXTURE ONLY.
\set ON_ERROR_STOP on

CREATE TABLE public.structured_draft_stale_revision_race_control (
  singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
  holder_ready boolean NOT NULL DEFAULT false,
  released boolean NOT NULL DEFAULT false
);

CREATE TABLE public.structured_draft_stale_revision_race_results (
  worker_label text PRIMARY KEY CHECK (worker_label IN ('winner', 'loser')),
  outcome text NOT NULL CHECK (outcome IN ('returned', 'error')),
  sqlstate text,
  message text,
  draft_id uuid,
  revision_id uuid,
  revision_number integer,
  replayed boolean,
  CHECK ((outcome = 'returned') = (draft_id IS NOT NULL AND revision_id IS NOT NULL AND revision_number IS NOT NULL AND replayed IS NOT NULL))
);

INSERT INTO public.structured_draft_stale_revision_race_control (singleton) VALUES (true);

CREATE TABLE public.structured_draft_stale_revision_race_baseline AS
SELECT * FROM public.save_sales_opportunity_structured_draft_revision(
  '00000000-0000-4000-8000-000000000201',
  '00000000-0000-4000-8000-000000000101',
  '00000000-0000-4000-8000-000000000301',
  '00000000-0000-4000-8000-000000000401',
  'SOR', 0,
  '{"SCOPE_STATEMENT":"Original scope","ACCEPTANCE_CRITERIA":"Original acceptance"}'::jsonb,
  '00000000-0000-4000-8000-000000000611'
);

CREATE TABLE public.structured_draft_stale_revision_race_history AS
SELECT revision.id, revision.draft_id, revision.revision_number, revision.parent_revision_id,
  revision.canonical_payload, revision.payload_hash
FROM public.sales_opportunity_structured_draft_revisions AS revision
JOIN public.structured_draft_stale_revision_race_baseline AS baseline ON baseline.revision_id = revision.id;
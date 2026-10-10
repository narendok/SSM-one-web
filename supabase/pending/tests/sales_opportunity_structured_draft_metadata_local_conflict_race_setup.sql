-- LOCAL DISPOSABLE TWO-WORKER CONFLICT-RACE FIXTURE ONLY.
\set ON_ERROR_STOP on

CREATE TABLE public.structured_draft_conflict_race_control (
  singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
  holder_ready boolean NOT NULL DEFAULT false,
  released boolean NOT NULL DEFAULT false
);

CREATE TABLE public.structured_draft_conflict_race_results (
  case_name text NOT NULL CHECK (case_name IN ('changed_payload', 'different_actor')),
  worker_label text NOT NULL CHECK (worker_label IN ('winner', 'loser')),
  outcome text NOT NULL CHECK (outcome IN ('returned', 'error')),
  sqlstate text,
  message text,
  draft_id uuid,
  revision_id uuid,
  revision_number integer,
  replayed boolean,
  PRIMARY KEY (case_name, worker_label),
  CHECK ((outcome = 'returned') = (draft_id IS NOT NULL AND revision_id IS NOT NULL AND revision_number IS NOT NULL AND replayed IS NOT NULL))
);

INSERT INTO public.structured_draft_conflict_race_control (singleton) VALUES (true);

-- LOCAL DISPOSABLE TWO-WORKER EXACT-REPLAY FIXTURE ONLY.
\set ON_ERROR_STOP on

CREATE TABLE public.structured_draft_exact_replay_race_control (
  singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
  holder_ready boolean NOT NULL DEFAULT false,
  released boolean NOT NULL DEFAULT false
);

CREATE TABLE public.structured_draft_exact_replay_race_results (
  worker_label text PRIMARY KEY CHECK (worker_label IN ('a', 'b')),
  draft_id uuid NOT NULL,
  revision_id uuid NOT NULL,
  revision_number integer NOT NULL,
  replayed boolean NOT NULL
);

INSERT INTO public.structured_draft_exact_replay_race_control (singleton) VALUES (true);
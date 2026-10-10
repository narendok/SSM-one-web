-- LOCAL DISPOSABLE TWO-SESSION RACE FIXTURE ONLY.
\set ON_ERROR_STOP on
INSERT INTO public.sales_test_permissions VALUES
  ('00000000-0000-4000-8000-000000000001', true),
  ('00000000-0000-4000-8000-000000000002', true);
INSERT INTO public.customers VALUES ('00000000-0000-4000-8000-000000000010', 'Disposable customer');
INSERT INTO public.customer_contacts VALUES ('00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000010', true);
INSERT INTO public.sales_enquiries VALUES ('00000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000011');
CREATE TABLE public.sales_intake_race_barriers (
  race_label text PRIMARY KEY,
  expected_workers integer NOT NULL CHECK (expected_workers = 2),
  ready_workers integer NOT NULL DEFAULT 0 CHECK (ready_workers BETWEEN 0 AND 2),
  released boolean NOT NULL DEFAULT false
);
CREATE TABLE public.sales_intake_race_results (
  race_label text NOT NULL REFERENCES public.sales_intake_race_barriers(race_label),
  worker_label text NOT NULL CHECK (worker_label IN ('a', 'b')),
  opportunity_id uuid NOT NULL,
  opportunity_number text NOT NULL,
  master_specification_id uuid NOT NULL,
  master_specification_number text NOT NULL,
  master_specification_version_id uuid NOT NULL,
  master_specification_version_number integer NOT NULL,
  replayed boolean NOT NULL,
  PRIMARY KEY (race_label, worker_label)
);
INSERT INTO public.sales_intake_race_barriers (race_label, expected_workers) VALUES
  ('same_key_same_payload', 2), ('same_key_changed_payload', 2),
  ('same_key_actor_conflict', 2), ('different_keys', 2);
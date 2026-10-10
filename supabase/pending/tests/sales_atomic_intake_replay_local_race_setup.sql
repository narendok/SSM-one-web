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
INSERT INTO public.sales_intake_race_barriers (race_label) VALUES
  ('same_key_same_payload'), ('same_key_changed_payload'), ('same_key_actor_conflict'), ('different_keys');
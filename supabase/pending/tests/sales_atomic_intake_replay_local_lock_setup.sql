-- LOCAL DISPOSABLE LOCK-WAIT/ROLLBACK ACCEPTANCE SETUP ONLY.
\set ON_ERROR_STOP on
INSERT INTO public.sales_test_permissions VALUES
  ('00000000-0000-4000-8000-000000000001', true),
  ('00000000-0000-4000-8000-000000000002', false);
INSERT INTO public.customers VALUES ('00000000-0000-4000-8000-000000000010', 'Disposable customer');
INSERT INTO public.customer_contacts VALUES ('00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000010', true);
INSERT INTO public.sales_enquiries VALUES ('00000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000011');
CREATE TABLE public.sales_intake_lock_wait_cases (
  case_label text PRIMARY KEY,
  request_key uuid NOT NULL UNIQUE,
  holder_ready boolean NOT NULL DEFAULT false,
  ready boolean NOT NULL DEFAULT false,
  released boolean NOT NULL DEFAULT false
);
INSERT INTO public.sales_intake_lock_wait_cases (case_label, request_key) VALUES
  ('new_request', '00000000-0000-4000-8000-000000000201'),
  ('receipt_replay', '00000000-0000-4000-8000-000000000202');

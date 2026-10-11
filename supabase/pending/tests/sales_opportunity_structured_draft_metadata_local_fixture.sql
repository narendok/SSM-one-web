-- LOCAL DISPOSABLE FIXTURE ONLY. Never run against an application database.
-- This models exactly the source tables and authorization helper consumed by
-- the pending structured-draft proposal; it is not a production schema export,
-- managed-RLS proof, or authenticated application-transport test.
\set ON_ERROR_STOP on
BEGIN;
DROP SCHEMA IF EXISTS auth CASCADE;
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
CREATE SCHEMA auth;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
DO $roles$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN CREATE ROLE service_role NOLOGIN; END IF;
END;
$roles$;
GRANT authenticated TO CURRENT_USER;
GRANT USAGE ON SCHEMA public, auth TO authenticated;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
CREATE TABLE public.sales_structured_draft_test_permissions (user_id uuid PRIMARY KEY, sales_manage boolean NOT NULL);
CREATE FUNCTION public.has_permission(p_actor uuid, p_permission text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT p_permission = 'sales.manage' AND EXISTS (
    SELECT 1 FROM public.sales_structured_draft_test_permissions WHERE user_id = p_actor AND sales_manage
  )
$$;
CREATE TABLE public.customers (id uuid PRIMARY KEY, name text NOT NULL);
CREATE TABLE public.sales_opportunities (
  id uuid PRIMARY KEY, customer_id uuid NOT NULL REFERENCES public.customers(id)
);
CREATE TABLE public.master_specifications (
  id uuid PRIMARY KEY, opportunity_id uuid NOT NULL REFERENCES public.sales_opportunities(id),
  customer_id uuid NOT NULL REFERENCES public.customers(id)
);
CREATE TABLE public.master_specification_versions (
  id uuid PRIMARY KEY, specification_id uuid NOT NULL REFERENCES public.master_specifications(id),
  version_number integer NOT NULL, specification_data jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (specification_id, version_number)
);
CREATE TABLE public.drive_nodes (
  id uuid PRIMARY KEY,
  project_id uuid NULL,
  parent_id uuid NULL,
  name text NOT NULL,
  node_type text NOT NULL,
  storage_bucket text NULL,
  storage_path text NULL,
  is_locked boolean NOT NULL DEFAULT false,
  is_trashed boolean NOT NULL DEFAULT false,
  department_id uuid NULL
);
INSERT INTO public.customers (id, name) VALUES
  ('00000000-0000-4000-8000-000000000101', 'Local Customer A'),
  ('00000000-0000-4000-8000-000000000102', 'Local Customer B');
INSERT INTO public.sales_opportunities (id, customer_id) VALUES
  ('00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000101'),
  ('00000000-0000-4000-8000-000000000202', '00000000-0000-4000-8000-000000000102');
INSERT INTO public.master_specifications (id, opportunity_id, customer_id) VALUES
  ('00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000101'),
  ('00000000-0000-4000-8000-000000000302', '00000000-0000-4000-8000-000000000202', '00000000-0000-4000-8000-000000000102');
INSERT INTO public.master_specification_versions (id, specification_id, version_number, specification_data, created_at) VALUES
  ('00000000-0000-4000-8000-000000000401', '00000000-0000-4000-8000-000000000301', 1, '{"source":"A"}'::jsonb, '2026-10-10T00:00:00Z'),
  ('00000000-0000-4000-8000-000000000402', '00000000-0000-4000-8000-000000000302', 1, '{"source":"B"}'::jsonb, '2026-10-10T00:00:00Z');
INSERT INTO public.drive_nodes (id, name, node_type, is_locked, is_trashed) VALUES
  ('00000000-0000-4000-8000-000000000601', 'Sales private structured drafts', 'folder', true, false),
  ('00000000-0000-4000-8000-000000000602', 'Untrusted folder', 'folder', false, false);
INSERT INTO public.sales_structured_draft_test_permissions (user_id, sales_manage) VALUES
  ('00000000-0000-4000-8000-000000000001', true),
  ('00000000-0000-4000-8000-000000000002', true),
  ('00000000-0000-4000-8000-000000000003', false);
COMMIT;
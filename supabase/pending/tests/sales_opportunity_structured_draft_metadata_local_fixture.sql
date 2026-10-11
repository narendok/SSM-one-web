-- LOCAL DISPOSABLE FIXTURE ONLY. Never run against an application database.
-- This models exactly the source tables and authorization helper consumed by
-- the pending structured-draft proposal; it is not a production schema export,
-- managed-RLS proof, or authenticated application-transport test.
\set ON_ERROR_STOP on
BEGIN;
DROP SCHEMA IF EXISTS auth CASCADE;
DROP SCHEMA IF EXISTS public CASCADE;
DROP SCHEMA IF EXISTS storage CASCADE;
CREATE SCHEMA public;
CREATE SCHEMA auth;
CREATE SCHEMA storage;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
DO $roles$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN CREATE ROLE service_role NOLOGIN; END IF;
END;
$roles$;
GRANT authenticated TO CURRENT_USER;
GRANT anon TO CURRENT_USER;
GRANT USAGE ON SCHEMA public, auth, storage TO authenticated, anon;
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
CREATE TABLE public.sales_structured_draft_test_project_permissions (user_id uuid NOT NULL, permission text NOT NULL, PRIMARY KEY(user_id, permission));
CREATE FUNCTION public.has_any_permission(p_actor uuid, p_permissions text[]) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.sales_structured_draft_test_project_permissions
    WHERE user_id = p_actor AND permission = ANY(p_permissions)
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
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
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
INSERT INTO public.sales_structured_draft_test_project_permissions(user_id, permission) VALUES
  ('00000000-0000-4000-8000-000000000003', 'projects.manage'),
  ('00000000-0000-4000-8000-000000000004', 'engineering.manage');
COMMIT;
CREATE TABLE public.departments (id uuid PRIMARY KEY, code text NOT NULL, name text NOT NULL, is_active boolean NOT NULL DEFAULT true);
INSERT INTO public.departments(id, code, name) VALUES ('00000000-0000-4000-8000-000000000501', 'SAL', 'Sales');
ALTER TABLE public.drive_nodes ADD COLUMN file_type text NULL, ADD COLUMN mime_type text NULL, ADD COLUMN file_size_bytes bigint NULL, ADD COLUMN sha256_checksum text NULL, ADD COLUMN current_version integer NOT NULL DEFAULT 1, ADD COLUMN slug text NOT NULL DEFAULT 'fixture', ADD COLUMN metadata jsonb NOT NULL DEFAULT '{}'::jsonb, ADD COLUMN created_by uuid NULL;
CREATE TABLE public.drive_node_revisions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), node_id uuid NOT NULL REFERENCES public.drive_nodes(id), version integer NOT NULL, file_size_bytes bigint NOT NULL, storage_path text NOT NULL, sha256_checksum text NULL, change_summary text NULL, uploaded_by uuid NULL);
CREATE TABLE public.document_control_registers (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), drive_node_id uuid NOT NULL UNIQUE REFERENCES public.drive_nodes(id), department_id uuid NOT NULL REFERENCES public.departments(id), document_number text NOT NULL UNIQUE, title text NOT NULL, document_status text NOT NULL DEFAULT 'DRAFT', controlled_version integer NOT NULL DEFAULT 1, approval_note text NULL, created_by uuid NOT NULL);
CREATE FUNCTION public.can_access_department_drive(p_user uuid, p_department uuid, p_project uuid) RETURNS boolean LANGUAGE sql AS $$ SELECT true $$;
CREATE FUNCTION public.next_business_number(p_kind text, p_prefix text, p_context text) RETURNS text LANGUAGE sql AS $$ SELECT upper(p_prefix) || '-LOCAL-' || substr(md5(coalesce(p_context,'') || p_kind), 1, 8) $$;
CREATE TABLE storage.objects (bucket_id text NOT NULL, name text NOT NULL, PRIMARY KEY(bucket_id,name));
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON storage.objects TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON storage.objects TO anon;

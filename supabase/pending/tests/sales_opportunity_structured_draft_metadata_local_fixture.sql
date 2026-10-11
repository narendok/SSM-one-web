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
  customer_id uuid NOT NULL REFERENCES public.customers(id),
  current_version_id uuid NULL
);
CREATE TABLE public.master_specification_versions (
  id uuid PRIMARY KEY, specification_id uuid NOT NULL REFERENCES public.master_specifications(id),
  version_number integer NOT NULL, specification_data jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (specification_id, version_number)
);
CREATE TABLE public.employees (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NULL,
  employment_status text NOT NULL
);
CREATE TABLE public.employee_departments (
  employee_id uuid NOT NULL REFERENCES public.employees(id),
  department_id uuid NOT NULL,
  PRIMARY KEY (employee_id, department_id)
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
INSERT INTO public.employees(id,user_id,employment_status) VALUES
  ('00000000-0000-4000-8000-000000000801','00000000-0000-4000-8000-000000000001','ACTIVE'),
  ('00000000-0000-4000-8000-000000000802','00000000-0000-4000-8000-000000000002','ACTIVE'),
  ('00000000-0000-4000-8000-000000000803','00000000-0000-4000-8000-000000000003','INACTIVE');
INSERT INTO public.employee_departments(employee_id,department_id) VALUES
  ('00000000-0000-4000-8000-000000000801','00000000-0000-4000-8000-000000000501'),
  ('00000000-0000-4000-8000-000000000802','00000000-0000-4000-8000-000000000501');
ALTER TABLE public.drive_nodes ADD COLUMN file_type text NULL, ADD COLUMN mime_type text NULL, ADD COLUMN file_size_bytes bigint NULL, ADD COLUMN sha256_checksum text NULL, ADD COLUMN current_version integer NOT NULL DEFAULT 1, ADD COLUMN slug text NOT NULL DEFAULT 'fixture', ADD COLUMN metadata jsonb NOT NULL DEFAULT '{}'::jsonb, ADD COLUMN created_by uuid NULL;
INSERT INTO public.customers (id, name) VALUES
  ('03e06115-a7d4-4965-9e92-9c37462f5ddc', 'Phase B Customer');
INSERT INTO public.sales_opportunities (id, customer_id) VALUES
  ('a6c62c81-1cc2-4804-b1c5-c004c6730b52', '03e06115-a7d4-4965-9e92-9c37462f5ddc');
INSERT INTO public.master_specifications (id, opportunity_id, customer_id) VALUES
  ('7a3aba95-61f6-495a-a280-f37a3be77670', 'a6c62c81-1cc2-4804-b1c5-c004c6730b52', '03e06115-a7d4-4965-9e92-9c37462f5ddc');
INSERT INTO public.master_specification_versions (id, specification_id, version_number, specification_data, created_at) VALUES
  ('4914fba5-43a0-4486-b62f-d775a9bb16b9', '7a3aba95-61f6-495a-a280-f37a3be77670', 1, '{"source":"Phase B"}'::jsonb, '2026-10-11T00:00:00Z');
INSERT INTO public.departments(id, code, name) VALUES
  ('db21a9b2-2cd4-4891-9151-064bef8a7cb4', 'SAL-PHASE-B', 'Sales Phase B');
INSERT INTO public.drive_nodes(id, name, node_type, is_locked, is_trashed, department_id, project_id, parent_id, slug) VALUES
  ('0c3e85df-f901-4bb9-9ea7-ee2072658faa', 'Sales root', 'folder', true, false, 'db21a9b2-2cd4-4891-9151-064bef8a7cb4', NULL, NULL, 'sales-root-phase-b'),
  ('020dcca5-7809-4287-88cd-537d837a3eee', 'Sales client folder', 'folder', true, false, 'db21a9b2-2cd4-4891-9151-064bef8a7cb4', NULL, '0c3e85df-f901-4bb9-9ea7-ee2072658faa', 'sales-client-phase-b');
CREATE TABLE public.drive_node_revisions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), node_id uuid NOT NULL REFERENCES public.drive_nodes(id), version integer NOT NULL, file_size_bytes bigint NOT NULL, storage_path text NOT NULL, sha256_checksum text NULL, change_summary text NULL, uploaded_by uuid NULL);
CREATE TABLE public.document_control_registers (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), drive_node_id uuid NOT NULL UNIQUE REFERENCES public.drive_nodes(id), department_id uuid NOT NULL REFERENCES public.departments(id), document_number text NOT NULL UNIQUE, title text NOT NULL, document_status text NOT NULL DEFAULT 'DRAFT', controlled_version integer NOT NULL DEFAULT 1, approval_note text NULL, owner_employee_id uuid NULL, source_revision_id uuid NULL, created_by uuid NOT NULL);
CREATE FUNCTION public.can_access_department_drive(p_user uuid, p_department uuid, p_project uuid) RETURNS boolean LANGUAGE sql AS $$
  SELECT EXISTS (SELECT 1 FROM public.employees e JOIN public.employee_departments ed ON ed.employee_id=e.id WHERE e.user_id=p_user AND e.employment_status='ACTIVE' AND ed.department_id=p_department)
$$;
CREATE FUNCTION public.next_business_number(p_kind text, p_prefix text, p_context text) RETURNS text LANGUAGE sql AS $$ SELECT upper(p_prefix) || '-LOCAL-' || substr(md5(coalesce(p_context,'') || p_kind), 1, 8) $$;
CREATE TABLE storage.objects (bucket_id text NOT NULL, name text NOT NULL, version text NOT NULL DEFAULT 'v1', PRIMARY KEY(bucket_id,name));
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON storage.objects TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON storage.objects TO anon;

-- LOCAL DISPOSABLE FIXTURE ONLY. Never run against an application database.
\set ON_ERROR_STOP on
DROP SCHEMA IF EXISTS auth CASCADE;
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
CREATE SCHEMA auth;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN CREATE ROLE service_role NOLOGIN; END IF;
END $$;
GRANT USAGE ON SCHEMA public TO authenticated;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
CREATE TABLE public.customers (id uuid PRIMARY KEY);
CREATE TABLE public.sales_opportunities (id uuid PRIMARY KEY, customer_id uuid NOT NULL REFERENCES public.customers(id));
CREATE TABLE public.customer_requirements (id uuid PRIMARY KEY, customer_id uuid NOT NULL REFERENCES public.customers(id), opportunity_id uuid NOT NULL REFERENCES public.sales_opportunities(id));
CREATE TABLE public.requirement_baselines (id uuid PRIMARY KEY, requirement_id uuid NOT NULL REFERENCES public.customer_requirements(id), status text NOT NULL, approved_by uuid, approved_at timestamptz);
CREATE TABLE public.employees (id uuid PRIMARY KEY, user_id uuid, employment_status text NOT NULL);
CREATE TABLE public.projects (id uuid PRIMARY KEY, customer_id uuid, opportunity_id uuid, requirement_baseline_id uuid, project_manager_employee_id uuid);
CREATE TABLE public.project_team_members (id uuid PRIMARY KEY, project_id uuid NOT NULL REFERENCES public.projects(id), employee_id uuid NOT NULL REFERENCES public.employees(id));
CREATE TABLE public.sales_project_handovers (id uuid PRIMARY KEY, baseline_id uuid NOT NULL REFERENCES public.requirement_baselines(id), project_id uuid, status text NOT NULL);
CREATE TABLE public.drive_nodes (id uuid PRIMARY KEY, project_id uuid REFERENCES public.projects(id));
CREATE TABLE public.drive_node_revisions (id uuid PRIMARY KEY, node_id uuid NOT NULL REFERENCES public.drive_nodes(id), version integer NOT NULL);
CREATE TABLE public.document_control_registers (id uuid PRIMARY KEY, drive_node_id uuid NOT NULL REFERENCES public.drive_nodes(id), project_id uuid REFERENCES public.projects(id), document_status text NOT NULL, controlled_version integer NOT NULL);
CREATE TABLE public.deviation_test_failpoints (name text PRIMARY KEY, enabled boolean NOT NULL DEFAULT false);
CREATE FUNCTION public.deviation_test_failpoint() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF EXISTS (SELECT 1 FROM public.deviation_test_failpoints WHERE name = TG_TABLE_NAME AND enabled) THEN RAISE EXCEPTION 'Injected deviation test failure'; END IF; RETURN NEW; END $$;
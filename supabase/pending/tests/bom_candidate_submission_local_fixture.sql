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
CREATE TABLE public.departments (id uuid PRIMARY KEY, code text NOT NULL, is_active boolean NOT NULL);
CREATE TABLE public.employees (id uuid PRIMARY KEY, user_id uuid, employment_status text NOT NULL);
CREATE TABLE public.employee_departments (employee_id uuid NOT NULL REFERENCES public.employees(id), department_id uuid NOT NULL REFERENCES public.departments(id));
CREATE TABLE public.permissions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), key text NOT NULL UNIQUE, module_key text NOT NULL, label text NOT NULL, description text NOT NULL);
CREATE TABLE public.access_roles (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL);
CREATE TABLE public.employee_access_roles (employee_id uuid NOT NULL REFERENCES public.employees(id), role_id uuid NOT NULL REFERENCES public.access_roles(id));
CREATE TABLE public.access_role_permissions (role_id uuid NOT NULL REFERENCES public.access_roles(id), permission_id uuid NOT NULL REFERENCES public.permissions(id));
CREATE TABLE public.projects (id uuid PRIMARY KEY, customer_id uuid, opportunity_id uuid, requirement_baseline_id uuid, project_manager_employee_id uuid);
CREATE TABLE public.project_boms (id uuid PRIMARY KEY, project_id uuid NOT NULL REFERENCES public.projects(id));
CREATE TABLE public.project_bom_items (id uuid PRIMARY KEY, bom_id uuid NOT NULL REFERENCES public.project_boms(id), value text NOT NULL);
CREATE TABLE public.project_team_members (id uuid PRIMARY KEY, project_id uuid NOT NULL REFERENCES public.projects(id), employee_id uuid NOT NULL REFERENCES public.employees(id));
CREATE TABLE public.sales_project_handovers (id uuid PRIMARY KEY, baseline_id uuid NOT NULL REFERENCES public.requirement_baselines(id), project_id uuid, status text NOT NULL);
CREATE TABLE public.candidate_test_failpoints (name text PRIMARY KEY, enabled boolean NOT NULL DEFAULT false);
CREATE FUNCTION public.candidate_test_failpoint() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF EXISTS (SELECT 1 FROM public.candidate_test_failpoints WHERE name = TG_TABLE_NAME AND enabled) THEN RAISE EXCEPTION 'Injected candidate test failure'; END IF; RETURN NEW; END $$;
CREATE FUNCTION public.has_permission(p_actor uuid, p_permission text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.employees employee JOIN public.employee_access_roles membership ON membership.employee_id = employee.id JOIN public.access_role_permissions role_permission ON role_permission.role_id = membership.role_id JOIN public.permissions permission ON permission.id = role_permission.permission_id WHERE employee.user_id = p_actor AND employee.employment_status = 'ACTIVE' AND permission.key = p_permission)
$$;
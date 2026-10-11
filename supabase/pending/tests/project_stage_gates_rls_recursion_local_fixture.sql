\set ON_ERROR_STOP on
-- LOCAL DISPOSABLE FIXTURE ONLY. Never run against an application database.
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
GRANT USAGE ON SCHEMA public, auth TO anon, authenticated;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
CREATE TYPE public.app_role AS ENUM ('admin', 'member');
CREATE TABLE public.user_roles (user_id uuid NOT NULL, role public.app_role NOT NULL);
CREATE TABLE public.permissions (id uuid PRIMARY KEY, key text UNIQUE NOT NULL);
CREATE TABLE public.employees (id uuid PRIMARY KEY, user_id uuid UNIQUE, employment_status text NOT NULL);
CREATE TABLE public.access_roles (id uuid PRIMARY KEY);
CREATE TABLE public.employee_access_roles (employee_id uuid NOT NULL REFERENCES public.employees(id), role_id uuid NOT NULL REFERENCES public.access_roles(id));
CREATE TABLE public.access_role_permissions (role_id uuid NOT NULL REFERENCES public.access_roles(id), permission_id uuid NOT NULL REFERENCES public.permissions(id));
CREATE TABLE public.projects (id uuid PRIMARY KEY, company_id uuid NOT NULL);
CREATE TABLE public.project_team_members (id uuid PRIMARY KEY, project_id uuid NOT NULL REFERENCES public.projects(id), employee_id uuid NOT NULL REFERENCES public.employees(id));
CREATE TABLE public.project_stage_gates (id uuid PRIMARY KEY, project_id uuid NOT NULL REFERENCES public.projects(id), gate_code text NOT NULL);
CREATE FUNCTION public.has_role(_user_id uuid, _role public.app_role) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$ SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role) $$;
CREATE FUNCTION public.has_permission(_user_id uuid, _permission_key text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$ SELECT public.has_role(_user_id, 'admin') OR EXISTS (SELECT 1 FROM public.employees e JOIN public.employee_access_roles ear ON ear.employee_id = e.id JOIN public.access_role_permissions arp ON arp.role_id = ear.role_id JOIN public.permissions p ON p.id = arp.permission_id WHERE e.user_id = _user_id AND e.employment_status = 'ACTIVE' AND p.key = _permission_key) $$;
GRANT SELECT ON public.user_roles, public.permissions, public.employees, public.access_roles, public.employee_access_roles, public.access_role_permissions, public.projects, public.project_team_members, public.project_stage_gates TO authenticated;
GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role), public.has_permission(uuid, text) TO authenticated;
ALTER TABLE public.project_team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_stage_gates ENABLE ROW LEVEL SECURITY;
-- Existing live policies, reproduced before the review-only replacement.
CREATE POLICY "Project members view their project team" ON public.project_team_members FOR SELECT TO authenticated USING (
  public.has_role(auth.uid(), 'admin') OR public.has_permission(auth.uid(), 'projects.manage') OR EXISTS (
    SELECT 1 FROM public.employees viewer WHERE viewer.user_id = auth.uid() AND viewer.id = project_team_members.employee_id
  ) OR EXISTS (
    SELECT 1 FROM public.project_team_members membership JOIN public.employees member_employee ON member_employee.id = membership.employee_id
    WHERE membership.project_id = project_team_members.project_id AND member_employee.user_id = auth.uid()
  )
);
CREATE POLICY "Project team view stage gates" ON public.project_stage_gates FOR SELECT TO authenticated USING (
  public.has_role(auth.uid(), 'admin') OR public.has_permission(auth.uid(), 'projects.view') OR EXISTS (
    SELECT 1 FROM public.project_team_members membership JOIN public.employees member_employee ON member_employee.id = membership.employee_id
    WHERE membership.project_id = project_stage_gates.project_id AND member_employee.user_id = auth.uid()
  )
);
INSERT INTO public.permissions VALUES ('10000000-0000-4000-8000-000000000001', 'projects.view');
INSERT INTO public.access_roles VALUES ('20000000-0000-4000-8000-000000000001');
INSERT INTO public.employees VALUES
  ('30000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', 'ACTIVE'),
  ('30000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000002', 'ACTIVE'),
  ('30000000-0000-4000-8000-000000000006', '40000000-0000-4000-8000-000000000006', 'ACTIVE'),
  ('30000000-0000-4000-8000-000000000003', '40000000-0000-4000-8000-000000000003', 'ACTIVE'),
  ('30000000-0000-4000-8000-000000000004', '40000000-0000-4000-8000-000000000004', 'ACTIVE'),
  ('30000000-0000-4000-8000-000000000005', '40000000-0000-4000-8000-000000000005', 'INACTIVE');
INSERT INTO public.user_roles VALUES ('40000000-0000-4000-8000-000000000004', 'admin');
INSERT INTO public.employee_access_roles VALUES ('30000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000001');
INSERT INTO public.access_role_permissions VALUES ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001');
INSERT INTO public.projects VALUES
  ('50000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000001'),
  ('50000000-0000-4000-8000-000000000002', '60000000-0000-4000-8000-000000000002');
INSERT INTO public.project_team_members VALUES
  ('70000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001'),
  ('70000000-0000-4000-8000-000000000002', '50000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000006'),
  ('70000000-0000-4000-8000-000000000003', '50000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000006'),
  ('70000000-0000-4000-8000-000000000004', '50000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000005');
INSERT INTO public.project_stage_gates VALUES
  ('80000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000001', 'GATE-A'),
  ('80000000-0000-4000-8000-000000000002', '50000000-0000-4000-8000-000000000002', 'GATE-B');

-- LOCAL DISPOSABLE FIXTURE ONLY. This is a deliberately minimal schema for
-- exercising the pending client-intake proposal. It models function inputs,
-- source foreign keys, and synthetic identity/scope helpers only. It does not
-- reproduce managed RLS, JWT verification, grants, or application transport.
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
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
CREATE TABLE public.customers (id uuid PRIMARY KEY, name text NOT NULL);
CREATE TABLE public.sales_enquiries (id uuid PRIMARY KEY, customer_id uuid NOT NULL REFERENCES public.customers(id), contact_id uuid, status text NOT NULL DEFAULT 'draft', updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.sales_opportunities (id uuid PRIMARY KEY, customer_id uuid NOT NULL REFERENCES public.customers(id), enquiry_id uuid REFERENCES public.sales_enquiries(id));
CREATE TABLE public.external_parties (id uuid PRIMARY KEY, customer_id uuid NOT NULL REFERENCES public.customers(id), active boolean NOT NULL DEFAULT true);
CREATE TABLE public.external_contacts (id uuid PRIMARY KEY, external_party_id uuid NOT NULL REFERENCES public.external_parties(id), user_id uuid NOT NULL UNIQUE, active boolean NOT NULL DEFAULT true, portal_enabled boolean NOT NULL DEFAULT true);
CREATE TABLE public.external_portal_access (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), external_contact_id uuid NOT NULL REFERENCES public.external_contacts(id), portal_type text NOT NULL, access_scope jsonb NOT NULL DEFAULT '{}'::jsonb, is_active boolean NOT NULL DEFAULT true, deactivated_at timestamptz, invitation_revoked_at timestamptz, expires_at timestamptz);
CREATE TABLE public.customer_requirements (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), opportunity_id uuid NOT NULL REFERENCES public.sales_opportunities(id), customer_id uuid NOT NULL REFERENCES public.customers(id), title text NOT NULL, status text NOT NULL, current_revision integer NOT NULL, customer_reference text, requirement_data jsonb NOT NULL DEFAULT '{}'::jsonb, submitted_at timestamptz, created_by uuid);
CREATE TABLE public.customer_requirement_revisions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), requirement_id uuid NOT NULL REFERENCES public.customer_requirements(id), revision_number integer NOT NULL, change_summary text NOT NULL, requirement_data jsonb NOT NULL, status text NOT NULL, created_by uuid);
CREATE TABLE public.departments (id uuid PRIMARY KEY, is_active boolean NOT NULL DEFAULT true);
CREATE TABLE public.employees (id uuid PRIMARY KEY, user_id uuid, employment_status text NOT NULL);
CREATE TABLE public.employee_departments (employee_id uuid NOT NULL REFERENCES public.employees(id), department_id uuid NOT NULL REFERENCES public.departments(id));
CREATE TABLE public.master_specifications (id uuid PRIMARY KEY, opportunity_id uuid NOT NULL REFERENCES public.sales_opportunities(id), customer_id uuid NOT NULL REFERENCES public.customers(id));
CREATE TABLE public.master_specification_versions (id uuid PRIMARY KEY, specification_id uuid NOT NULL REFERENCES public.master_specifications(id), version_number integer NOT NULL, specification_data jsonb NOT NULL, UNIQUE (specification_id, version_number));
CREATE TABLE public.requirement_feasibility_reviews (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), requirement_id uuid NOT NULL REFERENCES public.customer_requirements(id), department_id uuid REFERENCES public.departments(id), reviewer_user_id uuid, status text NOT NULL, findings text, assumptions text, risks text, reviewed_at timestamptz, created_by uuid, source_revision_id uuid, source_revision_number integer, master_specification_version_id uuid, master_specification_version_number integer, applicable_workstreams jsonb, UNIQUE (requirement_id, department_id));
CREATE TABLE public.activity_log (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), actor_user_id uuid NOT NULL, module_key text NOT NULL, entity_type text NOT NULL, entity_id uuid NOT NULL, action text NOT NULL, summary text NOT NULL, after_data jsonb);
CREATE TABLE public.notifications (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL, category text NOT NULL, title text NOT NULL, body text NOT NULL, target_url text, target_entity_type text, target_entity_id uuid, event_key text, UNIQUE (user_id, event_key));
CREATE FUNCTION public.enqueue_notification(_user_id uuid, _category text, _title text, _body text, _target_url text, _target_entity_type text, _target_entity_id uuid, _event_key text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$ BEGIN INSERT INTO public.notifications (user_id, category, title, body, target_url, target_entity_type, target_entity_id, event_key) VALUES (_user_id, _category, _title, _body, _target_url, _target_entity_type, _target_entity_id, _event_key) ON CONFLICT (user_id, event_key) DO NOTHING; END; $$;
CREATE FUNCTION public.external_current_contact_id(p_user_id uuid DEFAULT auth.uid()) RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$ SELECT contact.id FROM public.external_contacts contact JOIN public.external_parties party ON party.id = contact.external_party_id WHERE contact.user_id = p_user_id AND contact.active AND contact.portal_enabled AND party.active LIMIT 1 $$;
CREATE FUNCTION public.external_current_party_id() RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$ SELECT contact.external_party_id FROM public.external_contacts contact WHERE contact.id = public.external_current_contact_id(auth.uid()) $$;
CREATE FUNCTION public.has_permission(p_actor uuid, p_permission text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$ SELECT p_actor = '00000000-0000-4000-8000-000000000050'::uuid AND p_permission = 'sales.manage' $$;
CREATE FUNCTION public.client_requirement_test_failpoint() RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$ BEGIN IF current_setting('client_requirement.test.failpoint', true) = TG_TABLE_NAME AND NEW.action = 'external_submitted' THEN RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'Local test failpoint: ' || TG_TABLE_NAME; END IF; RETURN NEW; END; $$;
CREATE TRIGGER client_requirement_fail_activity BEFORE INSERT ON public.activity_log FOR EACH ROW EXECUTE FUNCTION public.client_requirement_test_failpoint();
INSERT INTO public.customers (id, name) VALUES ('00000000-0000-4000-8000-000000000010', 'Synthetic Customer A'), ('00000000-0000-4000-8000-000000000011', 'Synthetic Customer B');
INSERT INTO public.sales_opportunities (id, customer_id, enquiry_id) VALUES ('00000000-0000-4000-8000-000000000020', '00000000-0000-4000-8000-000000000010', NULL), ('00000000-0000-4000-8000-000000000021', '00000000-0000-4000-8000-000000000011', NULL);
INSERT INTO public.external_parties (id, customer_id) VALUES ('00000000-0000-4000-8000-000000000030', '00000000-0000-4000-8000-000000000010'), ('00000000-0000-4000-8000-000000000031', '00000000-0000-4000-8000-000000000011');
INSERT INTO public.external_contacts (id, external_party_id, user_id) VALUES ('00000000-0000-4000-8000-000000000040', '00000000-0000-4000-8000-000000000030', '00000000-0000-4000-8000-000000000001'), ('00000000-0000-4000-8000-000000000041', '00000000-0000-4000-8000-000000000030', '00000000-0000-4000-8000-000000000002'), ('00000000-0000-4000-8000-000000000042', '00000000-0000-4000-8000-000000000031', '00000000-0000-4000-8000-000000000003');
INSERT INTO public.external_portal_access (external_contact_id, portal_type, access_scope) VALUES ('00000000-0000-4000-8000-000000000040', 'CLIENT_REQUIREMENTS', '{"opportunityIds":["00000000-0000-4000-8000-000000000020"],"customerIds":["00000000-0000-4000-8000-000000000010"]}'::jsonb), ('00000000-0000-4000-8000-000000000041', 'CLIENT_REQUIREMENTS', '{"opportunityIds":["00000000-0000-4000-8000-000000000020"],"customerIds":["00000000-0000-4000-8000-000000000010"]}'::jsonb), ('00000000-0000-4000-8000-000000000042', 'CLIENT_REQUIREMENTS', '{"opportunityIds":["00000000-0000-4000-8000-000000000021"],"customerIds":["00000000-0000-4000-8000-000000000011"]}'::jsonb);
INSERT INTO public.departments (id, is_active) VALUES ('00000000-0000-4000-8000-000000000060', true);
INSERT INTO public.employees (id, user_id, employment_status) VALUES ('00000000-0000-4000-8000-000000000061', '00000000-0000-4000-8000-000000000062', 'ACTIVE');
INSERT INTO public.employee_departments (employee_id, department_id) VALUES ('00000000-0000-4000-8000-000000000061', '00000000-0000-4000-8000-000000000060');
INSERT INTO public.master_specifications (id, opportunity_id, customer_id) VALUES ('00000000-0000-4000-8000-000000000070', '00000000-0000-4000-8000-000000000020', '00000000-0000-4000-8000-000000000010');
INSERT INTO public.master_specification_versions (id, specification_id, version_number, specification_data) VALUES
  ('00000000-0000-4000-8000-000000000071', '00000000-0000-4000-8000-000000000070', 1, '{"workstreams":["HARDWARE"]}'::jsonb),
  ('00000000-0000-4000-8000-000000000072', '00000000-0000-4000-8000-000000000070', 2, '{"workstreams":["FIRMWARE"]}'::jsonb);
INSERT INTO public.customer_requirements (id, opportunity_id, customer_id, title, status, current_revision, requirement_data, created_by) VALUES ('00000000-0000-4000-8000-000000000080', '00000000-0000-4000-8000-000000000020', '00000000-0000-4000-8000-000000000010', 'Historical pin requirement', 'submitted', 1, '{}'::jsonb, '00000000-0000-4000-8000-000000000050');
INSERT INTO public.customer_requirement_revisions (id, requirement_id, revision_number, change_summary, requirement_data, status, created_by) VALUES ('00000000-0000-4000-8000-000000000081', '00000000-0000-4000-8000-000000000080', 1, 'Pinned historical requirement revision', '{"source":{"master_specification_version_id":"00000000-0000-4000-8000-000000000071","master_specification_version_number":1,"opportunity_id":"00000000-0000-4000-8000-000000000020","customer_id":"00000000-0000-4000-8000-000000000010"}}'::jsonb, 'submitted', '00000000-0000-4000-8000-000000000050');
INSERT INTO public.sales_enquiries (id, customer_id, status, updated_at) VALUES ('00000000-0000-4000-8000-000000000095', '00000000-0000-4000-8000-000000000010', 'draft', '2026-10-13 18:23:00+00');
UPDATE public.sales_opportunities SET enquiry_id = '00000000-0000-4000-8000-000000000095' WHERE id = '00000000-0000-4000-8000-000000000020';
COMMIT;
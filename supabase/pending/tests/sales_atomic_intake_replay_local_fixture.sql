-- LOCAL DISPOSABLE FIXTURE ONLY. Never run against an application database.
-- It is intentionally minimal and models only the verified shapes consumed by
-- the pending Sales intake proposal. It is not a production schema export or
-- RLS/HTTP transport proof.
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
CREATE TABLE public.sales_test_permissions (user_id uuid PRIMARY KEY, sales_manage boolean NOT NULL);
CREATE FUNCTION public.has_permission(p_actor uuid, p_permission text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT p_permission = 'sales.manage' AND EXISTS (
    SELECT 1 FROM public.sales_test_permissions WHERE user_id = p_actor AND sales_manage
  )
$$;
CREATE TABLE public.document_numbering_config (
  document_type text PRIMARY KEY, prefix text NOT NULL, next_value integer NOT NULL
);
INSERT INTO public.document_numbering_config VALUES ('opportunity', 'OPP', 1), ('master_specification', 'MS', 1);
CREATE FUNCTION public.next_business_number(p_type text, p_prefix text, p_unused text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_next integer; v_prefix text;
BEGIN
  SELECT next_value, prefix INTO v_next, v_prefix FROM public.document_numbering_config
  WHERE document_type = p_type FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Unknown test number type'; END IF;
  UPDATE public.document_numbering_config SET next_value = next_value + 1 WHERE document_type = p_type;
  RETURN coalesce(nullif(p_prefix, ''), v_prefix) || '-' || lpad(v_next::text, 4, '0');
END;
$$;
CREATE TABLE public.customers (id uuid PRIMARY KEY, name text NOT NULL);
CREATE TABLE public.customer_contacts (id uuid PRIMARY KEY, customer_id uuid NOT NULL REFERENCES public.customers(id), is_active boolean NOT NULL DEFAULT true);
CREATE TABLE public.sales_enquiries (id uuid PRIMARY KEY, customer_id uuid NOT NULL REFERENCES public.customers(id), contact_id uuid REFERENCES public.customer_contacts(id));
CREATE TABLE public.sales_opportunities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), opportunity_number text UNIQUE, customer_id uuid NOT NULL REFERENCES public.customers(id),
  primary_contact_id uuid REFERENCES public.customer_contacts(id), enquiry_id uuid REFERENCES public.sales_enquiries(id), name text NOT NULL,
  application text, product_type text, primary_sales_owner_user_id uuid, nda_required boolean NOT NULL, estimated_volume text,
  target_timeline text, priority text NOT NULL, next_action text, next_action_date date, created_by uuid NOT NULL
);
CREATE FUNCTION public.sales_opportunities_assign_business_code() RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.opportunity_number IS NULL OR btrim(NEW.opportunity_number) = '' THEN
    NEW.opportunity_number := public.next_business_number('opportunity', NULL, NULL);
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER sales_opportunities_assign_business_code BEFORE INSERT ON public.sales_opportunities
FOR EACH ROW EXECUTE FUNCTION public.sales_opportunities_assign_business_code();
CREATE TABLE public.master_specifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), specification_number text NOT NULL UNIQUE,
  opportunity_id uuid NOT NULL UNIQUE REFERENCES public.sales_opportunities(id), customer_id uuid NOT NULL REFERENCES public.customers(id),
  title text NOT NULL, status text NOT NULL, current_version integer NOT NULL, created_by uuid NOT NULL
);
CREATE TABLE public.master_specification_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), specification_id uuid NOT NULL REFERENCES public.master_specifications(id),
  version_number integer NOT NULL, change_summary text NOT NULL, specification_data jsonb NOT NULL, status text NOT NULL, created_by uuid NOT NULL,
  UNIQUE(specification_id, version_number)
);
CREATE TABLE public.activity_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), actor_user_id uuid NOT NULL, module_key text NOT NULL, entity_type text NOT NULL,
  entity_id uuid NOT NULL, action text NOT NULL, summary text NOT NULL, after_data jsonb
);
CREATE FUNCTION public.sales_intake_test_failpoint() RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF current_setting('sales_intake.test.failpoint', true) = TG_TABLE_NAME THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'Local test failpoint: ' || TG_TABLE_NAME;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER sales_intake_fail_opportunity BEFORE INSERT ON public.sales_opportunities FOR EACH ROW EXECUTE FUNCTION public.sales_intake_test_failpoint();
CREATE TRIGGER sales_intake_fail_specification BEFORE INSERT ON public.master_specifications FOR EACH ROW EXECUTE FUNCTION public.sales_intake_test_failpoint();
CREATE TRIGGER sales_intake_fail_version BEFORE INSERT ON public.master_specification_versions FOR EACH ROW EXECUTE FUNCTION public.sales_intake_test_failpoint();
CREATE TRIGGER sales_intake_fail_activity BEFORE INSERT ON public.activity_log FOR EACH ROW EXECUTE FUNCTION public.sales_intake_test_failpoint();
CREATE TRIGGER sales_intake_fail_receipt BEFORE INSERT ON public.sales_opportunity_intake_receipts FOR EACH ROW EXECUTE FUNCTION public.sales_intake_test_failpoint();
COMMIT;
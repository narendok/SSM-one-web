-- DISPOSABLE ONLY. Model app_role and one Sales-manage-only synthetic actor.
DO $$ DECLARE body text; BEGIN
 IF to_regtype('public.app_role') IS NULL THEN CREATE TYPE public.app_role AS ENUM('admin'); END IF;
 SELECT prosrc INTO body FROM pg_proc WHERE oid='public.has_permission(uuid,text)'::regprocedure;
 EXECUTE format('CREATE OR REPLACE FUNCTION public.has_permission(p_actor uuid,p_permission text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS %L',
 'SELECT CASE WHEN p_actor=''00000000-0000-4000-8000-000000000066''::uuid THEN p_permission=''sales.manage'' ELSE ('||rtrim(btrim(body),';')||') END');
END $$;
CREATE OR REPLACE FUNCTION public.has_role(p_actor uuid,p_role public.app_role) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT public.has_role(p_actor,p_role::text) $$;
-- DISPOSABLE FIXTURE ONLY: recreate the captured legacy runtime-write shape.
GRANT SELECT,INSERT,UPDATE,DELETE ON public.customer_requirements,public.customer_requirement_revisions,public.requirement_feasibility_reviews TO anon,authenticated;
CREATE POLICY "Sales users manage requirements" ON public.customer_requirements FOR ALL TO authenticated USING (public.has_permission(auth.uid(),'sales.manage') OR public.has_role(auth.uid(),'admin'::text)) WITH CHECK (public.has_permission(auth.uid(),'sales.manage') OR public.has_role(auth.uid(),'admin'::text));
CREATE POLICY "Sales users manage requirement revisions" ON public.customer_requirement_revisions FOR ALL TO authenticated USING (public.has_permission(auth.uid(),'sales.manage') OR public.has_role(auth.uid(),'admin'::text)) WITH CHECK (public.has_permission(auth.uid(),'sales.manage') OR public.has_role(auth.uid(),'admin'::text));
CREATE POLICY "Sales users manage feasibility reviews" ON public.requirement_feasibility_reviews FOR ALL TO authenticated USING (public.has_permission(auth.uid(),'sales.manage') OR public.has_role(auth.uid(),'admin'::text)) WITH CHECK (public.has_permission(auth.uid(),'sales.manage') OR public.has_role(auth.uid(),'admin'::text));

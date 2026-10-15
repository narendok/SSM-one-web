-- SOURCE-ONLY RESTORE REVIEW: not approved for execution.
-- Original backend yyrvduosyyaluifqvwkr; capture SHA256:
-- 843BE622B18A4E04B2F41673188CC4EEB79AC0D2E1C78EE99895121EF74EEAFC
-- Capture timestamp 2026-10-15T23:21:22.692607+00:00. Re-capture before any install.
-- Restores ONLY the three policies and anon/authenticated I/U/D removed by
-- 20261015_requirement_feasibility_original_target_compatibility.sql.
-- Does not restore routines, records, unrelated grants, tasks, or service_role.
-- This re-enables historical direct Sales writes: explicit rollback authorization required.
-- Requires reviewed unchanged SELECT policies, owners, RLS flags and unrelated ACLs.
BEGIN;
DO $restore_preflight$
DECLARE target text;
BEGIN
  FOREACH target IN ARRAY ARRAY['customer_requirements','customer_requirement_revisions','requirement_feasibility_reviews'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=target AND c.relrowsecurity AND NOT c.relforcerowsecurity
      AND pg_get_userbyid(c.relowner)='postgres') THEN
      RAISE EXCEPTION 'Restore target state drift: %',target;
    END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND
    (tablename,policyname) IN (
      ('customer_requirements','Sales users manage requirements'),
      ('customer_requirement_revisions','Sales users manage requirement revisions'),
      ('requirement_feasibility_reviews','Sales users manage feasibility reviews'))) THEN
    RAISE EXCEPTION 'A historical policy already exists; capture and review before restore';
  END IF;
END;
$restore_preflight$;
CREATE POLICY "Sales users manage requirements" ON public.customer_requirements
 AS PERMISSIVE FOR ALL TO authenticated
 USING (has_permission(auth.uid(), 'sales.manage'::text) OR has_role(auth.uid(), 'admin'::app_role))
 WITH CHECK (has_permission(auth.uid(), 'sales.manage'::text) OR has_role(auth.uid(), 'admin'::app_role));
CREATE POLICY "Sales users manage requirement revisions" ON public.customer_requirement_revisions
 AS PERMISSIVE FOR ALL TO authenticated
 USING (has_permission(auth.uid(), 'sales.manage'::text) OR has_role(auth.uid(), 'admin'::app_role))
 WITH CHECK (has_permission(auth.uid(), 'sales.manage'::text) OR has_role(auth.uid(), 'admin'::app_role));
CREATE POLICY "Sales users manage feasibility reviews" ON public.requirement_feasibility_reviews
 AS PERMISSIVE FOR ALL TO authenticated
 USING (has_permission(auth.uid(), 'sales.manage'::text) OR has_role(auth.uid(), 'admin'::app_role))
 WITH CHECK (has_permission(auth.uid(), 'sales.manage'::text) OR has_role(auth.uid(), 'admin'::app_role));
GRANT INSERT, UPDATE, DELETE ON public.customer_requirements TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.customer_requirement_revisions TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.requirement_feasibility_reviews TO anon, authenticated;
COMMIT;
-- Inspect exact post-restore metadata against the retained capture and run caller/RLS
-- acceptance before enabling legacy writers. This draft has NOT been SQL-executed.

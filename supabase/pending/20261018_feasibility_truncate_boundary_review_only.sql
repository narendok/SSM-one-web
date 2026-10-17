-- REVIEW ONLY. Not installed; requires separate approval and restore/caller acceptance.
-- Include after the reviewed original-target I/U/D transition in the SAME transaction.
-- TRUNCATE bypasses row-level policies; leaving its table grant is not direct-write denial.
DO $truncate_preflight$
DECLARE target regclass;
BEGIN
 FOREACH target IN ARRAY ARRAY['public.customer_requirements'::regclass,'public.customer_requirement_revisions'::regclass,'public.requirement_feasibility_reviews'::regclass] LOOP
  IF has_table_privilege('authenticated',target,'INSERT,UPDATE,DELETE') OR has_table_privilege('anon',target,'INSERT,UPDATE,DELETE') THEN
   RAISE EXCEPTION 'Apply the reviewed direct I/U/D transition first';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_class WHERE oid=target AND relrowsecurity AND NOT relforcerowsecurity) THEN
   RAISE EXCEPTION 'Unexpected graph RLS state';
  END IF;
 END LOOP;
 IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND cmd='ALL' AND (tablename,policyname) IN (
 ('customer_requirements','Sales users manage requirements'),
 ('customer_requirement_revisions','Sales users manage requirement revisions'),
 ('requirement_feasibility_reviews','Sales users manage feasibility reviews'))) THEN
  RAISE EXCEPTION 'Broad graph write policies remain';
 END IF;
END;
$truncate_preflight$;
REVOKE TRUNCATE ON public.customer_requirements,public.customer_requirement_revisions,public.requirement_feasibility_reviews FROM PUBLIC,anon,authenticated;
DO $truncate_postflight$
DECLARE target regclass;
BEGIN
 FOREACH target IN ARRAY ARRAY['public.customer_requirements'::regclass,'public.customer_requirement_revisions'::regclass,'public.requirement_feasibility_reviews'::regclass] LOOP
  IF has_table_privilege('authenticated',target,'INSERT,UPDATE,DELETE,TRUNCATE') OR has_table_privilege('anon',target,'INSERT,UPDATE,DELETE,TRUNCATE') THEN
   RAISE EXCEPTION 'Runtime graph write boundary is incomplete';
  END IF;
 END LOOP;
END;
$truncate_postflight$;

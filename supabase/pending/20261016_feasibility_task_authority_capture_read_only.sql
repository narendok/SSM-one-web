-- READ-ONLY SOURCE PACKAGE. Run only against the verified original managed target.
-- Expected project d758dbf2-2f0e-44b3-b149-1ec51def58eb / backend yyrvduosyyaluifqvwkr.
-- A database name alone does not prove target identity: retain operator/environment binding.
-- Captures catalog metadata only; no customer rows, credentials, DDL, grants or policies changed.
-- Keep output in controlled evidence; review exact policies/ACLs before constructing restore SQL.
BEGIN TRANSACTION READ ONLY;
WITH targets AS (
  SELECT c.oid, n.nspname AS schema_name, c.relname AS table_name,
         pg_get_userbyid(c.relowner) AS owner, c.relrowsecurity, c.relforcerowsecurity,
         c.relacl::text AS raw_acl
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relname IN
    ('customer_requirements','customer_requirement_revisions','requirement_feasibility_reviews','project_tasks')
), policies AS (
  SELECT t.table_name, p.polname, p.polcmd, p.polpermissive,
    ARRAY(SELECT CASE WHEN r = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(r) END
          FROM unnest(p.polroles) r ORDER BY r) AS roles,
    pg_get_expr(p.polqual,p.polrelid) AS using_expression,
    pg_get_expr(p.polwithcheck,p.polrelid) AS check_expression
  FROM targets t JOIN pg_policy p ON p.polrelid=t.oid
), grants AS (
  SELECT t.table_name, a.grantor, a.grantee, a.privilege_type, a.is_grantable
  FROM targets t JOIN pg_class c ON c.oid=t.oid
  CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl,acldefault('r',c.relowner))) a
), column_acls AS (
  SELECT t.table_name, a.attname AS column_name, a.attacl::text AS raw_acl
  FROM targets t JOIN pg_attribute a ON a.attrelid=t.oid
  WHERE a.attnum>0 AND NOT a.attisdropped AND a.attacl IS NOT NULL
), triggers AS (
  SELECT t.table_name, tr.tgname, tr.tgenabled, pg_get_triggerdef(tr.oid,true) AS definition,
    tr.tgfoid::regprocedure::text AS function_identity
  FROM targets t JOIN pg_trigger tr ON tr.tgrelid=t.oid WHERE NOT tr.tgisinternal
), routines AS (
  SELECT p.oid::regprocedure::text AS identity, p.prosecdef AS security_definer,
    pg_get_userbyid(p.proowner) AS owner, p.proacl::text AS raw_acl, p.proconfig AS settings,
    md5(pg_get_functiondef(p.oid)) AS definition_fingerprint
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.prokind='f' AND
   (p.proname IN ('submit_sales_feasibility_handover','assign_requirement_feasibility_review',
    'record_requirement_feasibility_response','submit_external_customer_requirement',
    'create_sales_bound_customer_requirement','lifecycle_can_manage_department')
    OR EXISTS (SELECT 1 FROM triggers tr WHERE tr.function_identity=p.oid::regprocedure::text))
)
SELECT jsonb_build_object(
  'captured_at',statement_timestamp(),'database',current_database(),'session_role',session_user,
  'expected_backend','yyrvduosyyaluifqvwkr','target_identity_verified_by_query',false,
  'expected_table_count',4,'found_table_count',(SELECT count(*) FROM targets),
  'tables',COALESCE((SELECT jsonb_agg(to_jsonb(t) ORDER BY table_name) FROM targets t),'[]'::jsonb),
  'policies',COALESCE((SELECT jsonb_agg(to_jsonb(p) ORDER BY table_name,polname) FROM policies p),'[]'::jsonb),
  'grants',COALESCE((SELECT jsonb_agg(to_jsonb(g) ORDER BY table_name,grantee,privilege_type) FROM grants g),'[]'::jsonb),
  'column_acls',COALESCE((SELECT jsonb_agg(to_jsonb(c) ORDER BY table_name,column_name) FROM column_acls c),'[]'::jsonb),
  'triggers',COALESCE((SELECT jsonb_agg(to_jsonb(t) ORDER BY table_name,tgname) FROM triggers t),'[]'::jsonb),
  'known_routines',COALESCE((SELECT jsonb_agg(to_jsonb(r) ORDER BY identity) FROM routines r),'[]'::jsonb)
) AS metadata_capture;
ROLLBACK;
-- Fingerprints identify drift only; they cannot recreate function bodies.
-- This inventory cannot prove absence of dynamic SQL, external writers, service-role jobs,
-- inherited role authority, sequence dependencies, or production caller/RLS behavior.
-- No generated restore/installation script or migration approval is implied.

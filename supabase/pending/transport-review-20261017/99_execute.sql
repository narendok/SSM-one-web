BEGIN;
DO $transport$
DECLARE v_payload bytea; v_count integer; v_min integer; v_max integer; v_graph_before jsonb; v_graph_after jsonb;
BEGIN
  IF (SELECT nspowner FROM pg_namespace WHERE nspname='_ssm_feasibility_install_20261017') IS DISTINCT FROM (SELECT oid FROM pg_roles WHERE rolname=current_user) THEN
    RAISE EXCEPTION 'Transport owner mismatch';
  END IF;
  LOCK TABLE _ssm_feasibility_install_20261017.chunks IN EXCLUSIVE MODE;
  SELECT decode(string_agg(encode(payload,'hex'),'' ORDER BY ordinal),'hex'),count(*),min(ordinal),max(ordinal)
  INTO v_payload,v_count,v_min,v_max FROM _ssm_feasibility_install_20261017.chunks;
  IF v_count <> 9 OR v_min <> 1 OR v_max <> 9
     OR octet_length(v_payload) <> 53542
     OR encode(sha256(v_payload),'hex') IS DISTINCT FROM 'a990777fe0c51ca4d12b6d3c6adcce3f35e0028fe4de5805d9303ae26ed12d9e' THEN
    RAISE EXCEPTION 'Transport incomplete or source hash mismatch';
  END IF;
  SELECT jsonb_build_object('tables',(SELECT jsonb_agg(jsonb_build_object('name',relname,'acl',relacl,'rls',relrowsecurity) ORDER BY relname) FROM pg_class WHERE oid IN ('public.customer_requirements'::regclass,'public.customer_requirement_revisions'::regclass,'public.requirement_feasibility_reviews'::regclass)),
    'policies',(SELECT jsonb_agg(to_jsonb(p) ORDER BY polrelid,polname) FROM pg_policy p WHERE polrelid IN ('public.customer_requirements'::regclass,'public.customer_requirement_revisions'::regclass,'public.requirement_feasibility_reviews'::regclass))) INTO v_graph_before;
  EXECUTE convert_from(v_payload,'UTF8');
  SELECT jsonb_build_object('tables',(SELECT jsonb_agg(jsonb_build_object('name',relname,'acl',relacl,'rls',relrowsecurity) ORDER BY relname) FROM pg_class WHERE oid IN ('public.customer_requirements'::regclass,'public.customer_requirement_revisions'::regclass,'public.requirement_feasibility_reviews'::regclass)),
    'policies',(SELECT jsonb_agg(to_jsonb(p) ORDER BY polrelid,polname) FROM pg_policy p WHERE polrelid IN ('public.customer_requirements'::regclass,'public.customer_requirement_revisions'::regclass,'public.requirement_feasibility_reviews'::regclass))) INTO v_graph_after;
  IF v_graph_before IS DISTINCT FROM v_graph_after THEN RAISE EXCEPTION 'Existing graph access changed'; END IF;
  IF EXISTS (SELECT 1 FROM (VALUES
    ('public.assign_requirement_feasibility_review(uuid,uuid,uuid)'::regprocedure),
    ('public.record_requirement_feasibility_response(uuid,text,text,text,text,uuid)'::regprocedure),
    ('public.read_requirement_feasibility_response_receipt(uuid,uuid,uuid,uuid,uuid)'::regprocedure),
    ('public.submit_sales_feasibility_handover(uuid,uuid,uuid,uuid,text,text,text,uuid[],uuid[],timestamptz,uuid)'::regprocedure)
  ) f(oid) JOIN pg_proc p ON p.oid=f.oid WHERE NOT p.prosecdef OR p.proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp']
    OR has_function_privilege('anon',f.oid,'EXECUTE') OR NOT has_function_privilege('authenticated',f.oid,'EXECUTE')
    OR NOT has_function_privilege('service_role',f.oid,'EXECUTE')) THEN RAISE EXCEPTION 'Protected RPC authority mismatch'; END IF;
  IF EXISTS (SELECT 1 FROM (VALUES ('public.sales_feasibility_handover_requests'::regclass),('public.requirement_feasibility_response_requests'::regclass)) t(oid)
    JOIN pg_class c ON c.oid=t.oid WHERE NOT c.relrowsecurity OR has_table_privilege('anon',t.oid,'SELECT,INSERT,UPDATE,DELETE')
    OR has_table_privilege('authenticated',t.oid,'SELECT,INSERT,UPDATE,DELETE')) THEN RAISE EXCEPTION 'Private receipt access mismatch'; END IF;
  IF (SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='requirement_feasibility_reviews'
      AND column_name IN ('source_revision_id','source_revision_number','master_specification_version_id','master_specification_version_number','applicable_workstreams')) <> 5 THEN
    RAISE EXCEPTION 'Installed pins incomplete';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.requirement_feasibility_reviews'::regclass
      AND conname='requirement_feasibility_reviews_revision_department_key' AND contype='u') THEN
    RAISE EXCEPTION 'Installed uniqueness incomplete';
  END IF;
END;
$transport$;
-- Explicitly remove only this newly-created, hash-checked transport; never CASCADE.
DROP TABLE _ssm_feasibility_install_20261017.chunks;
DROP SCHEMA _ssm_feasibility_install_20261017;
COMMIT;

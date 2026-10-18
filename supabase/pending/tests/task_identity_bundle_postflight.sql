DO $bundle_postflight$
DECLARE application_role name; object_oid oid; object_count integer; populated boolean;
BEGIN
 SELECT count(*) INTO object_count FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='_ssm_task_identity' AND c.relkind='r';
 IF object_count<>3 THEN RAISE EXCEPTION 'Private identity bundle table inventory mismatch'; END IF;
 IF EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='_ssm_task_identity' AND c.relkind='r' AND (NOT c.relrowsecurity OR c.relowner<>(SELECT oid FROM pg_roles WHERE rolname=current_user))) THEN RAISE EXCEPTION 'Private identity bundle table ownership/RLS mismatch'; END IF;
 SELECT count(*) INTO object_count FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='_ssm_task_identity';
 IF object_count<>4 THEN RAISE EXCEPTION 'Private identity bundle function inventory mismatch'; END IF;
 FOREACH application_role IN ARRAY ARRAY['anon'::name,'authenticated'::name,'service_role'::name] LOOP
  IF has_schema_privilege(application_role,'_ssm_task_identity','USAGE,CREATE') THEN RAISE EXCEPTION 'Private identity schema application access remains'; END IF;
  FOR object_oid IN SELECT c.oid FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='_ssm_task_identity' AND c.relkind='r' LOOP
   IF has_table_privilege(application_role,object_oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') THEN RAISE EXCEPTION 'Private identity table application access remains'; END IF;
  END LOOP;
  FOR object_oid IN SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='_ssm_task_identity' LOOP
   IF has_function_privilege(application_role,object_oid,'EXECUTE') THEN RAISE EXCEPTION 'Private identity function application execution remains'; END IF;
  END LOOP;
 END LOOP;
 FOR object_oid IN SELECT c.oid FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='_ssm_task_identity' AND c.relkind='r' LOOP
  EXECUTE format('SELECT EXISTS(SELECT 1 FROM %s)',object_oid::regclass) INTO populated;
  IF populated THEN RAISE EXCEPTION 'Unexpected private identity backfill'; END IF;
 END LOOP;
END;
$bundle_postflight$;

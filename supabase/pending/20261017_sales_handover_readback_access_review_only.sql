-- REVIEW ONLY. New own-actor read access requires specific managed approval.
-- Execute after the exact reviewed default-closed reader installation.
DO $reader_access$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE oid='public.read_sales_feasibility_handover_receipt(uuid,uuid,uuid,uuid,uuid)'::regprocedure
   AND prosecdef AND provolatile='s' AND proconfig=ARRAY['search_path=public, pg_temp']) THEN
  RAISE EXCEPTION 'Handover reader authority is incompatible';
 END IF;
 IF has_function_privilege('anon','public.read_sales_feasibility_handover_receipt(uuid,uuid,uuid,uuid,uuid)','EXECUTE')
 OR has_function_privilege('service_role','public.read_sales_feasibility_handover_receipt(uuid,uuid,uuid,uuid,uuid)','EXECUTE')
 OR has_table_privilege('authenticated','public.sales_feasibility_handover_requests','SELECT,INSERT,UPDATE,DELETE')
 OR has_table_privilege('anon','public.sales_feasibility_handover_requests','SELECT,INSERT,UPDATE,DELETE') THEN
  RAISE EXCEPTION 'Handover receipt access is not closed';
 END IF;
END;
$reader_access$;
GRANT EXECUTE ON FUNCTION public.read_sales_feasibility_handover_receipt(uuid,uuid,uuid,uuid,uuid) TO authenticated;

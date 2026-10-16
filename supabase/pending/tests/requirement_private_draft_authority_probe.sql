\set ON_ERROR_STOP on
BEGIN;
SET LOCAL lock_timeout='500ms';
DO $probe$
DECLARE r public.requirement_feasibility_reviews%ROWTYPE;
BEGIN
 SELECT review.* INTO STRICT r FROM public.requirement_feasibility_reviews review JOIN public.sales_feasibility_handover_requests receipt ON receipt.requirement_id=review.requirement_id WHERE receipt.request_key='00000000-0000-4000-8000-000000000198';
 IF pg_try_advisory_xact_lock(hashtextextended('sales-feasibility-requirement-root:'||r.requirement_id::text,0)) THEN RAISE EXCEPTION 'Authority context overlap not observed'; END IF;
 BEGIN
  UPDATE public.employees SET employment_status='INACTIVE' WHERE user_id='00000000-0000-4000-8000-000000000062';
  RAISE EXCEPTION 'Active employee mutation bypassed held authority';
 EXCEPTION WHEN lock_not_available THEN NULL; END;
 BEGIN
  UPDATE public.departments SET is_active=false WHERE id=r.department_id;
  RAISE EXCEPTION 'Active department mutation bypassed held authority';
 EXCEPTION WHEN lock_not_available THEN NULL; END;
 BEGIN
  DELETE FROM public.employee_departments WHERE department_id=r.department_id;
  RAISE EXCEPTION 'Membership deletion bypassed held authority';
 EXCEPTION WHEN lock_not_available THEN NULL; END;
 BEGIN
  UPDATE public.customer_requirement_revisions SET requirement_data='{"tampered":true}'::jsonb WHERE id=r.source_revision_id;
  RAISE EXCEPTION 'Pinned requirement body mutation bypassed held source';
 EXCEPTION WHEN lock_not_available THEN NULL; END;
 BEGIN
  UPDATE public.master_specification_versions SET specification_data='{"tampered":true}'::jsonb WHERE id=r.master_specification_version_id;
  RAISE EXCEPTION 'Pinned Master body mutation bypassed held source';
 EXCEPTION WHEN lock_not_available THEN NULL; END;
 RAISE NOTICE 'PRIVATE_DRAFT_AUTHORITY_LOCK_PASS overlap=observed employee_status,department_active,membership_delete,pinned_requirement,pinned_master=blocked sqlstate=55P03';
END;
$probe$;
ROLLBACK;

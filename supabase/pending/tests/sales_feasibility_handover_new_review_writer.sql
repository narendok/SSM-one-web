\set ON_ERROR_STOP on
BEGIN;
SELECT pg_advisory_xact_lock(20261015, 16);
INSERT INTO public.departments(id,is_active) VALUES ('00000000-0000-4000-8000-000000000064',true);
INSERT INTO public.requirement_feasibility_reviews(requirement_id,department_id,reviewer_user_id,status,created_by,source_revision_id,source_revision_number,master_specification_version_id,master_specification_version_number,applicable_workstreams)
SELECT requirement_id,'00000000-0000-4000-8000-000000000064','00000000-0000-4000-8000-000000000062','pending','00000000-0000-4000-8000-000000000050',source_revision_id,source_revision_number,master_specification_version_id,master_specification_version_number,applicable_workstreams
FROM public.sales_feasibility_handover_requests WHERE request_key='00000000-0000-4000-8000-000000000198';
COMMIT;
\echo SALES_FEASIBILITY_HANDOVER_ROOT_PHANTOM_WRITER_COMMITTED_AFTER_GUARD

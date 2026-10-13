\set ON_ERROR_STOP on
BEGIN;
INSERT INTO public.departments VALUES ('00000000-0000-4000-8000-000000000210','HW',true);
INSERT INTO public.employees VALUES
 ('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000201','ACTIVE'),
 ('00000000-0000-4000-8000-000000000202','00000000-0000-4000-8000-000000000202','ACTIVE'),
 ('00000000-0000-4000-8000-000000000203','00000000-0000-4000-8000-000000000203','ACTIVE');
INSERT INTO public.employee_departments VALUES
 ('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000210'),
 ('00000000-0000-4000-8000-000000000202','00000000-0000-4000-8000-000000000210'),
 ('00000000-0000-4000-8000-000000000203','00000000-0000-4000-8000-000000000210');
INSERT INTO public.projects VALUES ('00000000-0000-4000-8000-000000000220','active');
INSERT INTO public.project_team_members VALUES
 ('00000000-0000-4000-8000-000000000220','00000000-0000-4000-8000-000000000201'),
 ('00000000-0000-4000-8000-000000000220','00000000-0000-4000-8000-000000000203');
INSERT INTO public.permission_test_grants VALUES ('00000000-0000-4000-8000-000000000201','documents.edit');

SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000201',false);
CREATE TEMP TABLE initial_assignment AS
SELECT public.assign_project_structured_docx_responsibility(
  '00000000-0000-4000-8000-000000000220','00000000-0000-4000-8000-000000000210',
  'BOM','00000000-0000-4000-8000-000000000202',NULL,
  '00000000-0000-4000-8000-000000000230'
) AS id;

SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000203',false);
DO $$ BEGIN
  BEGIN
    PERFORM public.reassign_project_structured_docx_responsibility(
      (SELECT id FROM initial_assignment),1,'00000000-0000-4000-8000-000000000203',NULL,
      '00000000-0000-4000-8000-000000000231'
    );
    RAISE EXCEPTION 'Unassigned manager actor reassigned responsibility';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Scoped department document-management authority%' THEN RAISE; END IF;
  END;
END $$;

SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000201',false);
CREATE TEMP TABLE reassigned AS
SELECT public.reassign_project_structured_docx_responsibility(
  (SELECT id FROM initial_assignment),1,'00000000-0000-4000-8000-000000000203',
  '00000000-0000-4000-8000-000000000202','00000000-0000-4000-8000-000000000232'
) AS id;
DO $$ BEGIN
  IF (SELECT status FROM public.structured_lifecycle_docx_responsibility_assignments WHERE id=(SELECT id FROM initial_assignment)) <> 'REVOKED'
     OR (SELECT responsibility_revision FROM public.structured_lifecycle_docx_responsibility_assignments WHERE id=(SELECT id FROM reassigned)) <> 2
     OR (SELECT count(*) FROM public.structured_lifecycle_docx_responsibility_update_audit_events) <> 1 THEN
    RAISE EXCEPTION 'Authorized reassignment did not atomically preserve revision and audit';
  END IF;
  BEGIN
    PERFORM public.reassign_project_structured_docx_responsibility(
      (SELECT id FROM reassigned),1,'00000000-0000-4000-8000-000000000202',NULL,
      '00000000-0000-4000-8000-000000000233'
    );
    RAISE EXCEPTION 'Stale revision reassignment accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Project structured DOCX responsibility revision is stale%' THEN RAISE; END IF;
  END;
  IF (SELECT count(*) FROM public.structured_lifecycle_docx_responsibility_update_receipts) <> 1
     OR (SELECT count(*) FROM public.structured_lifecycle_docx_responsibility_update_audit_events) <> 1
     OR (SELECT count(*) FROM public.structured_lifecycle_docx_responsibility_assignments WHERE scope_type='PROJECT' AND project_id='00000000-0000-4000-8000-000000000220' AND document_kind='BOM' AND status='ACTIVE') <> 1 THEN
    RAISE EXCEPTION 'Denied stale reassignment left mutable residue';
  END IF;
END $$;
ROLLBACK;
\echo STRUCTURED_LIFECYCLE_DOCX_PROJECT_RESPONSIBILITY_UPDATE_LOCAL_ASSERTIONS_PASS
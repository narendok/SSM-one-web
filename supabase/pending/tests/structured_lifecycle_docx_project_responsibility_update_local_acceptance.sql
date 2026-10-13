\set ON_ERROR_STOP on
BEGIN;
INSERT INTO public.departments VALUES ('00000000-0000-4000-8000-000000000210','HW',true);
INSERT INTO public.employees VALUES
 ('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000201','ACTIVE'),
 ('00000000-0000-4000-8000-000000000202','00000000-0000-4000-8000-000000000202','ACTIVE'),
 ('00000000-0000-4000-8000-000000000203','00000000-0000-4000-8000-000000000203','ACTIVE'),
 ('00000000-0000-4000-8000-000000000204','00000000-0000-4000-8000-000000000204','SUSPENDED'),
 ('00000000-0000-4000-8000-000000000205','00000000-0000-4000-8000-000000000205','ACTIVE'),
 ('00000000-0000-4000-8000-000000000206','00000000-0000-4000-8000-000000000206','ACTIVE');
INSERT INTO public.employee_departments VALUES
 ('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000210'),
 ('00000000-0000-4000-8000-000000000202','00000000-0000-4000-8000-000000000210'),
 ('00000000-0000-4000-8000-000000000203','00000000-0000-4000-8000-000000000210'),
 ('00000000-0000-4000-8000-000000000204','00000000-0000-4000-8000-000000000210'),
 ('00000000-0000-4000-8000-000000000205','00000000-0000-4000-8000-000000000210');
INSERT INTO public.departments VALUES ('00000000-0000-4000-8000-000000000211','QA',true);
INSERT INTO public.employee_departments VALUES ('00000000-0000-4000-8000-000000000206','00000000-0000-4000-8000-000000000211');
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
DO $$ BEGIN
  BEGIN
    PERFORM public.reassign_project_structured_docx_responsibility(NULL,1,'00000000-0000-4000-8000-000000000203',NULL,'00000000-0000-4000-8000-000000000240');
    RAISE EXCEPTION 'NULL assignment target accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Invalid project structured DOCX responsibility reassignment payload%' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.reassign_project_structured_docx_responsibility((SELECT id FROM initial_assignment),NULL,'00000000-0000-4000-8000-000000000203',NULL,'00000000-0000-4000-8000-000000000241');
    RAISE EXCEPTION 'NULL expected revision accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Invalid project structured DOCX responsibility reassignment payload%' THEN RAISE; END IF;
  END;
  PERFORM set_config('request.jwt.claim.sub','',true);
  BEGIN
    PERFORM public.reassign_project_structured_docx_responsibility((SELECT id FROM initial_assignment),1,'00000000-0000-4000-8000-000000000203',NULL,'00000000-0000-4000-8000-000000000242');
    RAISE EXCEPTION 'NULL actor reassigned responsibility';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Authentication required%' THEN RAISE; END IF;
  END;
  PERFORM set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000201',true);
  BEGIN
    PERFORM public.reassign_project_structured_docx_responsibility((SELECT id FROM initial_assignment),1,'00000000-0000-4000-8000-000000000204',NULL,'00000000-0000-4000-8000-000000000243');
    RAISE EXCEPTION 'Inactive responsible employee accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Assigned responsible and reviewer employees must be active department project-team members%' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.reassign_project_structured_docx_responsibility((SELECT id FROM initial_assignment),1,'00000000-0000-4000-8000-000000000206',NULL,'00000000-0000-4000-8000-000000000244');
    RAISE EXCEPTION 'Wrong-department responsible employee accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Assigned responsible and reviewer employees must be active department project-team members%' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.reassign_project_structured_docx_responsibility((SELECT id FROM initial_assignment),1,'00000000-0000-4000-8000-000000000205',NULL,'00000000-0000-4000-8000-000000000245');
    RAISE EXCEPTION 'Non-team responsible employee accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Assigned responsible and reviewer employees must be active department project-team members%' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.reassign_project_structured_docx_responsibility((SELECT id FROM initial_assignment),1,'00000000-0000-4000-8000-000000000203','00000000-0000-4000-8000-000000000204','00000000-0000-4000-8000-000000000246');
    RAISE EXCEPTION 'Inactive reviewer accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Assigned responsible and reviewer employees must be active department project-team members%' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.reassign_project_structured_docx_responsibility((SELECT id FROM initial_assignment),1,'00000000-0000-4000-8000-000000000203','00000000-0000-4000-8000-000000000206','00000000-0000-4000-8000-000000000247');
    RAISE EXCEPTION 'Wrong-department reviewer accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Assigned responsible and reviewer employees must be active department project-team members%' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.reassign_project_structured_docx_responsibility((SELECT id FROM initial_assignment),1,'00000000-0000-4000-8000-000000000203','00000000-0000-4000-8000-000000000205','00000000-0000-4000-8000-000000000248');
    RAISE EXCEPTION 'Non-team reviewer accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Assigned responsible and reviewer employees must be active department project-team members%' THEN RAISE; END IF;
  END;
END $$;
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
  IF (SELECT public.reassign_project_structured_docx_responsibility(
    (SELECT id FROM initial_assignment),1,'00000000-0000-4000-8000-000000000203',
    '00000000-0000-4000-8000-000000000202','00000000-0000-4000-8000-000000000232'
  )) <> (SELECT id FROM reassigned) THEN
    RAISE EXCEPTION 'Exact reassignment replay did not return its original replacement';
  END IF;
  BEGIN
    PERFORM public.reassign_project_structured_docx_responsibility(
      (SELECT id FROM initial_assignment),1,'00000000-0000-4000-8000-000000000202',NULL,
      '00000000-0000-4000-8000-000000000232'
    );
    RAISE EXCEPTION 'Reassignment request-key conflict accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Responsibility reassignment request key conflicts%' THEN RAISE; END IF;
  END;
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
CREATE TEMP TABLE preserved_revision AS
SELECT responsibility_revision, responsible_employee_id, reviewer_employee_id
FROM public.structured_lifecycle_docx_responsibility_assignments
WHERE id = (SELECT id FROM reassigned);
SELECT public.revoke_structured_lifecycle_docx_responsibility(
  (SELECT id FROM reassigned),'00000000-0000-4000-8000-000000000249'
);
DO $$ BEGIN
  IF (SELECT status FROM public.structured_lifecycle_docx_responsibility_assignments WHERE id=(SELECT id FROM reassigned)) <> 'REVOKED'
     OR (SELECT responsibility_revision FROM public.structured_lifecycle_docx_responsibility_assignments WHERE id=(SELECT id FROM reassigned)) <> (SELECT responsibility_revision FROM preserved_revision)
     OR (SELECT responsible_employee_id FROM public.structured_lifecycle_docx_responsibility_assignments WHERE id=(SELECT id FROM reassigned)) <> (SELECT responsible_employee_id FROM preserved_revision)
     OR (SELECT reviewer_employee_id FROM public.structured_lifecycle_docx_responsibility_assignments WHERE id=(SELECT id FROM reassigned)) <> (SELECT reviewer_employee_id FROM preserved_revision) THEN
    RAISE EXCEPTION 'Revocation did not preserve immutable historical assignment revision';
  END IF;
  BEGIN
    PERFORM * FROM public.resolve_structured_lifecycle_docx_registry_scope(
      '00000000-0000-4000-8000-000000000250','00000000-0000-4000-8000-000000000251','BOM',
      (SELECT id FROM reassigned),'00000000-0000-4000-8000-000000000252','HW-BOM',1,repeat('e',64),repeat('f',64)
    );
    RAISE EXCEPTION 'Revoked responsibility assignment permitted read or download scope';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Current assigned-person DOCX authority is unavailable%' THEN RAISE; END IF;
  END;
END $$;
ROLLBACK;
\echo STRUCTURED_LIFECYCLE_DOCX_PROJECT_RESPONSIBILITY_UPDATE_LOCAL_ASSERTIONS_PASS
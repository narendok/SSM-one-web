\set ON_ERROR_STOP on
DO $$ BEGIN
 IF (SELECT count(*) FROM public.structured_lifecycle_docx_responsibility_assignments WHERE project_id='00000000-0000-4000-8000-000000000120' AND document_kind='BOM' AND status='ACTIVE')<>1 THEN RAISE EXCEPTION 'Concurrent assignment allowed more than one active root'; END IF;
 IF (SELECT count(*) FROM public.structured_lifecycle_docx_registry_audit_events WHERE assignment_id=(SELECT id FROM public.structured_lifecycle_docx_responsibility_assignments WHERE project_id='00000000-0000-4000-8000-000000000120' AND document_kind='BOM'))<>1 THEN RAISE EXCEPTION 'Concurrent assignment did not preserve exactly one audit receipt'; END IF;
END $$;
\echo STRUCTURED_LIFECYCLE_DOCX_REGISTRY_CONCURRENCY_ASSERTIONS_PASS

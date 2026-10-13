\set ON_ERROR_STOP on
DO $$ BEGIN
  IF (SELECT count(*) FROM public.structured_lifecycle_docx_responsibility_assignments WHERE project_id='00000000-0000-4000-8000-000000000320' AND document_kind='BOM' AND status='ACTIVE') <> 1
     OR (SELECT count(*) FROM public.structured_lifecycle_docx_responsibility_assignments WHERE project_id='00000000-0000-4000-8000-000000000320' AND document_kind='BOM' AND responsibility_revision=2) <> 1
     OR (SELECT count(*) FROM public.structured_lifecycle_docx_responsibility_update_receipts) <> 1
     OR (SELECT count(*) FROM public.structured_lifecycle_docx_responsibility_update_audit_events) <> 1 THEN
    RAISE EXCEPTION 'Simultaneous reassignment did not yield one active replacement and one receipt/audit';
  END IF;
END $$;
\echo STRUCTURED_LIFECYCLE_DOCX_PROJECT_RESPONSIBILITY_UPDATE_CONCURRENCY_ASSERTIONS_PASS
\set ON_ERROR_STOP on
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000401',false);
SELECT public.reassign_project_structured_docx_responsibility(
  (SELECT id FROM public.structured_lifecycle_docx_responsibility_assignments
   WHERE project_id='00000000-0000-4000-8000-000000000420' AND document_kind='BOM' AND responsibility_revision=1),
  1, :'responsible_employee_id'::uuid, NULL, :'request_key'::uuid
);
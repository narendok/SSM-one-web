\set ON_ERROR_STOP on
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000101',false);
SELECT public.assign_project_structured_docx_responsibility('00000000-0000-4000-8000-000000000120','00000000-0000-4000-8000-000000000110','BOM','00000000-0000-4000-8000-000000000102',NULL,:'request_key');

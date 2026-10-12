#!/usr/bin/env python3
from pathlib import Path

sql = Path(__file__).parents[1] / "20261012_structured_lifecycle_docx_private_object_enforcement.sql"
text = sql.read_text()
required = [
    "AS RESTRICTIVE FOR SELECT TO authenticated",
    "AS RESTRICTIVE FOR INSERT TO authenticated",
    "AS RESTRICTIVE FOR UPDATE TO authenticated",
    "AS RESTRICTIVE FOR DELETE TO authenticated",
    "NOT public.is_sales_structured_docx_request_path(bucket_id, name)",
    "NOT EXISTS (SELECT 1 FROM storage.objects object_row",
    "assignment_row.status = 'ACTIVE'",
    "employee.user_id = v_actor",
    "object_row.version = p_object_version",
    "REVOKE ALL ON FUNCTION public.assert_sales_structured_docx_current_path_create_only",
]
for item in required:
    if item not in text:
        raise SystemExit(f"missing required DOCX private-object enforcement: {item}")
if "CREATE POLICY sales_structured_docx_update_restrictive" not in text or "CREATE POLICY sales_structured_docx_delete_restrictive" not in text:
    raise SystemExit("missing immutable update/delete policies")
print("STRUCTURED_LIFECYCLE_DOCX_PRIVATE_OBJECT_ENFORCEMENT_STATIC_PASS=true")
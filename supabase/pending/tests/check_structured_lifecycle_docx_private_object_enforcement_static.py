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
    "Pre-insert authorization only",
    "Post-upload verifier boundary",
    "assert_sales_structured_docx_uploaded_object",
    "Current actor no longer owns an active verified DOCX request path",
    "assignment_row.status = 'ACTIVE'",
    "employee.user_id = v_actor",
    "object_row.version = p_object_version",
    "sales_structured_docx_drive_nodes_read_restrictive",
    "sales_structured_docx_drive_revisions_read_restrictive",
    "sales_structured_docx_registers_read_restrictive",
    "GRANT EXECUTE ON FUNCTION public.assert_sales_structured_docx_current_path_create_only(uuid,text,text,text) TO authenticated, service_role;",
    "GRANT EXECUTE ON FUNCTION public.can_stage_sales_structured_docx_object(text,text) TO authenticated, service_role;",
    "GRANT EXECUTE ON FUNCTION public.can_read_sales_structured_docx_object(text,text) TO authenticated, service_role;",
]
for item in required:
    if item not in text:
        raise SystemExit(f"missing required DOCX private-object enforcement: {item}")
if "CREATE POLICY sales_structured_docx_update_restrictive" not in text or "CREATE POLICY sales_structured_docx_delete_restrictive" not in text:
    raise SystemExit("missing immutable update/delete policies")
if "-draft\\\\.docx" in text:
    raise SystemExit("DOCX regex over-escapes its literal dot")
print("STRUCTURED_LIFECYCLE_DOCX_PRIVATE_OBJECT_ENFORCEMENT_STATIC_PASS=true")
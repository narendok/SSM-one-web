#!/usr/bin/env python3
"""Static guard for the uninstalled structured DOCX registry proposal."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
sql = (root / "20261012_structured_lifecycle_docx_registry_contract.sql").read_text()
bridge = Path("src/lib/structured-lifecycle-docx-private-object-bridge.server.ts").read_text()


def need(value: str, label: str):
    if value not in sql:
        raise SystemExit(f"MISSING {label}")


def forbid(value: str, label: str):
    if value in sql:
        raise SystemExit(f"FORBIDDEN {label}")

for table in (
    "structured_lifecycle_docx_responsibility_assignments",
    "structured_lifecycle_docx_template_pins",
    "structured_lifecycle_docx_registry_audit_events",
):
    need(f"CREATE TABLE public.{table}", table)
    need(f"GRANT ALL ON public.{table} TO service_role;", f"{table} service-only grant")
    need(f"ALTER TABLE public.{table} ENABLE ROW LEVEL SECURITY;", f"{table} RLS")

for primitive in (
    "department_process_templates", "department_process_template_document_revisions",
    "employees", "employee_departments", "project_team_members",
    "responsible_employee_id", "reviewer_employee_id", "active_document_revision_id",
    "FOR UPDATE", "Current immutable approved template pin", "extensions.gen_random_uuid()",
):
    need(primitive, primitive)

for kind in ("'SOR'", "'NDA'", "'PRS'", "'BOM'", "'DFMEA'", "'ANNUAL_SKILL_MATRIX'"):
    need(kind, kind)

need("assert_structured_lifecycle_docx_registry_manager", "caller-authenticated registry manager")
for required in ("Active project-team membership", "Scoped department document-management authority", "pg_advisory_xact_lock", "Registry request key conflicts", "Assigned responsible and reviewer employees must be active department members"):
    need(required, required)

for signature in (
    "public.resolve_structured_lifecycle_docx_registry_scope(uuid,text,uuid,uuid,text,integer,text,text)",
    "public.assign_structured_lifecycle_docx_responsibility(uuid,uuid,text,uuid,uuid,uuid)",
    "public.revoke_structured_lifecycle_docx_responsibility(uuid,uuid)",
    "public.approve_structured_lifecycle_docx_template_pin(uuid,text,uuid,uuid,text,uuid)",
    "public.revoke_structured_lifecycle_docx_template_pin(uuid,uuid)",
):
    need(f"REVOKE ALL ON FUNCTION {signature} FROM PUBLIC, anon, authenticated, service_role;", signature)
    forbid(f"GRANT EXECUTE ON FUNCTION {signature}", f"pre-grant {signature}")

for forbidden in ("CREATE POLICY", "INSERT INTO public.document_control_registers", "sales_opportunity_structured_draft_materializations", "GRANT ALL ON public.structured_lifecycle_docx_responsibility_assignments TO authenticated"):
    forbid(forbidden, forbidden)

if "resolveCurrentRegistryAssignment" not in bridge or "StructuredDocxRegistryScope" not in bridge:
    raise SystemExit("MISSING bridge registry contract")
print("STRUCTURED_LIFECYCLE_DOCX_REGISTRY_STATIC_GUARD_PASS")

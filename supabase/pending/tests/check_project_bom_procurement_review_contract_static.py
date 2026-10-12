#!/usr/bin/env python3
"""Static guard for the source-only project BOM Procurement review contract."""
from pathlib import Path

sql = (Path(__file__).resolve().parents[1] / "20261012_project_bom_procurement_review_contract.sql").read_text()
checks = {
    "source-only header": "SOURCE-ONLY, UNDEPLOYED REVIEW CONTRACT. DO NOT APPLY." in sql,
    "five additive tables have grant before rls": sql.count("CREATE TABLE public.project_bom_procurement_review_") == 5 and sql.count("ENABLE ROW LEVEL SECURITY") == 5 and sql.count("GRANT ALL ON public.project_bom_procurement_review") >= 5,
    "inspected project-manager assignment scope": all(token in sql for token in ("project_manager_employee_id", "project_team_members", "projects.manage", "employment_status = 'ACTIVE'")),
    "existing rows re-read authoritative catalog values": all(token in sql for token in ("SELECT * INTO v_component FROM public.components", "v_component.part_number", "v_component.manufacturer", "cannot supply derived catalog fields")),
    "new parts remain proposal rows": "source_kind = 'NEW_PART'" in sql and "does not create a part" in sql and "INSERT INTO public.components" not in sql,
    "immutable request snapshot and source pin": all(token in sql for token in ("pinned_bom_number", "pinned_bom_revision", "pinned_bom_updated_at", "project_bom_procurement_review_request_lines", "v_bom_item.matched_component_id", "Source BOM item does not pin the selected authoritative component")),
    "analysis isolates commercial facts": all(token in sql for token in ("availability_state", "cost_state", "sourcing_state", "observed_unit_cost", "currency", "lead_time_days", "alternate_component_id")),
    "stale locking and idempotency": all(token in sql for token in ("pg_advisory_xact_lock", "FOR UPDATE", "The project BOM revision is stale", "Request key conflicts")),
    "transaction audit and receipt": all(token in sql for token in ("project_bom_procurement_review_audit_events", "project_bom_procurement_review_receipts", "payload_hash")),
    "no inventory approval po or bom write": all(token not in sql for token in ("UPDATE public.project_boms", "INSERT INTO public.project_bom_items", "UPDATE public.project_bom_items", "INSERT INTO public.inventory", "UPDATE public.inventory", "INSERT INTO public.purchase_orders", "INSERT INTO public.purchase_requests", "INSERT INTO public.components")),
    "entrypoints execution withheld": all(token in sql for token in ("REVOKE ALL ON FUNCTION public.submit_project_bom_procurement_review", "REVOKE ALL ON FUNCTION public.analyze_project_bom_procurement_review", "REVOKE ALL ON FUNCTION public.decide_project_bom_procurement_review", "No GRANT EXECUTE statement is present")) and "GRANT EXECUTE ON FUNCTION" not in sql,
}
failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("PROJECT_BOM_PROCUREMENT_REVIEW_STATIC_GUARD_FAIL: " + "; ".join(failed))
print("PROJECT_BOM_PROCUREMENT_REVIEW_STATIC_GUARD_PASS=true")

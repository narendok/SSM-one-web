#!/usr/bin/env python3
"""Static guard for the source-only project BOM Procurement review contract."""
from pathlib import Path

sql = (Path(__file__).resolve().parents[1] / "20261012_project_bom_procurement_review_contract.sql").read_text()
concurrency = (Path(__file__).resolve().parent / "run_project_bom_procurement_review_local_concurrency_acceptance.sh").read_text()
checks = {
    "source-only header": "SOURCE-ONLY, UNDEPLOYED REVIEW CONTRACT. DO NOT APPLY." in sql,
    "five additive tables are service-only before rls": sql.count("CREATE TABLE public.project_bom_procurement_review_") == 5 and sql.count("ENABLE ROW LEVEL SECURITY") == 5 and sql.count("GRANT ALL ON public.project_bom_procurement_review") >= 5 and "GRANT SELECT ON public.project_bom_procurement_review" not in sql,
    "inspected project-manager assignment scope": all(token in sql for token in ("project_manager_employee_id", "project_team_members", "projects.manage", "employment_status = 'ACTIVE'")),
    "existing rows re-read authoritative catalog values": all(token in sql for token in ("SELECT * INTO v_component FROM public.components", "v_component.part_number", "v_component.manufacturer", "cannot supply derived catalog fields")),
    "new parts remain proposal rows": "source_kind = 'NEW_PART'" in sql and "does not create a part" in sql and "INSERT INTO public.components" not in sql,
    "immutable request snapshot and source pin": all(token in sql for token in ("pinned_bom_number", "pinned_bom_revision", "pinned_bom_updated_at", "project_bom_procurement_review_request_lines", "v_bom_item.matched_component_id", "Source BOM item does not pin the selected authoritative component")),
    "analysis isolates commercial facts": all(token in sql for token in ("availability_state", "cost_state", "sourcing_state", "observed_unit_cost", "currency", "lead_time_days", "alternate_component_id")),
    "protected requester or reviewer read returns immutable pin and latest analysis": all(token in sql for token in ("project_bom_procurement_review_read_scope", "submitted_by = p_actor", "read_project_bom_procurement_review", "pinnedBomRevision", "ORDER BY analysis.analysis_revision DESC", "Procurement request is unavailable")),
    "analysis revisions reject stale updates": all(token in sql for token in ("p_expected_analysis_revision integer", "The Procurement line analysis revision is stale", "v_current_analysis_revision+1")),
    "allow pins each reviewed analysis and exact bom source state": all(token in sql for token in ("p_expected_bom_updated_at timestamptz", "p_reviewed_analysis_revisions jsonb", "project_bom_procurement_review_canonical_decision_analyses", "Reviewed Procurement analysis is missing or stale", "The project BOM source is stale", "reviewed_analysis_revisions")),
    "stale locking and idempotency": all(token in sql for token in ("pg_advisory_xact_lock", "FOR UPDATE", "The project BOM revision is stale", "Request key conflicts")),
    "isolated two-session stale-decision evidence": all(token in concurrency for token in ("ANALYZE_VS_ALLOW_STALE_PIN_PASS=true", "SAME_REVISION_BOM_MANUAL_EDIT_STALE_DECISION_PASS=true", "Reviewed Procurement analysis is missing or stale", "The project BOM source is stale", "action='ALLOW'")),
    "transaction audit and receipt": all(token in sql for token in ("project_bom_procurement_review_audit_events", "project_bom_procurement_review_receipts", "payload_hash", "v_decision='ALLOW' THEN 'ALLOWED_PENDING_HARDWARE_SELECTION' ELSE 'DENIED'")),
    "no inventory approval po or bom write": all(token not in sql for token in ("UPDATE public.project_boms", "INSERT INTO public.project_bom_items", "UPDATE public.project_bom_items", "INSERT INTO public.inventory", "UPDATE public.inventory", "INSERT INTO public.purchase_orders", "INSERT INTO public.purchase_requests", "INSERT INTO public.components")),
    "direct tables remain private and entrypoints execution withheld": all(token in sql for token in ("No authenticated table grants or SELECT policies", "REVOKE ALL ON FUNCTION public.project_bom_procurement_review_read_scope", "REVOKE ALL ON FUNCTION public.submit_project_bom_procurement_review", "REVOKE ALL ON FUNCTION public.analyze_project_bom_procurement_review", "REVOKE ALL ON FUNCTION public.decide_project_bom_procurement_review", "REVOKE ALL ON FUNCTION public.read_project_bom_procurement_review", "No GRANT EXECUTE statement is present")) and "GRANT EXECUTE ON FUNCTION" not in sql and "CREATE POLICY project_bom_procurement_review" not in sql,
}
failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("PROJECT_BOM_PROCUREMENT_REVIEW_STATIC_GUARD_FAIL: " + "; ".join(failed))
print("PROJECT_BOM_PROCUREMENT_REVIEW_STATIC_GUARD_PASS=true")

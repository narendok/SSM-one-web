#!/usr/bin/env python3
"""Static guard for the unapplied project BOM Procurement review contract."""
from pathlib import Path

sql = (Path(__file__).resolve().parents[1] / "20261012_project_bom_procurement_review_contract.sql").read_text()

checks = {
    "source-only header": "SOURCE-ONLY, UNDEPLOYED PROPOSAL. DO NOT APPLY." in sql,
    "all additive tables are granted before RLS": sql.count("GRANT SELECT ON public.project_bom_procurement_review") >= 5 and sql.count("ENABLE ROW LEVEL SECURITY") == 5,
    "request is BOM revision pinned": all(token in sql for token in ("project_bom_id", "pinned_bom_number", "pinned_bom_revision", "p_expected_bom_revision")),
    "existing components are identifiers only": "source_kind IN ('EXISTING_COMPONENT', 'NEW_PART')" in sql and "component_id uuid" in sql,
    "analysis covers MPN cost and sourcing": all(token in sql for token in ("mpn text NOT NULL", "availability_state", "cost_state", "sourcing_state", "observed_unit_cost", "supplier_name", "lead_time_days", "alternate_component_id")),
    "unknown cannot become zero": "unknown is PENDING/TBC/UNAVAILABLE rather than zero" in sql,
    "allow and deny are not approvals": "ALLOWED_PENDING_HARDWARE_SELECTION" in sql and "not a technical approval" in sql,
    "idempotency and audit are additive": all(token in sql for token in ("request_key uuid PRIMARY KEY", "payload_hash", "project_bom_procurement_review_audit_events", "authorize before replay")),
    "inventory and order mutation paths absent": all(token not in sql for token in ("INSERT INTO public.components", "UPDATE public.components", "project_bom_items", "inventory_lots", "stock_history", "purchase_orders", "purchase_order_items")),
    "execution remains withheld": "EXECUTE remains intentionally ungranted" in sql and "GRANT EXECUTE ON FUNCTION" not in sql,
    "caller acceptance is explicit": all(token in sql for token in ("stale-BOM denial", "changed replay conflict", "revoke-after-wait", "all-or-nothing rollback")),
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("PROJECT_BOM_PROCUREMENT_REVIEW_STATIC_GUARD_FAIL: " + "; ".join(failed))
print("PROJECT_BOM_PROCUREMENT_REVIEW_STATIC_GUARD_PASS=true")
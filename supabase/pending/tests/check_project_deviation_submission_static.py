#!/usr/bin/env python3
"""Static guard for the unapplied deviation submission proposal."""
from pathlib import Path

pending = Path(__file__).resolve().parents[1]
sql = (pending / "20261011_project_deviation_submission.sql").read_text()
fixture = (Path(__file__).resolve().parent / "project_deviation_submission_local_fixture.sql").read_text()
acceptance = (Path(__file__).resolve().parent / "project_deviation_submission_local_acceptance.sql").read_text()
runner = (Path(__file__).resolve().parent / "run_project_deviation_submission_local_acceptance.sh").read_text()

checks = {
    "source-only header": "SOURCE-ONLY, UNDEPLOYED PROPOSAL. DO NOT APPLY." in sql,
    "all additive tables have grants": sql.count("GRANT SELECT ON public.project_deviation_submission") == 5,
    "all new tables have RLS": sql.count("ENABLE ROW LEVEL SECURITY") == 5,
    "protected submit function has no execute grant": "GRANT EXECUTE ON FUNCTION public.submit_project_deviation" not in sql,
    "only proposed submission state exists": "status = 'PROPOSED_SUBMITTED'" in sql and "APPROVED" not in sql.split("CREATE OR REPLACE FUNCTION public.project_deviation_submission_canonical_payload")[0],
    "committed project predicate is exact": all(token in sql for token in ("baseline.status = 'project_initiated'", "baseline.approved_by IS NOT NULL", "baseline.approved_at IS NOT NULL", "handover.status = 'completed'", "handover.project_id = project.id", "opportunity.customer_id = project.customer_id", "requirement.customer_id = project.customer_id")),
    "active manager and exact team are required": all(token in sql for token in ("manager.user_id = p_actor", "manager.employment_status = 'ACTIVE'", "team.project_id = project.id", "team.employee_id = manager.id")),
    "source revision is project controlled and pinned": all(token in sql for token in ("source_register.project_id = project.id", "source_register.document_status = 'APPROVED'", "source_revision.id = p_source_document_revision_id", "source_revision.node_id = source_register.drive_node_id", "source_revision.version = source_register.controlled_version")),
    "evidence is exact approved same project": all(token in sql for token in ("evidence_document_register_id", "document_status = 'APPROVED'", "Deviation evidence requires an approved controlled revision owned by the exact project")),
    "immutable exception scope requires one bounded form": all(token in sql for token in ("reason", "risk", "safeguards", "customerImpact", "affectedPartReference", "validFrom", "validUntil", "exactly one affected part scope or validity period")),
    "authorization precedes receipt replay and repeats": sql.index("project_deviation_submission_scope(v_actor") < sql.index("FROM public.project_deviation_submission_request_receipts") and sql.count("project_deviation_submission_scope(v_actor") >= 3,
    "project and request serialization present": "project-deviation-project:" in sql and "project-deviation-request:" in sql,
    "approval rule recorded but not activated": "responsible_technical_authority_and_quality_plus_customer_when_customer_requirements_affected" in sql and all(token not in sql for token in ("qms.approve", "engineering.approve", "customer approval", "approve_project_deviation")),
    "legacy and candidate records untouched": all(token not in sql for token in ("INSERT INTO public.project_change_requests", "UPDATE public.project_change_requests", "component_candidate_", "inventory_lots", "stock_history", "project_bom_items")),
    "local fixture only": "LOCAL DISPOSABLE FIXTURE ONLY" in fixture,
    "acceptance covers replay denials validity evidence and rollback": all(token in acceptance for token in ("Exact replay", "Changed replay", "Cross project source", "Missing validity or part scope", "Inverted validity", "Cross project evidence", "Unauthorized actor", "Receipt failure did not roll back", "ROLLBACK;")),
    "runner is explicitly disposable": "LOCAL_DEVIATION_SUBMISSION_DISPOSABLE" in runner and "/tmp/project_deviation_submission_local_" in runner,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("STATIC_GUARD_FAIL: " + "; ".join(failed))
print("PROJECT_DEVIATION_SUBMISSION_STATIC_GUARD_PASS=true")
#!/usr/bin/env python3
"""Static guard for the unapplied candidate submission contract."""
from pathlib import Path

pending = Path(__file__).resolve().parents[1]
sql = (pending / "20261011_bom_candidate_submission.sql").read_text()
fixture = (Path(__file__).resolve().parent / "bom_candidate_submission_local_fixture.sql").read_text()
acceptance = (Path(__file__).resolve().parent / "bom_candidate_submission_local_acceptance.sql").read_text()
runner = (Path(__file__).resolve().parent / "run_bom_candidate_submission_local_acceptance.sh").read_text()
concurrency = (Path(__file__).resolve().parent / "bom_candidate_submission_local_concurrency_assertions.sql").read_text()
revocation = (Path(__file__).resolve().parent / "bom_candidate_submission_local_revocation_assertions.sql").read_text()

checks = {
    "source-only header": "SOURCE-ONLY, UNDEPLOYED PROPOSAL. DO NOT APPLY." in sql,
    "four additive tables have grants": sql.count("GRANT SELECT ON public.component_candidate") == 4,
    "all new tables have RLS": sql.count("ENABLE ROW LEVEL SECURITY") == 4,
    "function has no execute grant": "GRANT EXECUTE ON FUNCTION public.submit_component_candidate" not in sql,
    "direct inventory paths absent": all(token not in sql for token in ("saveComponentWithStock", "inventory_lots", "stock_history", "component_substitutes", "component_projects")),
    "manual BOM rows are never written": "INSERT INTO public.project_bom_items" not in sql and "UPDATE public.project_bom_items" not in sql and "DELETE FROM public.project_bom_items" not in sql,
    "actual committed statuses are exact": "baseline.status = 'project_initiated'" in sql and "handover.status = 'completed'" in sql,
    "exact source linkage is locked": all(token in sql for token in ("project.requirement_baseline_id", "handover.project_id = project.id", "opportunity.customer_id = project.customer_id", "requirement.customer_id", "FOR UPDATE OF project, bom, baseline, handover")),
    "manager and employee backed team are required": "manager.user_id = p_actor" in sql and "manager.employment_status = 'ACTIVE'" in sql and "team.employee_id = manager.id" in sql,
    "hardware department is explicit": "hardware.code = 'HARDWARE' AND hardware.is_active" in sql,
    "authorization precedes replay": sql.index("component_candidate_submission_scope(v_actor") < sql.index("FROM public.component_candidate_submission_request_receipts"),
    "authorization repeats after waits": sql.count("component_candidate_submission_scope(v_actor") >= 3,
    "project and request are serialized": "component-candidate-project:" in sql and "component-candidate-request:" in sql,
    "canonical payload is immutable revision one": "revision_number integer NOT NULL CHECK (revision_number = 1)" in sql and "component_candidate_submission_canonical_payload" in sql,
    "acceptance covers manual bom replay denials and rollback": all(token in acceptance for token in ("Manual line remains untouched", "Exact replay", "Incomplete handover", "Mismatched project handover", "Unauthorized actor", "Receipt failure did not roll back", "ROLLBACK;")),
    "acceptance covers baseline department and linkage denials": all(token in acceptance for token in ("Baseline without approver", "Baseline without approval time", "Active baseline", "Superseded baseline", "Inactive Hardware department", "Non-Hardware department", "Missing Hardware department", "Mismatched customer lineage", "Mismatched opportunity lineage")),
    "concurrency asserts one persisted result": "BOM_CANDIDATE_SUBMISSION_CONCURRENCY_PASS=true" in concurrency and "Concurrent exact replay wrote more than one header" in concurrency,
    "serialized authority revocation is denied": "BOM_CANDIDATE_SUBMISSION_REVOCATION_PASS=true" in revocation and "Revoked actor created a candidate" in revocation and "candidate_test_waitpoint" in sql,
    "runner is explicitly disposable": "LOCAL_BOM_CANDIDATE_DISPOSABLE" in runner and "/tmp/bom_candidate_submission_local_" in runner,
    "fixture is local only": "LOCAL DISPOSABLE FIXTURE ONLY" in fixture,
}
failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("STATIC_GUARD_FAIL: " + "; ".join(failed))
print("BOM_CANDIDATE_SUBMISSION_STATIC_GUARD_PASS=true")
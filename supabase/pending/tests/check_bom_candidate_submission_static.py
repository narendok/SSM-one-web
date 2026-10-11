#!/usr/bin/env python3
"""Static guard for the unapplied candidate submission contract."""
from pathlib import Path

pending = Path(__file__).resolve().parents[1]
sql = (pending / "20261011_bom_candidate_submission.sql").read_text()
fixture = (Path(__file__).resolve().parent / "bom_candidate_submission_local_fixture.sql").read_text()
acceptance = (Path(__file__).resolve().parent / "bom_candidate_submission_local_acceptance.sql").read_text()
runner = (Path(__file__).resolve().parent / "run_bom_candidate_submission_local_acceptance.sh").read_text()
concurrency = (Path(__file__).resolve().parent / "bom_candidate_submission_local_concurrency_assertions.sql").read_text()
revocation_runner = (Path(__file__).resolve().parent / "run_bom_candidate_submission_local_revocation_wait.sh").read_text()
revocation_worker = (Path(__file__).resolve().parent / "bom_candidate_submission_local_revocation_wait_worker.sql").read_text()
decision_revocation_runner = (Path(__file__).resolve().parent / "run_bom_candidate_decision_local_revocation_wait.sh").read_text()
decision_revocation_worker = (Path(__file__).resolve().parent / "bom_candidate_decision_local_revocation_wait_worker.sql").read_text()
decision_acceptance = (Path(__file__).resolve().parent / "bom_candidate_decision_local_acceptance.sql").read_text()
decision_runner = (Path(__file__).resolve().parent / "run_bom_candidate_decision_local_acceptance.sh").read_text()
decision_concurrency = (Path(__file__).resolve().parent / "bom_candidate_decision_local_concurrency_assertions.sql").read_text()

checks = {
    "source-only header": "SOURCE-ONLY, UNDEPLOYED PROPOSAL. DO NOT APPLY." in sql,
    "all additive tables have grants": sql.count("GRANT SELECT ON public.component_candidate") == 6,
    "all new tables have RLS": sql.count("ENABLE ROW LEVEL SECURITY") == 6,
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
    "acceptance covers baseline department lineage and revoked authority denials": all(token in acceptance for token in ("Baseline without approver", "Baseline without approval time", "Active baseline", "Superseded baseline", "Inactive Hardware department", "Non-Hardware department", "Missing Hardware department", "Mismatched customer lineage", "Mismatched opportunity lineage", "Inactive employee", "Revoked team membership")),
    "concurrency asserts one persisted result": "BOM_CANDIDATE_SUBMISSION_CONCURRENCY_PASS=true" in concurrency and "Concurrent exact replay wrote more than one header" in concurrency,
    "revocation wait uses exact production project lock": all(token in revocation_runner for token in ("component-candidate-project:", "hashtextextended", "pg_locks", "pg_stat_activity", "waiting-on-exact-project-lock")),
    "revocation wait covers new and replay requests": all(token in revocation_runner for token in ("replay_result_returned=false", "new_request_graph_unchanged=true", "000000000191", "000000000192")),
    "revocation worker has no production instrumentation": "candidate_test_wait" not in revocation_worker and "submit_component_candidate" in revocation_worker,
    "runner is explicitly disposable": "LOCAL_BOM_CANDIDATE_DISPOSABLE" in runner and "/tmp/bom_candidate_submission_local_" in runner,
    "fixture is local only": "LOCAL DISPOSABLE FIXTURE ONLY" in fixture,
    "decision permission remains pending only": "VALUES ('engineering.approve'" in sql and "GRANT EXECUTE ON FUNCTION public.decide_component_candidate" not in sql,
    "decision source locks and reauthorizes": all(token in sql for token in ("component-candidate-decision:", "component-candidate-decision-request:", "candidate.submitted_by <> p_actor")) and sql.count("component_candidate_decision_scope(v_actor") >= 4,
    "decision replay precedes terminal status enforcement": sql.index("FROM public.component_candidate_decision_request_receipts") < sql.index("IF v_scope.candidate_status <> 'SUBMITTED'") < sql.index("UPDATE public.component_candidate_submissions SET status = v_target_status"),
    "candidate statuses and audit events are only implemented states": "status IN ('SUBMITTED', 'APPROVED_PENDING_PURCHASE', 'REJECTED')" in sql and "event_type IN ('SUBMITTED', 'APPROVED_PENDING_PURCHASE', 'REJECTED')" in sql and "PROMOTED" not in sql,
    "decision acceptance covers authority replay denials and rollback": all(token in decision_acceptance for token in ("Authorized approve", "Authorized reject", "Missing permission", "Wrong department", "Inactive employee", "Self review", "Wrong revision", "Terminal candidate status", "Exact decision replay after state transition", "Decision payload mismatch", "Decision actor mismatch", "Decision receipt failure did not roll back")),
    "decision concurrency asserts one winner": "BOM_CANDIDATE_DECISION_CONCURRENCY_PASS=true" in decision_concurrency,
    "decision runner is explicitly disposable": "LOCAL_BOM_CANDIDATE_DISPOSABLE" in decision_runner and "/tmp/bom_candidate_decision_local_" in decision_runner,
    "decision revocation wait uses exact production decision lock": all(token in decision_revocation_runner for token in ("component-candidate-decision:", "hashtextextended", "pg_locks", "pg_stat_activity", "waiting-on-exact-decision-lock")),
    "decision revocation wait covers new decision and terminal receipt replay": all(token in decision_revocation_runner for token in ("new_decision_graph_unchanged=true", "replay_history_unchanged=true", "300000000091", "300000000093")),
    "decision revocation worker has no production instrumentation": "candidate_test_wait" not in decision_revocation_worker and "decide_component_candidate" in decision_revocation_worker,
}
failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("STATIC_GUARD_FAIL: " + "; ".join(failed))
print("BOM_CANDIDATE_SUBMISSION_STATIC_GUARD_PASS=true")
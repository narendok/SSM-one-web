#!/usr/bin/env python3
"""Static guard for the unapplied project official decision-log proposal."""
from pathlib import Path

pending = Path(__file__).resolve().parents[1]
sql = (pending / "20261010_project_official_decision_log_contract.sql").read_text()
harness = (Path(__file__).resolve().parent / "project_official_decision_log_contract_acceptance.sql").read_text()

checks = {
    "no service-role ALL on history objects": "GRANT ALL ON TABLE public.project_official_decision_" not in sql,
    "service role is read-only on history objects": all(
        f"GRANT SELECT ON TABLE public.{name} TO service_role;" in sql
        for name in (
            "project_official_decisions",
            "project_official_decision_evidence",
            "project_official_decision_receipts",
        )
    ),
    "public and caller roles are revoked from history objects": all(
        f"REVOKE ALL ON TABLE public.{name} FROM PUBLIC, anon, authenticated, service_role;" in sql
        for name in (
            "project_official_decisions",
            "project_official_decision_evidence",
            "project_official_decision_receipts",
            "project_official_decision_log",
        )
    ),
    "append RPC remains ungranted and fail-closed": (
        "GRANT EXECUTE ON FUNCTION public.append_project_official_decision" not in sql
        and "Official decision append authority is not installed" in sql
    ),
    "caller reads remain denied pending authority": sql.count("USING (false);") == 2 and "WHERE false;" in sql,
    "evidence fields require JSON strings": all(
        f"jsonb_typeof(v_evidence_entry->'{field}') <> 'string'" in sql
        for field in ("evidenceReference", "contributorReference", "scopeReference")
    ),
    "role harness uses SET LOCAL ROLE": "SET LOCAL ROLE authenticated;" in harness,
    "role harness uses transaction-local settings rather than psql variables in DO bodies": (
        "current_setting('project_official_decision.test.cross_project_reader_user_id')" in harness
        and ":'cross_project_reader_user_id'" not in harness.split("DO $role_bound_denials$", 1)[1]
    ),
    "role harness catches only the expected permission SQLSTATE": (
        "EXCEPTION WHEN insufficient_privilege OR OTHERS" not in harness
        and "EXCEPTION WHEN OTHERS" not in harness
        and "SQLSTATE <> '42501'" in harness
    ),
    "outsider view expects privilege denial": "Expected outsider view SELECT privilege denial" in harness,
    "role harness asserts no history mutation": "Role-bound denial changed append-only decision history" in harness,
}
failed = [name for name, passed in checks.items() if not passed]
for name, passed in checks.items():
    print(f"{'PASS' if passed else 'FAIL'}: {name}")
if failed:
    raise SystemExit(1)

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
    "server JSONB adapter rejects client source and amendment identifiers": (
        "CREATE OR REPLACE FUNCTION public.project_official_decision_request_adapter(" in sql
        and "'projectBomItemId', 'sourceLocator', 'amendment'," in sql
        and "'project_bom_item_id', 'source_page_reference'," in sql
    ),
    "adapter stages JSONB shape checks before object or array expansion": (
        "WITH request_shape AS" in sql
        and "WHERE jsonb_typeof(p_request) = 'object'" in sql
        and "WHERE jsonb_typeof(request_fields.p_request->'evidenceReferences') = 'array'" in sql
    ),
    "canonicalization rejects null inputs explicitly": (
        "WHEN p_project_bom_item_id IS NULL OR adapted.payload IS NULL THEN NULL" in sql
        and "CASE WHEN canonical.payload IS NULL THEN NULL ELSE md5" in sql
    ),
    "nonempty evidence remains denied pending provenance": "Evidence provenance authority is not installed" in sql,
    "all known draft overloads are revoked": all(signature in sql for signature in (
        "append_project_official_decision(uuid, uuid, jsonb, uuid)",
        "append_project_official_decision(uuid, text, text, text, text, uuid, text, text, jsonb, uuid)",
        "project_official_decision_canonical_payload(uuid, uuid, jsonb)",
        "project_official_decision_canonical_payload(uuid, text, text, text, text, uuid, text, text, jsonb)",
        "project_official_decision_payload_hash(uuid, uuid, jsonb)",
        "project_official_decision_payload_hash(uuid, text, text, text, text, uuid, text, text, jsonb)",
    )),
    "server receipt canonicalization remains authoritative": (
        "This JSONB result, produced" in sql
        and "is the receipt authority." in sql
        and "Cross-runtime byte/hash parity is intentionally not" in sql
    ),
    "manual request strings are preserved rather than trimmed": (
        "'note', p_request->'note'" in sql
        and "'sourcePageReference', p_request->'sourcePageReference'" in sql
        and "v_adapted_request->>'note'" in sql
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

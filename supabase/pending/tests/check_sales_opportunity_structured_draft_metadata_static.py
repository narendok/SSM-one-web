#!/usr/bin/env python3
"""Source-only structural guard for the pending Structured Sales draft contract."""

from pathlib import Path


PENDING_ROOT = Path(__file__).resolve().parents[1]
SQL = (PENDING_ROOT / "20261009_sales_opportunity_structured_draft_metadata.sql").read_text()
ACCEPTANCE = (Path(__file__).resolve().parent / "sales_opportunity_structured_draft_metadata_acceptance.sql").read_text()


def require(haystack: str, needle: str, label: str) -> None:
    if needle not in haystack:
        raise SystemExit(f"FAIL: missing {label}")


def forbid(haystack: str, needle: str, label: str) -> None:
    if needle in haystack:
        raise SystemExit(f"FAIL: forbidden {label}")


def main() -> None:
    protected_signature = "public.save_sales_opportunity_structured_draft_revision(uuid, uuid, uuid, uuid, text, integer, jsonb, uuid)"
    require(SQL, "SECURITY DEFINER", "protected save function")
    require(SQL, "IF char_length(v_value #>> '{}') > (\n        CASE", "valid payload-length CASE expression")
    require(SQL, "PERFORM pg_advisory_xact_lock", "logical identity lock")
    require(SQL, "FOR UPDATE;\n  IF FOUND THEN", "locked receipt lookup")
    require(SQL, "-- Re-check authorization after waiting on the logical/source locks", "post-lock authorization comment")
    post_lock = SQL.index("-- Re-check authorization after waiting on the logical/source locks")
    receipt_lock = SQL.index("FROM public.sales_opportunity_structured_draft_requests AS request_receipt", post_lock)
    require(SQL[post_lock:receipt_lock], "IF NOT public.has_permission(v_actor_id, 'sales.manage') THEN", "post-lock authorization recheck")
    require(SQL, "v_request.requested_by = v_actor_id", "actor-bound replay")
    require(SQL, "v_request.source_fingerprint = v_source_fingerprint", "source-hash-bound replay")
    require(SQL, "Structured Sales draft revision conflict", "stale revision denial")
    require(SQL, "sales_opportunity_structured_draft_revisions_immutable", "append-only revision trigger")
    require(SQL, f"REVOKE ALL ON FUNCTION {protected_signature} FROM PUBLIC, anon, authenticated, service_role;", "default-revoked save transport")
    forbid(SQL, f"GRANT EXECUTE ON FUNCTION {protected_signature}", "pre-granted save transport")
    for forbidden in ("INSERT INTO public.drive", "INSERT INTO public.storage", "INSERT INTO public.controlled_document", "INSERT INTO public.document_register"):
        forbid(SQL, forbidden, forbidden)
    require(ACCEPTANCE, "second_sales_manager_user_id", "second authorized actor fixture input")
    require(ACCEPTANCE, "Expected separately authorized actor replay to fail", "actor-isolation acceptance")
    require(ACCEPTANCE, "Expected stale revision to fail", "stale revision acceptance")
    require(ACCEPTANCE, "Expected unchanged payload with a new request key to fail", "unchanged-payload new-key acceptance")
    require(ACCEPTANCE, "Expected unknown editable payload field to fail", "unknown-field acceptance")
    require(ACCEPTANCE, "Expected non-string editable payload field to fail", "non-string-field acceptance")
    require(ACCEPTANCE, "Expected raw opportunity/customer source mismatch to fail", "opportunity source-mismatch acceptance")
    require(ACCEPTANCE, "Expected raw Master Specification source mismatch to fail", "specification source-mismatch acceptance")
    require(ACCEPTANCE, "Expected raw Master Specification version source mismatch to fail", "version source-mismatch acceptance")
    require(ACCEPTANCE, "Expected immutable revision update to fail", "append-only acceptance")
    forbid(ACCEPTANCE, "Metadata proposal must not create an activity audit", "unsupported no-audit assertion")
    audit_sql = (PENDING_ROOT / "20261011_sales_opportunity_structured_draft_audit_location.sql").read_text()
    audit_runtime = Path(__file__).resolve().parent / "sales_opportunity_structured_draft_audit_location_local_acceptance.sql"
    audit_runner = Path(__file__).resolve().parent / "run_sales_opportunity_structured_draft_audit_location_local_acceptance.sh"
    audited_signature = "public.save_sales_opportunity_structured_draft_at_location(uuid, uuid, uuid, uuid, text, integer, jsonb, uuid, uuid)"
    require(audit_sql, "sales_opportunity_structured_draft_audit_events", "immutable audit ledger")
    require(audit_sql, "sales_opportunity_structured_draft_revision_locations", "revision-to-private-location binding")
    require(audit_sql, "storage_state text NOT NULL DEFAULT 'NOT_MATERIALIZED'", "no-fake-blob storage boundary")
    require(audit_sql, "The requested private Sales location is unavailable", "private-location scope denial")
    require(audit_sql, "Request key conflicts with a different private Sales location", "location-bound replay denial")
    require(audit_sql, "rolls back the\n  -- underlying revision and receipt", "transaction-coupled rollback boundary")
    require(audit_sql, "sales_opportunity_structured_draft_audit_events_immutable", "append-only audit trigger")
    require(audit_sql, f"REVOKE ALL ON FUNCTION {audited_signature} FROM PUBLIC, anon, authenticated, service_role;", "default-revoked audited save transport")
    forbid(audit_sql, f"GRANT EXECUTE ON FUNCTION {audited_signature}", "pre-granted audited save transport")
    forbid(audit_sql, "INSERT INTO storage.objects", "fake storage-object write")
    require(audit_runtime.read_text(), "STRUCTURED_DRAFT_AUDIT_LOCATION_LOCAL_ACCEPTANCE_PASS", "audit/location local acceptance marker")
    require(audit_runtime.read_text(), "audit mutation accepted", "audit immutability acceptance")
    require(audit_runtime.read_text(), "denied location changed receipt graph", "location denial rollback acceptance")
    require(audit_runner.read_text(), "AUDIT_LOCATION_EXECUTION_COMPLETE=true", "audit/location disposable runner")
    fixture = Path(__file__).resolve().parent / "sales_opportunity_structured_draft_metadata_local_fixture.sql"
    runtime = Path(__file__).resolve().parent / "sales_opportunity_structured_draft_metadata_local_installed_acceptance.sql"
    runner = Path(__file__).resolve().parent / "run_sales_opportunity_structured_draft_metadata_local_acceptance.sh"
    conflict_setup = Path(__file__).resolve().parent / "sales_opportunity_structured_draft_metadata_local_conflict_race_setup.sql"
    conflict_worker = Path(__file__).resolve().parent / "sales_opportunity_structured_draft_metadata_local_conflict_race_worker.sql"
    conflict_assertions = Path(__file__).resolve().parent / "sales_opportunity_structured_draft_metadata_local_conflict_race_assertions.sql"
    conflict_runner = Path(__file__).resolve().parent / "run_sales_opportunity_structured_draft_metadata_local_conflict_race.sh"
    stale_setup = Path(__file__).resolve().parent / "sales_opportunity_structured_draft_metadata_local_stale_revision_race_setup.sql"
    stale_worker = Path(__file__).resolve().parent / "sales_opportunity_structured_draft_metadata_local_stale_revision_race_worker.sql"
    stale_assertions = Path(__file__).resolve().parent / "sales_opportunity_structured_draft_metadata_local_stale_revision_race_assertions.sql"
    stale_runner = Path(__file__).resolve().parent / "run_sales_opportunity_structured_draft_metadata_local_stale_revision_race.sh"
    rollback_setup = Path(__file__).resolve().parent / "sales_opportunity_structured_draft_metadata_local_rollback_setup.sql"
    rollback_acceptance = Path(__file__).resolve().parent / "sales_opportunity_structured_draft_metadata_local_rollback_acceptance.sql"
    rollback_assertions = Path(__file__).resolve().parent / "sales_opportunity_structured_draft_metadata_local_rollback_assertions.sql"
    rollback_runner = Path(__file__).resolve().parent / "run_sales_opportunity_structured_draft_metadata_local_rollback_acceptance.sh"
    require(fixture.read_text(), "LOCAL DISPOSABLE FIXTURE ONLY", "local fixture boundary")
    require(runtime.read_text(), "STRUCTURED_DRAFT_LOCAL_ACCEPTANCE_PASS", "runtime acceptance success marker")
    require(runner.read_text(), "Refusing a non-private local structured-draft acceptance target.", "local-only runner refusal")
    require(conflict_setup.read_text(), "LOCAL DISPOSABLE TWO-WORKER CONFLICT-RACE FIXTURE ONLY", "conflict-race fixture boundary")
    require(conflict_worker.read_text(), "Captures expected SQLSTATE without returning a receipt on denial", "conflict worker receipt denial capture")
    require(conflict_worker.read_text(), "worker actor context mismatch", "conflict worker actor-context assertion")
    require(conflict_assertions.read_text(), "Request key conflicts with a different immutable source, schema, caller, revision, or payload", "conflict receipt assertion")
    require(conflict_assertions.read_text(), "v_drafts <> 1 OR v_revisions <> 1 OR v_requests <> 1", "conflict no-extra-write assertion")
    require(conflict_runner.read_text(), "CONTRACT_CONTENTION_OBSERVED case=%s", "conflict contract lock observation")
    require(conflict_runner.read_text(), "Fixture-only transport; pending contract remains revoked by default.", "conflict fixture-only transport boundary")
    require(stale_setup.read_text(), "LOCAL DISPOSABLE TWO-WORKER STALE-REVISION RACE FIXTURE ONLY", "stale-race fixture boundary")
    require(stale_worker.read_text(), "Captures the stale conflict without a receipt result", "stale worker receipt denial capture")
    require(stale_assertions.read_text(), "Structured Sales draft revision conflict", "stale conflict assertion")
    require(stale_assertions.read_text(), "Original revision history changed during stale-revision race", "stale historical preservation assertion")
    require(stale_assertions.read_text(), "v_drafts <> 1 OR v_revisions <> 2 OR v_requests <> 2", "stale no-loser-write assertion")
    require(stale_runner.read_text(), "CONTRACT_CONTENTION_OBSERVED workers=%s", "stale contract lock observation")
    require(stale_runner.read_text(), "Fixture-only transport; the pending proposal remains fully revoked by default.", "stale fixture-only transport boundary")
    require(rollback_setup.read_text(), "STRUCTURED_DRAFT_TEST_FAILPOINT", "rollback failpoint trigger")
    require(rollback_acceptance.read_text(), "create_revision", "create revision rollback case")
    require(rollback_acceptance.read_text(), "create_receipt", "create receipt rollback case")
    require(rollback_acceptance.read_text(), "update_revision", "update revision rollback case")
    require(rollback_acceptance.read_text(), "update_receipt", "update receipt rollback case")
    require(rollback_assertions.read_text(), "STRUCTURED_DRAFT_ROLLBACK_ACCEPTANCE_PASS", "rollback success marker")
    require(rollback_runner.read_text(), "Refusing a non-private local structured-draft rollback target", "rollback local-only runner refusal")
    authorization_setup = Path(__file__).resolve().parent / "sales_opportunity_structured_draft_metadata_local_authorization_after_lock_setup.sql"
    authorization_worker = Path(__file__).resolve().parent / "sales_opportunity_structured_draft_metadata_local_authorization_after_lock_worker.sql"
    authorization_assertions = Path(__file__).resolve().parent / "sales_opportunity_structured_draft_metadata_local_authorization_after_lock_assertions.sql"
    authorization_runner = Path(__file__).resolve().parent / "run_sales_opportunity_structured_draft_metadata_local_authorization_after_lock.sh"
    require(authorization_setup.read_text(), "LOCAL DISPOSABLE AUTHORIZATION-AFTER-LOCK FIXTURE ONLY", "authorization-after-lock fixture boundary")
    require(authorization_worker.read_text(), "Its save call must wait inside the contract", "authorization-after-lock worker boundary")
    require(authorization_assertions.read_text(), "Authorization-after-lock denial changed persisted draft contents", "authorization-after-lock exact-state assertion")
    require(authorization_assertions.read_text(), "Sales management permission is required", "authorization-after-lock denial assertion")
    require(authorization_runner.read_text(), "CONTRACT_CONTENTION_OBSERVED case=%s worker_lock=%s", "authorization-after-lock lock evidence")
    require(authorization_runner.read_text(), "FIXTURE_PERMISSION_REVOCATION_COMMITTED case=%s", "authorization-after-lock committed revocation")
    require(authorization_runner.read_text(), "Fixture-only transport; the pending proposal remains fully revoked by default.", "authorization-after-lock fixture transport boundary")
    print("structured draft metadata static checks: PASS")


if __name__ == "__main__":
    main()
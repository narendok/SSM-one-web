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
    require(SQL, f"REVOKE ALL ON FUNCTION {protected_signature} FROM PUBLIC, anon, service_role;", "default-revoked save transport")
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
    require(audit_sql, f"REVOKE ALL ON FUNCTION {audited_signature} FROM PUBLIC, anon, service_role;", "default-revoked audited save transport")
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
    materialization = (PENDING_ROOT / "20261011_sales_opportunity_structured_draft_materialization.sql").read_text()
    activation = (PENDING_ROOT / "20261011_sales_opportunity_structured_draft_materialization_activation.sql").read_text()
    materialization_acceptance = Path(__file__).resolve().parent / "sales_opportunity_structured_draft_materialization_local_acceptance.sql"
    materialization_runner = Path(__file__).resolve().parent / "run_sales_opportunity_structured_draft_materialization_local_acceptance.sh"
    require(materialization, "sales_opportunity_document_locations", "opportunity-specific Sales location binding")
    require(materialization, "sales_opportunity_structured_draft_storage_attempts", "staged object receipt")
    require(materialization, "sales_opportunity_structured_draft_materializations", "immutable materialization receipt")
    require(materialization, "sales_opportunity_structured_draft_materialization_audits", "transaction-coupled materialization audit")
    require(materialization, "Staged Sales draft object does not exist", "storage object existence verification")
    require(materialization, "Staged Sales draft object lacks a verified owned attempt receipt", "owned staged-object requirement")
    require(materialization, "Request key conflicts with a different Sales draft materialization payload", "payload mismatch denial")
    require(materialization, "Sales document location target is outside its locked root", "locked location ancestry")
    require(materialization, "REVOKE ALL ON FUNCTION public.commit_sales_opportunity_structured_draft_materialization", "default-revoked materializer")
    forbid(materialization, "GRANT EXECUTE ON FUNCTION public.commit_sales_opportunity_structured_draft_materialization", "pre-granted materializer")
    forbid(materialization, 'CREATE POLICY "Sales structured drafts insert', "storage policy in source-only schema contract")
    require(activation, "ACTION-TIME APPROVAL REQUIRED", "separate activation boundary")
    require(activation, "Sales structured drafts insert their recorded private prefix", "narrow policy approval package")
    require(activation, "GRANT EXECUTE ON FUNCTION public.commit_sales_opportunity_structured_draft_materialization", "activation-only execute grant")
    require(materialization_acceptance.read_text(), "STRUCTURED_DRAFT_MATERIALIZATION_LOCAL_ACCEPTANCE_PASS", "materialization acceptance marker")
    require(materialization_acceptance.read_text(), "cross-opportunity location accepted", "cross-scope denial assertion")
    require(materialization_acceptance.read_text(), "changed replay accepted", "replay mismatch assertion")
    require(materialization_acceptance.read_text(), "immutable history changed", "immutable audit assertion")
    require(materialization_runner.read_text(), "MATERIALIZATION_EXECUTION_COMPLETE=true", "materialization disposable runner")
    staged_phase_a = Path(__file__).resolve().parents[3] / "docs/evidence/sql-editor/20261011_sales_structured_draft_phase_a_install.sql"
    staged_phase_b = Path(__file__).resolve().parents[3] / "docs/evidence/sql-editor/20261011_sales_structured_draft_phase_b_binding_review.sql"
    staged_phase_c = Path(__file__).resolve().parents[3] / "docs/evidence/sql-editor/20261011_sales_structured_draft_phase_c_managed_acceptance_rollback.sql"
    staged_phase_d = Path(__file__).resolve().parents[3] / "docs/evidence/sql-editor/20261011_sales_structured_draft_phase_d_activation.sql"
    staged_flow = Path(__file__).resolve().parent / "sales_opportunity_structured_draft_staged_flow_local_acceptance.sql"
    staged_runner = Path(__file__).resolve().parent / "run_sales_opportunity_structured_draft_staged_flow_local_acceptance.sh"
    require(staged_phase_a.read_text(), "BEGIN;", "phase A transaction begin")
    require(staged_phase_a.read_text(), "COMMIT;", "phase A transaction commit")
    forbid(staged_phase_a.read_text(), "GRANT EXECUTE ON FUNCTION", "phase A authenticated execute grant")
    forbid(staged_phase_a.read_text(), "CREATE POLICY \"Sales structured drafts insert", "phase A Storage policy activation")
    require(staged_phase_b.read_text(), "BEGIN READ ONLY;", "phase B read-only transaction")
    require(staged_phase_b.read_text(), "a6c62c81-1cc2-4804-b1c5-c004c6730b52", "phase B approved opportunity")
    require(staged_phase_b.read_text(), "020dcca5-7809-4287-88cd-537d837a3eee", "phase B approved Sales folder")
    require(staged_phase_b.read_text(), "WITH RECURSIVE pinned", "phase B recursive ancestry CTE")
    require(staged_phase_b.read_text(), "0c3e85df-f901-4bb9-9ea7-ee2072658faa", "phase B exact Sales root")
    require(staged_phase_b.read_text(), "exact_sales_root_reached", "phase B root-reach assertion")
    require(staged_phase_b.read_text(), "ancestry_has_no_cycle", "phase B cycle assertion")
    require(staged_phase_b.read_text(), "ancestry_not_depth_truncated", "phase B depth assertion")
    require(staged_phase_c.read_text(), "PHASE_C_NOT_GENUINE_CALLER_CONTEXT", "phase C genuine caller guard")
    require(staged_phase_c.read_text(), "operator claim simulations only", "phase C simulation boundary")
    require(staged_phase_c.read_text(), "phase_c_first_save", "phase C executable save")
    require(staged_phase_c.read_text(), "phase_c_exact_replay", "phase C executable replay")
    require(staged_phase_c.read_text(), "PHASE_C_ROLLBACK_ONLY_FUNCTION_ACCEPTANCE_PASSED", "phase C success evidence")
    require(staged_phase_c.read_text(), "ROLLBACK;", "phase C forced rollback")
    require(staged_phase_d.read_text(), "BEGIN;", "phase D transaction begin")
    require(staged_phase_d.read_text(), "COMMIT;", "phase D transaction commit")
    require(staged_phase_d.read_text(), "GRANT EXECUTE ON FUNCTION public.commit_sales_opportunity_structured_draft_materialization", "phase D activation grant")
    require(staged_flow.read_text(), "phase A leaked authenticated execute", "staged flow no-early-grant assertion")
    require(staged_flow.read_text(), "phase C rollback leaked access or history", "staged flow rollback assertion")
    require(staged_flow.read_text(), "STRUCTURED_DRAFT_STAGED_FLOW_LOCAL_ACCEPTANCE_PASS", "staged-flow success marker")
    require(staged_runner.read_text(), "STAGED_FLOW_EXECUTION_COMPLETE=true", "staged-flow disposable runner")
    print("structured draft metadata static checks: PASS")


if __name__ == "__main__":
    main()
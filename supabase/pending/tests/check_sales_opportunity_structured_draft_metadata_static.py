#!/usr/bin/env python3
"""Source-only structural guard for the pending Structured Sales draft contract."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SQL = (ROOT / "20261009_sales_opportunity_structured_draft_metadata.sql").read_text()
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
    require(ACCEPTANCE, "Expected immutable revision update to fail", "append-only acceptance")
    forbid(ACCEPTANCE, "Metadata proposal must not create an activity audit", "unsupported no-audit assertion")
    print("structured draft metadata static checks: PASS")


if __name__ == "__main__":
    main()
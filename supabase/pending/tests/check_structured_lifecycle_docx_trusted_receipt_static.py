#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
receipt = (root / "20261012_structured_lifecycle_docx_trusted_receipt_authority.sql").read_text()
materialization = (root / "20261012_sales_structured_docx_materialization_contract.sql").read_text()
acceptance = (Path(__file__).parent / "sales_structured_docx_materialization_local_acceptance.sql").read_text()
server = Path("src/lib/structured-lifecycle-docx-sales-orchestration.server.ts").read_text()
functions = Path("src/lib/structured-lifecycle-docx-private-object-bridge.functions.ts").read_text()

def need(text: str, needle: str, label: str):
    if needle not in text:
        raise SystemExit(f"MISSING {label}")

def forbid(text: str, needle: str, label: str):
    if needle in text:
        raise SystemExit(f"FORBIDDEN {label}")

for item in (
    "CREATE TABLE public.sales_opportunity_structured_docx_trusted_receipts",
    "assert_sales_structured_docx_trusted_actor_scope",
    "issue_sales_structured_docx_trusted_receipt",
    "resolve_sales_structured_docx_server_scope",
    "assert_sales_structured_docx_trusted_receipt_for_commit",
    "consumed_at",
    "pg_advisory_xact_lock",
    "storage.objects",
    "structured_lifecycle_docx_responsibility_assignments",
    "Trusted DOCX receipt registry responsibility changed",
    "Trusted DOCX receipt template pin changed",
    "Only the trusted server DOCX verifier may issue a receipt",
    "REVOKE ALL ON FUNCTION public.issue_sales_structured_docx_trusted_receipt",
    "GRANT EXECUTE ON FUNCTION public.issue_sales_structured_docx_trusted_receipt",
): need(receipt, item, item)
forbid(receipt, "TO authenticated;", "authenticated receipt issuer grant")
forbid(receipt, "set_config('structured_docx.trusted_actor'", "caller-controlled trusted actor setting")
for item in ("p_trusted_receipt_id uuid", "object_version text NOT NULL", "SET consumed_at=now()"):
    need(materialization, item, item)
need(receipt, "Trusted DOCX receipt is absent, consumed, or conflicts with commit facts", "protected receipt rejection")
need(receipt, "Trusted DOCX commit actor does not match the authenticated caller", "caller-authenticated commit actor binding")
need(materialization, "assert_sales_structured_docx_trusted_receipt_for_commit", "commit-side protected receipt recheck")
need(materialization, "An authenticated assigned responsible person is required", "authenticated atomic commit")
if materialization.index("IF v_actor IS NULL THEN RAISE EXCEPTION 'An authenticated assigned responsible person is required'; END IF;") > materialization.index("SELECT * INTO v_request FROM public.sales_opportunity_structured_docx_requests AS docx_request"):
    raise SystemExit("MISSING reachable commit null-actor rejection")
if receipt.index("PERFORM public.assert_sales_structured_docx_trusted_actor_scope") > receipt.index("FOR UPDATE;", receipt.index("CREATE OR REPLACE FUNCTION public.assert_sales_structured_docx_trusted_receipt_for_commit")):
    raise SystemExit("MISSING receipt-last commit lock order")
for item in ("createContractBoundCurrentPathPrivateDocxReader", "issue_sales_structured_docx_trusted_receipt", "commit_sales_structured_docx_materialization", "assert_sales_structured_docx_current_path_create_only"):
    need(server, item, item)
need(functions, "lifecycleAcceptanceEnabled", "deployment gate")
need(acceptance, "issue_sales_structured_docx_trusted_receipt", "receipt acceptance")
need(acceptance, "LOCAL_DOCX_FAIL null actor commit accepted", "reachable null-actor acceptance")
need(acceptance, "SALES_STRUCTURED_DOCX_LOCAL_ACCEPTANCE_PASS", "acceptance pass marker")
print("STRUCTURED_LIFECYCLE_DOCX_TRUSTED_RECEIPT_STATIC_PASS=true")

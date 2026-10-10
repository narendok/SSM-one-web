#!/usr/bin/env python3
"""Static guard for the unapplied atomic Sales intake/replay proposal."""
from pathlib import Path

pending = Path(__file__).resolve().parents[1]
sql = (pending / "20261010_sales_atomic_intake_replay.sql").read_text()
harness = (Path(__file__).resolve().parent / "sales_atomic_intake_replay_acceptance.sql").read_text()
local_runner = (Path(__file__).resolve().parent / "run_sales_atomic_intake_local_acceptance.sh").read_text()
local_fixture = (Path(__file__).resolve().parent / "sales_atomic_intake_replay_local_fixture.sql").read_text()
local_acceptance = (Path(__file__).resolve().parent / "sales_atomic_intake_replay_local_installed_acceptance.sql").read_text()

checks = {
    "source-only header": "SOURCE-ONLY, UNDEPLOYED PROPOSAL. DO NOT APPLY." in sql,
    "one private receipt table": "CREATE TABLE public.sales_opportunity_intake_receipts" in sql,
    "all default receipt privileges explicitly revoked": "REVOKE ALL ON TABLE public.sales_opportunity_intake_receipts FROM PUBLIC, anon, authenticated, service_role;" in sql,
    "service role has no receipt mutations": "GRANT ALL ON TABLE public.sales_opportunity_intake_receipts TO service_role;" not in sql and "GRANT SELECT ON TABLE public.sales_opportunity_intake_receipts TO service_role;" in sql,
    "receipt lookup is actor scoped": "WHERE request_key = p_request_key AND requested_by = v_actor_id;" in sql,
    "source authorization precedes receipt lookup": sql.index("public.has_permission(v_actor_id, 'sales.manage')") < sql.index("FROM public.sales_opportunity_intake_receipts WHERE request_key = p_request_key FOR UPDATE"),
    "authorization rechecked after receipt wait": sql.count("IF NOT public.has_permission(v_actor_id, 'sales.manage')") >= 3,
    "source rows are locked": all(fragment in sql for fragment in ("FROM public.customers WHERE id = p_customer_id FOR UPDATE", "FROM public.customer_contacts", "FROM public.sales_enquiries", "FOR UPDATE;")),
    "source pairing is explicit": "Contact/customer source mismatch" in sql and "Enquiry/customer/contact source mismatch" in sql,
    "opportunity number remains server generated": "opportunity_number" in sql and "NULL, p_customer_id" in sql and "next_business_number('opportunity'" in sql,
    "master number uses established allocator": "public.next_business_number('master_specification', 'MS', NULL)" in sql,
    "canonical payload conditional length expression is valid": "(v_key = 'nextAction' AND char_length(p_intake->>v_key) > 1000)" in sql and "(v_key <> 'nextAction' AND char_length(p_intake->>v_key) > 240)" in sql,
    "one transaction writes opportunity spec version audit receipt": all(fragment in sql for fragment in ("INSERT INTO public.sales_opportunities", "INSERT INTO public.master_specifications", "INSERT INTO public.master_specification_versions", "INSERT INTO public.activity_log", "INSERT INTO public.sales_opportunity_intake_receipts")),
    "exact actor source payload replay is required": "v_prior.requested_by = v_actor_id" in sql and "v_prior.canonical_payload = v_canonical" in sql and "v_prior.payload_hash = v_payload_hash" in sql,
    "receipt functions remain ungranted": "GRANT EXECUTE ON FUNCTION public.create_sales_opportunity_with_initial_master_specification" not in sql and "GRANT EXECUTE ON FUNCTION public.lookup_sales_opportunity_intake_receipt" not in sql,
    "acceptance uses a real authenticated role": "SET LOCAL ROLE authenticated;" in harness,
    "acceptance catches only permission denial": "EXCEPTION WHEN OTHERS" not in harness and "EXCEPTION WHEN insufficient_privilege" in harness and "SQLSTATE <> '42501'" in harness,
    "acceptance rolls back": harness.rstrip().endswith("ROLLBACK;"),
    "concurrency and rollback remain explicit acceptance gates": "Two distinct authenticated sessions race" in harness and "complete transaction rolls back" in harness,
    "local runner rejects remote targets": "LOCALHOST_ONLY_HOSTS" in local_runner and "Refusing a non-local" in local_runner,
    "local runner limits sockets to the fresh task root": "LOCAL_SALES_INTAKE_PRIVATE_SOCKET_ROOT" in local_runner and "startsWith('/tmp/sales_atomic_acceptance_')" in local_runner and "Connection options are not accepted" in local_runner and "--host=\"$socket_host\"" in local_runner,
    "local runner requires disposable confirmation": "LOCAL_SALES_INTAKE_DISPOSABLE" in local_runner and "yes" in local_runner,
    "local installed transport is explicit and separate": "GRANT EXECUTE ON FUNCTION public.create_sales_opportunity_with_initial_master_specification" in local_runner and "local disposable fixture only" in local_runner,
    "local fixture proves allocator locking": "FOR UPDATE" in local_fixture and "document_numbering_config" in local_fixture,
    "local acceptance covers replay conflicts invalid source rollback and races": all(fragment in local_acceptance for fragment in ("Exact replay", "changed payload", "different actor", "invalid source", "rollback", "Two-session race")),
    "local acceptance restores its disposable fixture": local_acceptance.rstrip().endswith("ROLLBACK;"),
}
failed = [name for name, passed in checks.items() if not passed]
for name, passed in checks.items():
    print(f"{'PASS' if passed else 'FAIL'}: {name}")
if failed:
    raise SystemExit(1)

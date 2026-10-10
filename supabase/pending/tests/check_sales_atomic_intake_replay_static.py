#!/usr/bin/env python3
"""Static guard for the unapplied atomic Sales intake/replay proposal."""
from pathlib import Path

pending = Path(__file__).resolve().parents[1]
sql = (pending / "20261010_sales_atomic_intake_replay.sql").read_text()
harness = (Path(__file__).resolve().parent / "sales_atomic_intake_replay_acceptance.sql").read_text()
local_runner = (Path(__file__).resolve().parent / "run_sales_atomic_intake_local_acceptance.sh").read_text()
local_fixture = (Path(__file__).resolve().parent / "sales_atomic_intake_replay_local_fixture.sql").read_text()
local_acceptance = (Path(__file__).resolve().parent / "sales_atomic_intake_replay_local_installed_acceptance.sql").read_text()
race_runner = (Path(__file__).resolve().parent / "run_sales_atomic_intake_local_race_acceptance.sh").read_text()
race_setup = (Path(__file__).resolve().parent / "sales_atomic_intake_replay_local_race_setup.sql").read_text()
race_worker = (Path(__file__).resolve().parent / "sales_atomic_intake_replay_local_race_worker.sql").read_text()
race_assertions = (Path(__file__).resolve().parent / "sales_atomic_intake_replay_local_race_assertions.sql").read_text()

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
    "canonical payload required keys are order independent": "FROM unnest(v_allowed) AS allowed(key)" in sql and "FROM unnest(v_spec_allowed) AS allowed(key)" in sql,
    "canonical payload rejects unknown nested keys without array null ambiguity": "EXISTS (SELECT 1 FROM jsonb_object_keys(v_spec) AS key WHERE key <> ALL(v_spec_allowed))" in sql,
    "nested key inspection follows object shape validation": sql.index("IF jsonb_typeof(v_spec) <> 'object' THEN") < sql.index("EXISTS (SELECT 1 FROM jsonb_object_keys(v_spec) AS key WHERE key <> ALL(v_spec_allowed))"),
    "canonical payload requires every emitted specification scalar": "'connectivityAndGnss', 'environmentAndIp'" in sql and "'requirementSummary', 'schedule', 'volumes', 'connectivityAndGnss'" in sql,
    "jsonb key removals are unambiguous": "v_spec_data := v_canonical->'masterSpecification';" in sql and "v_spec_data - 'changeSummary'::text" in sql,
    "canonical payload accepts explicit JSON null optionals": "IS DISTINCT FROM 'null' AND jsonb_typeof(p_intake->'application') IS DISTINCT FROM 'string'" in sql,
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
    "local race runner rejects remote targets": "Refusing a non-local PostgreSQL target." in race_runner and "LOCAL_SALES_INTAKE_DISPOSABLE" in race_runner,
    "local race runner bounds worker waits": "timeout 20s psql" in race_runner and "interval '15 seconds'" in race_worker,
    "local race workers use independent psql sessions": race_runner.count("timeout 20s psql") >= 2,
    "local race readiness is durable": "sales_intake_race_barriers" in race_setup and "ready_workers" in race_worker,
    "local race barrier rows carry their required worker count": "(race_label, expected_workers)" in race_setup and "('same_key_same_payload', 2)" in race_setup,
    "local race retains worker identity after readiness commit": "set_config('request.jwt.claim.sub', :'actor_id', false)" in race_worker,
    "local race waits for both committed readiness rows": "SELECT ready_workers FROM public.sales_intake_race_barriers" in race_runner,
    "local exact replay waits for both durable responses": "Exact replay workers did not record both responses" in race_assertions,
    "local race releases before it evaluates completed workers": "-v release_only=yes" in race_runner and "wait \"$race_pid\"" in race_runner,
    "local race avoids sleep-only coordination": "pg_advisory_xact_lock" in race_worker and "released" in race_assertions,
    "local race covers same key conflicts and distinct keys": all(label in race_runner for label in ("same_key_same_payload", "same_key_changed_payload", "same_key_actor_conflict", "different_keys")),
    "local race asserts allocation and atomic row counts": "count(DISTINCT opportunity_number)" in race_assertions and "mismatched opportunity/spec/version/audit rows" in race_assertions,
    "local race records both worker responses": "CREATE TABLE public.sales_intake_race_results" in race_setup and "INSERT INTO public.sales_intake_race_results" in race_worker,
    "local race proves exact replay IDs": "Exact replay workers did not return identical opportunity/specification/version IDs" in race_assertions and "count(DISTINCT master_specification_version_id)" in race_assertions,
}
failed = [name for name, passed in checks.items() if not passed]
for name, passed in checks.items():
    print(f"{'PASS' if passed else 'FAIL'}: {name}")
if failed:
    raise SystemExit(1)

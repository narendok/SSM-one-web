#!/usr/bin/env bash
set -euo pipefail
# LOCAL DISPOSABLE POSTGRESQL ONLY. Uses two psql sessions and advisory-lock
# barriers; it never contacts a managed backend or modifies the guarded runner.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
work_dir="$(mktemp -d /tmp/client_requirement_intake_concurrency_XXXXXX)"
data_dir="$work_dir/data"; socket_dir="$work_dir/socket"; log_dir="$work_dir/logs"; database="client_requirement_intake_concurrency_local"; port=55439; server_pid=""
mkdir -p "$socket_dir" "$log_dir"
cleanup() { local status=$?; if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi; rm -rf "$work_dir"; printf 'CLEANUP_VERIFIED private_concurrency_fixture_removed_on_exit=true\n'; exit "$status"; }
trap cleanup EXIT
[[ "$(id -u)" == "0" ]] || { echo "This disposable fixture requires the sandbox root user." >&2; exit 64; }
chown -R 1000:1000 "$work_dir"
setpriv --reuid=1000 --regid=1000 --clear-groups initdb -D "$data_dir" --no-locale --encoding=UTF8 --auth-local=trust -U lovable >/dev/null
cat >>"$data_dir/postgresql.conf" <<PGCONF
listen_addresses = ''
port = $port
unix_socket_directories = '$socket_dir'
shared_memory_type = mmap
dynamic_shared_memory_type = mmap
logging_collector = off
PGCONF
setpriv --reuid=1000 --regid=1000 --clear-groups postgres -D "$data_dir" >"$log_dir/postgres.log" 2>&1 & server_pid=$!
for _ in $(seq 1 150); do psql --host="$socket_dir" --port="$port" --username=lovable --dbname=postgres -Atqc 'SELECT 1' >/dev/null 2>&1 && break; sleep 0.1; done
psql --host="$socket_dir" --port="$port" --username=lovable --dbname=postgres -Atqc 'SELECT 1' >/dev/null
createdb --host="$socket_dir" --port="$port" --username=lovable "$database"
psql_args=(--set=ON_ERROR_STOP=1 --host="$socket_dir" --port="$port" --username=lovable --dbname="$database")
run_psql() { psql "${psql_args[@]}" "$@"; }
run_psql -f "$root/supabase/pending/tests/client_requirement_intake_local_fixture.sql"
run_psql -f "$root/supabase/pending/20261005_client_requirement_intake.sql"
run_psql -c "GRANT EXECUTE ON FUNCTION public.submit_external_customer_requirement(uuid, uuid, text, text, jsonb, uuid) TO authenticated;"
run_case() {
  local case_name="$1" title_a="$2" payload_a="$3" title_b="$4" payload_b="$5" expected_b_status="$6"
  local worker="$root/supabase/pending/tests/client_requirement_intake_local_concurrency.sql"
  psql "${psql_args[@]}" --set="submission_title=$title_a" --set="submission_payload=$payload_a" -f "$worker" >"$log_dir/${case_name}_a.out" 2>"$log_dir/${case_name}_a.err" & local pid_a=$!
  until run_psql -Atqc "SELECT count(*) FROM pg_locks WHERE locktype = 'advisory' AND objid = 918273645 AND granted" | grep -qx 1; do sleep 0.01; done
  psql "${psql_args[@]}" --set="submission_title=$title_b" --set="submission_payload=$payload_b" -f "$worker" >"$log_dir/${case_name}_b.out" 2>"$log_dir/${case_name}_b.err" & local pid_b=$!
  run_psql -c "SELECT pg_advisory_unlock(918273645);" >/dev/null
  wait "$pid_a"; local status_a=$?
  wait "$pid_b"; local status_b=$?
  printf 'CONCURRENCY_CASE case=%s worker_a_exit=%s worker_b_exit=%s\n' "$case_name" "$status_a" "$status_b"
  [[ "$status_a" == "0" && "$status_b" == "$expected_b_status" ]] || { cat "$log_dir/${case_name}_a.err" "$log_dir/${case_name}_b.err" >&2; return 1; }
}
run_case same_actor_same_canonical 'Concurrent request' '{"description":"Concurrent canonical payload"}' ' Concurrent request ' '{"description":"Concurrent canonical payload"}' 0
same_ids="$(sed -n '/^[0-9a-f-]\{36\}$/p' "$log_dir/same_actor_same_canonical_a.out"; sed -n '/^[0-9a-f-]\{36\}$/p' "$log_dir/same_actor_same_canonical_b.out")"
[[ "$(printf '%s\n' "$same_ids" | sort -u | wc -l)" == "1" ]] || { echo 'LOCAL_CASE_FAIL same canonical submissions returned different requirement IDs' >&2; exit 1; }
[[ "$(run_psql -Atqc "SELECT count(*) FROM public.customer_requirements WHERE customer_reference = 'REQ-CONCURRENT'")" == "1" ]] || { echo 'LOCAL_CASE_FAIL same canonical submissions created multiple headers' >&2; exit 1; }
same_revision_count="$(run_psql -Atqc "SELECT count(*) FROM public.customer_requirement_revisions")"
same_audit_count="$(run_psql -Atqc "SELECT count(*) FROM public.activity_log WHERE action = 'external_submitted'")"
same_receipt_count="$(run_psql -Atqc "SELECT count(*) FROM public.external_requirement_submission_requests WHERE request_key = '00000000-0000-4000-8000-000000000095'")"
[[ "$same_revision_count/$same_audit_count/$same_receipt_count" == "1/1/1" ]] || { printf 'LOCAL_CASE_FAIL same canonical write counts revision/audit/receipt=%s/%s/%s\n' "$same_revision_count" "$same_audit_count" "$same_receipt_count" >&2; exit 1; }
run_psql -c "TRUNCATE public.external_requirement_submission_requests, public.activity_log, public.customer_requirement_revisions, public.customer_requirements CASCADE;" >/dev/null
run_case same_key_conflicting_payloads 'Conflict A' '{"description":"Concurrent conflict A"}' 'Conflict B' '{"description":"Concurrent conflict B"}' 3
[[ "$(run_psql -Atqc "SELECT count(*) FROM public.customer_requirements")" == "1" && "$(run_psql -Atqc "SELECT count(*) FROM public.customer_requirement_revisions")" == "1" && "$(run_psql -Atqc "SELECT count(*) FROM public.activity_log WHERE action = 'external_submitted'")" == "1" && "$(run_psql -Atqc "SELECT count(*) FROM public.external_requirement_submission_requests WHERE request_key = '00000000-0000-4000-8000-000000000095'")" == "1" ]] || { echo 'LOCAL_CASE_FAIL conflicting request-key submissions committed more than one graph' >&2; exit 1; }
grep -Fqx 'ERROR:  Request key conflicts with a different caller or payload' "$log_dir/same_key_conflicting_payloads_b.err" || { cat "$log_dir/same_key_conflicting_payloads_b.err" >&2; exit 1; }
printf 'CLIENT_REQUIREMENT_LOCAL_CONCURRENCY_PASS same_result=true same_graph=1/1/1/1 conflict_one_winner=true\n'
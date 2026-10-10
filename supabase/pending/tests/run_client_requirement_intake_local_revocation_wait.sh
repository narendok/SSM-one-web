#!/usr/bin/env bash
set -euo pipefail
# LOCAL DISPOSABLE POSTGRESQL ONLY. It proves post-lock scope revalidation with
# synthetic GUC actors; it never contacts a managed backend or alters its runner.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
work_dir="$(mktemp -d /tmp/client_requirement_intake_revocation_wait_XXXXXX)"
data_dir="$work_dir/data"; socket_dir="$work_dir/socket"; log_dir="$work_dir/logs"; database="client_requirement_intake_revocation_wait_local"; port=55440; server_pid=""
mkdir -p "$socket_dir" "$log_dir"
cleanup() { local status=$?; if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi; rm -rf "$work_dir"; printf 'CLEANUP_VERIFIED private_revocation_wait_fixture_removed_on_exit=true\n'; exit "$status"; }
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
psql "${psql_args[@]}" <<'SQL' >"$log_dir/locker.out" 2>"$log_dir/locker.err" & locker_pid=$!
BEGIN;
SELECT pg_advisory_xact_lock(hashtextextended('00000000-0000-4000-8000-000000000096', 0));
SELECT pg_sleep(0.25);
COMMIT;
SQL
sleep 0.03
psql "${psql_args[@]}" -f "$root/supabase/pending/tests/client_requirement_intake_local_revocation_wait.sql" >"$log_dir/waiter.out" 2>"$log_dir/waiter.err" & waiter_pid=$!
sleep 0.05
run_psql -c "UPDATE public.external_portal_access SET deactivated_at = now() WHERE external_contact_id = '00000000-0000-4000-8000-000000000040';" >/dev/null
wait "$locker_pid"
waiter_status=0; wait "$waiter_pid" || waiter_status=$?
[[ "$waiter_status" == "3" ]] || { cat "$log_dir/waiter.err" >&2; exit 1; }
grep -Fq 'ERROR:  Client requirement access is inactive, expired, revoked, or outside its granted scope' "$log_dir/waiter.err" || { cat "$log_dir/waiter.err" >&2; exit 1; }
[[ "$(run_psql -Atqc "SELECT count(*) FROM public.customer_requirements WHERE customer_reference = 'REQ-REVOKED-WAIT'")" == "0" ]] || { echo 'LOCAL_CASE_FAIL post-revocation wait created a requirement header' >&2; exit 1; }
[[ "$(run_psql -Atqc "SELECT count(*) FROM public.customer_requirement_revisions WHERE requirement_id IN (SELECT id FROM public.customer_requirements WHERE customer_reference = 'REQ-REVOKED-WAIT')")" == "0" ]] || { echo 'LOCAL_CASE_FAIL post-revocation wait created a requirement revision' >&2; exit 1; }
[[ "$(run_psql -Atqc "SELECT count(*) FROM public.activity_log WHERE action = 'external_submitted' AND after_data->>'request_key' = '00000000-0000-4000-8000-000000000096'")" == "0" ]] || { echo 'LOCAL_CASE_FAIL post-revocation wait created an audit record' >&2; exit 1; }
[[ "$(run_psql -Atqc "SELECT count(*) FROM public.external_requirement_submission_requests WHERE request_key = '00000000-0000-4000-8000-000000000096'")" == "0" ]] || { echo 'LOCAL_CASE_FAIL post-revocation wait created a request receipt' >&2; exit 1; }
printf 'CLIENT_REQUIREMENT_LOCAL_REVOCATION_WAIT_PASS initial_scope=authorized revocation=committed_before_unlock waiter_sqlstate=P0001 request_graph=0/0/0/0\n'
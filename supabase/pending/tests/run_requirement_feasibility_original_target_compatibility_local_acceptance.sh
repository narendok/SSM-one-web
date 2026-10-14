#!/usr/bin/env bash
set -euo pipefail
# LOCAL DISPOSABLE POSTGRESQL ONLY. It never contacts a managed backend.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
work_dir="$(mktemp -d /tmp/requirement_feasibility_compatibility_XXXXXX)"; data_dir="$work_dir/data"; socket_dir="$work_dir/socket"; log_dir="$work_dir/logs"; database="requirement_feasibility_compatibility_local"; port=55440; server_pid=""
mkdir -p "$socket_dir" "$log_dir"
cleanup() { local status=$?; if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi; rm -rf "$work_dir"; printf 'CLEANUP_VERIFIED private_fixture_removed_on_exit=true\n'; exit "$status"; }
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
args=(--set=ON_ERROR_STOP=1 --host="$socket_dir" --port="$port" --username=lovable --dbname="$database")
psql "${args[@]}" -f "$root/supabase/pending/tests/client_requirement_intake_local_fixture.sql"
psql "${args[@]}" -f "$root/supabase/pending/20261005_client_requirement_intake.sql"
psql "${args[@]}" -f "$root/supabase/pending/20261013_sales_feasibility_handover.sql"
psql "${args[@]}" -f "$root/supabase/pending/tests/requirement_feasibility_original_target_compatibility_local_acceptance.sql"
psql "${args[@]}" -f "$root/supabase/pending/tests/sales_feasibility_handover_competing_source_a.sql" >"$log_dir/competing-a.log" 2>&1 & first_pid=$!
psql "${args[@]}" -c 'SELECT pg_advisory_lock(20261015, 31); SELECT pg_advisory_unlock(20261015, 31);' >/dev/null
psql "${args[@]}" -f "$root/supabase/pending/tests/sales_feasibility_handover_competing_source_b.sql" >"$log_dir/competing-b.log" 2>&1 & second_pid=$!
wait "$first_pid"; wait "$second_pid"
cat "$log_dir/competing-a.log" "$log_dir/competing-b.log"
psql "${args[@]}" -Atqc "SELECT CASE WHEN (SELECT count(*) FROM public.sales_feasibility_handover_requests WHERE request_key IN ('00000000-0000-4000-8000-000000000212','00000000-0000-4000-8000-000000000213')) = 1 AND (SELECT count(*) FROM public.customer_requirements WHERE title LIKE 'Competing source handover%') = 1 THEN 'SALES_FEASIBILITY_HANDOVER_COMPETING_SOURCE_PASS receipts=1 requirements=1 second=denied' ELSE 'SALES_FEASIBILITY_HANDOVER_COMPETING_SOURCE_FAIL' END" | grep -Fx 'SALES_FEASIBILITY_HANDOVER_COMPETING_SOURCE_PASS receipts=1 requirements=1 second=denied'
printf 'ORIGINAL_TARGET_COMPATIBILITY_LOCAL_ACCEPTANCE_COMPLETE=true\n'
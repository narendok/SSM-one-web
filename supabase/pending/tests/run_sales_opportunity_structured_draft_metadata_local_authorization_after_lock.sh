#!/usr/bin/env bash
set -euo pipefail
# LOCAL DISPOSABLE POSTGRESQL 17 ONLY. Refuses remote, managed, and shared targets.
# Explicit private socket/port/user/database arguments prevent inherited PG* redirection.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
work_dir="$(mktemp -d /tmp/structured_draft_authorization_after_lock_XXXXXX)"
data_dir="$work_dir/data"; socket_dir="$work_dir/socket"; log_dir="$work_dir/logs"; database="structured_draft_acceptance_authorization_after_lock"; port=55437; server_pid=""
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
psql_args=(--set=ON_ERROR_STOP=1 --host="$socket_dir" --port="$port" --username=lovable --dbname="$database")
run_psql() { psql "${psql_args[@]}" "$@"; }
run_psql -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_fixture.sql"
run_psql -f "$root/supabase/pending/20261009_sales_opportunity_structured_draft_metadata.sql"
# Fixture-only transport; the pending proposal remains fully revoked by default.
run_psql -c "GRANT EXECUTE ON FUNCTION public.save_sales_opportunity_structured_draft_revision(uuid, uuid, uuid, uuid, text, integer, jsonb, uuid) TO authenticated;"
run_psql -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_authorization_after_lock_setup.sql"
for case_name in new_write receipt_replay; do
  run_psql -c 'UPDATE public.sales_structured_draft_test_permissions SET sales_manage = true WHERE user_id = '\''00000000-0000-4000-8000-000000000001'\'';'
  run_psql -c 'UPDATE public.structured_draft_authorization_after_lock_control SET holder_ready = false, released = false WHERE singleton;'
  PGAPPNAME="structured-draft-authorization-after-lock-holder:$case_name" timeout 20s psql "${psql_args[@]}" -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_authorization_after_lock_holder.sql" >"$log_dir/$case_name-holder.log" 2>&1 & holder_pid=$!
  for _ in $(seq 1 150); do [[ "$(run_psql -Atqc 'SELECT holder_ready::text FROM public.structured_draft_authorization_after_lock_control WHERE singleton')" == true ]] && break; sleep 0.1; done
  [[ "$(run_psql -Atqc 'SELECT holder_ready::text FROM public.structured_draft_authorization_after_lock_control WHERE singleton')" == true ]] || { cat "$log_dir/$case_name-holder.log" >&2; exit 1; }
  PGAPPNAME="structured-draft-authorization-after-lock-worker:$case_name" timeout 20s psql "${psql_args[@]}" -v authorization_case="$case_name" -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_authorization_after_lock_worker.sql" >"$log_dir/$case_name-worker.log" 2>&1 & worker_pid=$!
  lock_evidence=""
  for _ in $(seq 1 150); do
    lock_evidence="$(run_psql -Atqc "SELECT count(*)::text || ':' || coalesce(string_agg(activity.pid::text || ':' || activity.wait_event_type || ':' || activity.wait_event || ':granted=' || lock.granted::text, ',' ORDER BY activity.pid), '') FROM pg_stat_activity AS activity JOIN pg_locks AS lock ON lock.pid = activity.pid WHERE activity.application_name = 'structured-draft-authorization-after-lock-worker:$case_name' AND activity.wait_event_type = 'Lock' AND activity.wait_event = 'advisory' AND lock.locktype = 'advisory' AND NOT lock.granted")"
    [[ "$lock_evidence" == 1:* ]] && break; sleep 0.1
  done
  [[ "$lock_evidence" == 1:* ]] || { echo "Expected in-contract advisory-lock wait for $case_name, saw: $lock_evidence" >&2; run_psql -c "SELECT pid, application_name, state, wait_event_type, wait_event, query FROM pg_stat_activity WHERE application_name = 'structured-draft-authorization-after-lock-worker:$case_name';" >&2; exit 1; }
  printf 'CONTRACT_CONTENTION_OBSERVED case=%s worker_lock=%s\n' "$case_name" "$lock_evidence"
  # Autocommit makes this fixture-only revocation committed before lock release.
  run_psql -c "UPDATE public.sales_structured_draft_test_permissions SET sales_manage = false WHERE user_id = '00000000-0000-4000-8000-000000000001';"
  printf 'FIXTURE_PERMISSION_REVOCATION_COMMITTED case=%s\n' "$case_name"
  run_psql -c 'UPDATE public.structured_draft_authorization_after_lock_control SET released = true WHERE singleton;'
  wait "$holder_pid"; wait "$worker_pid"
done
run_psql -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_authorization_after_lock_assertions.sql"
# Revoke the fixture-only transport before fixture cleanup.
run_psql -c "REVOKE ALL ON FUNCTION public.save_sales_opportunity_structured_draft_revision(uuid, uuid, uuid, uuid, text, integer, jsonb, uuid) FROM authenticated;"
printf 'AUTHORIZATION_AFTER_LOCK_EXECUTION_COMPLETE=true\n'

#!/usr/bin/env bash
set -euo pipefail
# LOCAL DISPOSABLE POSTGRESQL 17 ONLY. Refuses remote, managed, and shared targets.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
work_dir="$(mktemp -d /tmp/structured_draft_conflict_race_XXXXXX)"
data_dir="$work_dir/data"; socket_dir="$work_dir/socket"; log_dir="$work_dir/logs"; database="structured_draft_acceptance_conflicts"; port=55434; server_pid=""
mkdir -p "$socket_dir" "$log_dir"
cleanup() { local status=$?; if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi; rm -rf "$work_dir"; printf 'CLEANUP_VERIFIED private_fixture_removed_on_exit=true\n'; exit "$status"; }
trap cleanup EXIT
[[ "$(id -u)" == "0" ]] || { echo "This disposable fixture requires the sandbox root user." >&2; exit 64; }
chown -R 1000:1000 "$work_dir"
setpriv --reuid=1000 --regid=1000 --clear-groups initdb -D "$data_dir" --no-locale --encoding=UTF8 --auth-local=trust -U lovable >/dev/null
cat >>"$data_dir/postgresql.conf" <<EOF
listen_addresses = ''
port = $port
unix_socket_directories = '$socket_dir'
shared_memory_type = mmap
dynamic_shared_memory_type = mmap
logging_collector = off
EOF
setpriv --reuid=1000 --regid=1000 --clear-groups postgres -D "$data_dir" >"$log_dir/postgres.log" 2>&1 & server_pid=$!
for _ in $(seq 1 150); do psql --host="$socket_dir" --port="$port" --username=lovable --dbname=postgres -Atqc 'SELECT 1' >/dev/null 2>&1 && break; sleep 0.1; done
psql --host="$socket_dir" --port="$port" --username=lovable --dbname=postgres -Atqc 'SELECT 1' >/dev/null
createdb --host="$socket_dir" --port="$port" --username=lovable "$database"
psql_args=(--set=ON_ERROR_STOP=1 --host="$socket_dir" --port="$port" --username=lovable --dbname="$database")
run_psql() { psql "${psql_args[@]}" "$@"; }
run_psql -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_fixture.sql"
run_psql -f "$root/supabase/pending/20261009_sales_opportunity_structured_draft_metadata.sql"
# Fixture-only transport; pending contract remains revoked by default.
run_psql -c "GRANT EXECUTE ON FUNCTION public.save_sales_opportunity_structured_draft_revision(uuid, uuid, uuid, uuid, text, integer, jsonb, uuid) TO authenticated;"
run_psql -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_conflict_race_setup.sql"
run_case() {
  local case_name="$1" loser_actor="$2" loser_payload="$3"
  PGAPPNAME="structured-draft-conflict-holder:$case_name" timeout 20s psql "${psql_args[@]}" -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_conflict_race_holder.sql" >"$log_dir/$case_name-holder.log" 2>&1 & local holder_pid=$!
  for _ in $(seq 1 150); do [[ "$(run_psql -Atqc 'SELECT holder_ready::text FROM public.structured_draft_conflict_race_control WHERE singleton')" == true ]] && break; sleep 0.1; done
  [[ "$(run_psql -Atqc 'SELECT holder_ready::text FROM public.structured_draft_conflict_race_control WHERE singleton')" == true ]] || { cat "$log_dir/$case_name-holder.log" >&2; return 1; }
  env PGAPPNAME="structured-draft-conflict-worker:winner:$case_name" timeout 20s psql "${psql_args[@]}" -v case_name="$case_name" -v worker_label=winner -v actor_id=00000000-0000-4000-8000-000000000001 -v payload='{"SCOPE_STATEMENT":"Concurrent scope","ACCEPTANCE_CRITERIA":"Concurrent acceptance"}' -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_conflict_race_worker.sql" >"$log_dir/$case_name-winner.log" 2>&1 & local winner_pid=$!
  env PGAPPNAME="structured-draft-conflict-worker:loser:$case_name" timeout 20s psql "${psql_args[@]}" -v case_name="$case_name" -v worker_label=loser -v actor_id="$loser_actor" -v payload="$loser_payload" -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_conflict_race_worker.sql" >"$log_dir/$case_name-loser.log" 2>&1 & local loser_pid=$!
  local lock_evidence=""
  for _ in $(seq 1 150); do lock_evidence="$(run_psql -Atqc "SELECT count(*)::text || ':' || coalesce(string_agg(pid::text || ':' || wait_event_type || ':' || wait_event, ',' ORDER BY pid), '') FROM pg_stat_activity WHERE application_name LIKE 'structured-draft-conflict-worker:%' AND application_name LIKE '%$case_name' AND wait_event_type = 'Lock' AND wait_event = 'advisory'")"; [[ "$lock_evidence" == 2:* ]] && break; sleep 0.1; done
  [[ "$lock_evidence" == 2:* ]] || { echo "Expected two contract advisory-lock waits for $case_name, saw: $lock_evidence" >&2; printf 'ACTIVE_WORKERS case=%s\n' "$case_name" >&2; run_psql -c "SELECT pid, application_name, state, wait_event_type, wait_event, query FROM pg_stat_activity WHERE application_name LIKE 'structured-draft-conflict-worker:%';" >&2; cat "$log_dir/$case_name-winner.log" "$log_dir/$case_name-loser.log" >&2; return 1; }
  printf 'CONTRACT_CONTENTION_OBSERVED case=%s workers=%s\n' "$case_name" "$lock_evidence"
  run_psql -c 'UPDATE public.structured_draft_conflict_race_control SET released = true WHERE singleton;'
  wait "$holder_pid"; wait "$winner_pid"; wait "$loser_pid"
  run_psql -c 'UPDATE public.structured_draft_conflict_race_control SET holder_ready = false, released = false WHERE singleton;'
}
run_case changed_payload 00000000-0000-4000-8000-000000000001 '{"SCOPE_STATEMENT":"Changed concurrent scope","ACCEPTANCE_CRITERIA":"Concurrent acceptance"}'
run_case different_actor 00000000-0000-4000-8000-000000000002 '{"SCOPE_STATEMENT":"Concurrent scope","ACCEPTANCE_CRITERIA":"Concurrent acceptance"}'
run_psql -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_conflict_race_assertions.sql"
printf 'CONFLICT_RACE_EXECUTION_COMPLETE=true\n'

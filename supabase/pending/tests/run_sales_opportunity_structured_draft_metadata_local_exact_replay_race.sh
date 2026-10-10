#!/usr/bin/env bash
set -euo pipefail

# LOCAL DISPOSABLE POSTGRESQL 17 ONLY. This creates and removes a fresh private
# Unix-socket fixture; it never accepts a managed, network, or shared database.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
work_dir="$(mktemp -d /tmp/structured_draft_exact_replay_race_XXXXXX)"
data_dir="$work_dir/data"
socket_dir="$work_dir/socket"
database="structured_draft_acceptance_exact_replay"
port=55433
log_dir="$work_dir/logs"
mkdir -p "$socket_dir" "$log_dir"
server_pid=""

cleanup() {
  local status=$?
  if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -rf "$work_dir"
  exit "$status"
}
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
setpriv --reuid=1000 --regid=1000 --clear-groups postgres -D "$data_dir" >"$log_dir/postgres.log" 2>&1 &
server_pid=$!

for _ in $(seq 1 150); do
  if psql --host="$socket_dir" --port="$port" --username=lovable --dbname=postgres -Atqc 'SELECT 1' >/dev/null 2>&1; then break; fi
  sleep 0.1
done
psql --host="$socket_dir" --port="$port" --username=lovable --dbname=postgres -Atqc 'SELECT 1' >/dev/null
createdb --host="$socket_dir" --port="$port" --username=lovable "$database"
psql_args=(--set=ON_ERROR_STOP=1 --host="$socket_dir" --port="$port" --username=lovable --dbname="$database")
run_psql() { psql "${psql_args[@]}" "$@"; }

run_psql -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_fixture.sql"
run_psql -f "$root/supabase/pending/20261009_sales_opportunity_structured_draft_metadata.sql"
# Fixture-only transport; the pending proposal itself remains fully revoked.
run_psql -c "GRANT EXECUTE ON FUNCTION public.save_sales_opportunity_structured_draft_revision(uuid, uuid, uuid, uuid, text, integer, jsonb, uuid) TO authenticated;"
run_psql -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_exact_replay_race_setup.sql"

PGAPPNAME=structured-draft-exact-replay-holder timeout 20s psql "${psql_args[@]}" -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_exact_replay_race_holder.sql" >"$log_dir/holder.log" 2>&1 &
holder_pid=$!
for _ in $(seq 1 150); do
  [[ "$(run_psql -Atqc 'SELECT holder_ready::text FROM public.structured_draft_exact_replay_race_control WHERE singleton')" == true ]] && break
  sleep 0.1
done
[[ "$(run_psql -Atqc 'SELECT holder_ready::text FROM public.structured_draft_exact_replay_race_control WHERE singleton')" == true ]] || { cat "$log_dir/holder.log" >&2; exit 1; }

for label in a b; do
  PGAPPNAME="structured-draft-exact-replay-worker:$label" timeout 20s psql "${psql_args[@]}" -v worker_label="$label" -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_exact_replay_race_worker.sql" >"$log_dir/$label.log" 2>&1 &
  eval "worker_${label}_pid=$!"
done

lock_evidence=""
for _ in $(seq 1 150); do
  lock_evidence="$(run_psql -Atqc "SELECT count(*)::text || ':' || string_agg(pid::text || ':' || wait_event_type || ':' || wait_event, ',' ORDER BY pid) FROM pg_stat_activity WHERE application_name LIKE 'structured-draft-exact-replay-worker:%' AND wait_event_type = 'Lock' AND wait_event = 'advisory'")"
  [[ "$lock_evidence" == 2:* ]] && break
  sleep 0.1
done
[[ "$lock_evidence" == 2:* ]] || { echo "Expected two contract advisory-lock waits, saw: $lock_evidence" >&2; exit 1; }
printf 'CONTRACT_CONTENTION_OBSERVED workers=%s\n' "$lock_evidence"

run_psql -c 'UPDATE public.structured_draft_exact_replay_race_control SET released = true WHERE singleton;'
wait "$holder_pid"
for label in a b; do
  worker_var="worker_${label}_pid"
  wait "${!worker_var}"
done
run_psql -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_exact_replay_race_assertions.sql"
printf 'CLEANUP_VERIFIED private_fixture_removed_on_exit=true\n'
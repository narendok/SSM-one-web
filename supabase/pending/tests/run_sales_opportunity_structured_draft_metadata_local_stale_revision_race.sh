#!/usr/bin/env bash
set -euo pipefail
# LOCAL DISPOSABLE POSTGRESQL 17 ONLY. Refuses remote, managed, and shared targets.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; work_dir="$(mktemp -d /tmp/structured_draft_stale_revision_race_XXXXXX)"; data_dir="$work_dir/data"; socket_dir="$work_dir/socket"; log_dir="$work_dir/logs"; database="structured_draft_acceptance_stale_revision"; port=55435; server_pid=""
mkdir -p "$socket_dir" "$log_dir"
cleanup() { local status=$?; if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi; rm -rf "$work_dir"; printf 'CLEANUP_VERIFIED private_fixture_removed_on_exit=true\n'; exit "$status"; }
trap cleanup EXIT
[[ "$(id -u)" == "0" ]] || { echo "This disposable fixture requires the sandbox root user." >&2; exit 64; }
chown -R 1000:1000 "$work_dir"; setpriv --reuid=1000 --regid=1000 --clear-groups initdb -D "$data_dir" --no-locale --encoding=UTF8 --auth-local=trust -U lovable >/dev/null
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
psql --host="$socket_dir" --port="$port" --username=lovable --dbname=postgres -Atqc 'SELECT 1' >/dev/null; createdb --host="$socket_dir" --port="$port" --username=lovable "$database"; psql_args=(--set=ON_ERROR_STOP=1 --host="$socket_dir" --port="$port" --username=lovable --dbname="$database")
run_psql() { psql "${psql_args[@]}" "$@"; }
run_psql -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_fixture.sql"; run_psql -f "$root/supabase/pending/20261009_sales_opportunity_structured_draft_metadata.sql"
# Fixture-only transport; the pending proposal remains fully revoked by default.
run_psql -c "GRANT EXECUTE ON FUNCTION public.save_sales_opportunity_structured_draft_revision(uuid, uuid, uuid, uuid, text, integer, jsonb, uuid) TO authenticated;"; run_psql -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_stale_revision_race_setup.sql"
PGAPPNAME=structured-draft-stale-revision-holder timeout 20s psql "${psql_args[@]}" -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_stale_revision_race_holder.sql" >"$log_dir/holder.log" 2>&1 & holder_pid=$!
for _ in $(seq 1 150); do [[ "$(run_psql -Atqc 'SELECT holder_ready::text FROM public.structured_draft_stale_revision_race_control WHERE singleton')" == true ]] && break; sleep 0.1; done
[[ "$(run_psql -Atqc 'SELECT holder_ready::text FROM public.structured_draft_stale_revision_race_control WHERE singleton')" == true ]] || { cat "$log_dir/holder.log" >&2; exit 1; }
for spec in 'winner|{"SCOPE_STATEMENT":"Winner scope","ACCEPTANCE_CRITERIA":"Winner acceptance"}|00000000-0000-4000-8000-000000000612' 'loser|{"SCOPE_STATEMENT":"Loser scope","ACCEPTANCE_CRITERIA":"Loser acceptance"}|00000000-0000-4000-8000-000000000613'; do IFS='|' read -r label payload request_key <<<"$spec"; env PGAPPNAME="structured-draft-stale-revision-worker:$label" timeout 20s psql "${psql_args[@]}" -v worker_label="$label" -v payload="$payload" -v request_key="$request_key" -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_stale_revision_race_worker.sql" >"$log_dir/$label.log" 2>&1 & eval "worker_${label}_pid=$!"; done
lock_evidence=""
for _ in $(seq 1 150); do lock_evidence="$(run_psql -Atqc "SELECT count(*)::text || ':' || coalesce(string_agg(pid::text || ':' || wait_event_type || ':' || wait_event, ',' ORDER BY pid), '') FROM pg_stat_activity WHERE application_name LIKE 'structured-draft-stale-revision-worker:%' AND wait_event_type = 'Lock' AND wait_event = 'advisory'")"; [[ "$lock_evidence" == 2:* ]] && break; sleep 0.1; done
[[ "$lock_evidence" == 2:* ]] || { echo "Expected two contract advisory-lock waits, saw: $lock_evidence" >&2; run_psql -c "SELECT pid, application_name, state, wait_event_type, wait_event, query FROM pg_stat_activity WHERE application_name LIKE 'structured-draft-stale-revision-worker:%';" >&2; exit 1; }
printf 'CONTRACT_CONTENTION_OBSERVED workers=%s\n' "$lock_evidence"; run_psql -c 'UPDATE public.structured_draft_stale_revision_race_control SET released = true WHERE singleton;'; wait "$holder_pid"; for label in winner loser; do worker_var="worker_${label}_pid"; wait "${!worker_var}"; done
run_psql -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_stale_revision_race_assertions.sql"; printf 'STALE_REVISION_RACE_EXECUTION_COMPLETE=true\n'
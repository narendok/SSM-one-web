#!/usr/bin/env bash
set -euo pipefail
# LOCAL DISPOSABLE PostgreSQL ONLY. It creates an isolated socket/database,
# applies the pending proposal unchanged, runs deterministic assertions, and
# removes only that fixture. It never contacts a managed backend.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
work_dir="$(mktemp -d /tmp/project_drive_provisioning_local_XXXXXX)"
data_dir="$work_dir/data"; socket_dir="$work_dir/socket"; log_dir="$work_dir/logs"; database="project_drive_provisioning_local"; port=55447; server_pid=""
mkdir -p "$socket_dir" "$log_dir"
cleanup() { local status=$?; if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi; rm -rf "$work_dir"; printf 'CLEANUP_VERIFIED disposable_fixture_removed=true\n'; exit "$status"; }
trap cleanup EXIT
[[ "$(id -u)" == "0" ]] || { echo "This disposable fixture requires sandbox root." >&2; exit 64; }
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
run_psql -f "$root/supabase/pending/tests/project_drive_provisioning_local_fixture.sql"
run_psql -f "$root/supabase/pending/20261005_harden_project_drive_provisioning_boundary.sql"
run_psql -f "$root/supabase/pending/tests/project_drive_provisioning_local_acceptance.sql"

# Exact project advisory-lock contention: both invocations must serialize to one root.
worker="$root/supabase/pending/tests/project_drive_provisioning_local_worker.sql"
psql "${psql_args[@]}" <<'SQL' >"$log_dir/lock_holder.out" 2>"$log_dir/lock_holder.err" & holder_pid=$!
BEGIN;
SELECT pg_advisory_xact_lock(hashtextextended('project-drive:00000000-0000-4000-8000-000000000102', 0));
SELECT pg_sleep(0.25);
COMMIT;
SQL
sleep 0.05
psql "${psql_args[@]}" -f "$worker" >"$log_dir/worker_a.out" 2>"$log_dir/worker_a.err" & worker_a_pid=$!
psql "${psql_args[@]}" -f "$worker" >"$log_dir/worker_b.out" 2>"$log_dir/worker_b.err" & worker_b_pid=$!
wait "$holder_pid"
wait "$worker_a_pid"
wait "$worker_b_pid"
root_count="$(run_psql -Atqc "SELECT count(*) FROM public.drive_nodes WHERE project_id = '00000000-0000-4000-8000-000000000102' AND folder_kind = 'PROJECT_ROOT' AND is_trashed = false")"
folder_count="$(run_psql -Atqc "SELECT count(*) FROM public.drive_nodes n JOIN public.projects p ON p.project_drive_node_id = n.parent_id WHERE p.id = '00000000-0000-4000-8000-000000000102' AND n.folder_kind = 'STANDARD' AND n.is_trashed = false")"
pointer_valid="$(run_psql -Atqc "SELECT count(*) FROM public.projects p JOIN public.drive_nodes n ON n.id = p.project_drive_node_id WHERE p.id = '00000000-0000-4000-8000-000000000102' AND n.project_id = p.id AND n.folder_kind = 'PROJECT_ROOT' AND n.is_trashed = false")"
[[ "$root_count/$folder_count/$pointer_valid" == "1/8/1" ]] || { echo "LOCAL_ASSERT_FAIL contention root/folders/pointer=$root_count/$folder_count/$pointer_valid" >&2; exit 1; }
printf 'NAMED_PASS deterministic_two_session_contention root_count=%s folder_count=%s pointer_valid=%s worker_exits=0/0\n' "$root_count" "$folder_count" "$pointer_valid"
printf 'PROJECT_DRIVE_PROVISIONING_LOCAL_ACCEPTANCE_PASS=true\n'
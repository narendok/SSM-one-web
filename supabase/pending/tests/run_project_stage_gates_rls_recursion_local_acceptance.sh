#!/usr/bin/env bash
set -euo pipefail
[[ "${LOCAL_PROJECT_STAGE_GATES_RLS_DISPOSABLE:-}" == "yes" ]] || { echo 'Set LOCAL_PROJECT_STAGE_GATES_RLS_DISPOSABLE=yes.' >&2; exit 64; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
work_dir="$(mktemp -d /tmp/project_stage_gates_rls_XXXXXX)"; data_dir="$work_dir/data"; socket_dir="$work_dir/socket"; port=55468; server_pid=""
cleanup() { status=$?; if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi; rm -rf "$work_dir"; printf 'CLEANUP_VERIFIED project_stage_gates_rls_fixture_removed=true\n'; exit "$status"; }
trap cleanup EXIT
[[ "$(id -u)" == "0" ]] || { echo 'Requires sandbox root for isolated postgres.' >&2; exit 64; }
mkdir -p "$socket_dir"; chown -R 1000:1000 "$work_dir"
setpriv --reuid=1000 --regid=1000 --clear-groups initdb -D "$data_dir" --no-locale --encoding=UTF8 --auth-local=trust -U lovable >/dev/null
cat >> "$data_dir/postgresql.conf" <<EOF
listen_addresses = ''
port = $port
unix_socket_directories = '$socket_dir'
shared_memory_type = mmap
dynamic_shared_memory_type = mmap
EOF
setpriv --reuid=1000 --regid=1000 --clear-groups postgres -D "$data_dir" >/dev/null 2>&1 & server_pid=$!
for _ in $(seq 1 150); do psql --host="$socket_dir" --port="$port" --username=lovable --dbname=postgres -Atqc 'SELECT 1' >/dev/null 2>&1 && break; sleep 0.1; done
psql --host="$socket_dir" --port="$port" --username=lovable --dbname=postgres -Atqc 'SELECT 1' >/dev/null
createdb --host="$socket_dir" --port="$port" --username=lovable project_stage_gates_rls_local
args=(--set=ON_ERROR_STOP=1 --host="$socket_dir" --port="$port" --username=lovable --dbname=project_stage_gates_rls_local)
psql "${args[@]}" -f "$root/supabase/pending/tests/project_stage_gates_rls_recursion_local_fixture.sql"
psql "${args[@]}" -f "$root/supabase/pending/20261011_project_stage_gates_rls_recursion_repair.sql"
psql "${args[@]}" -f "$root/supabase/pending/tests/project_stage_gates_rls_recursion_local_acceptance.sql"

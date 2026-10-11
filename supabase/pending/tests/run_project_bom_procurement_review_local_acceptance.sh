#!/usr/bin/env bash
set -euo pipefail
[[ "${LOCAL_PROJECT_BOM_PROCUREMENT_DISPOSABLE:-}" == "yes" ]] || { echo "Set LOCAL_PROJECT_BOM_PROCUREMENT_DISPOSABLE=yes to run a disposable fixture." >&2; exit 64; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; work_dir="$(mktemp -d /tmp/project_bom_procurement_local_XXXXXX)"; data_dir="$work_dir/data"; socket_dir="$work_dir/socket"; port=55461; server_pid=""
cleanup() { status=$?; if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi; rm -rf "$work_dir"; printf 'CLEANUP_VERIFIED disposable_fixture_removed=true\n'; exit "$status"; }
trap cleanup EXIT
[[ "$(id -u)" == "0" ]] || { echo "This disposable fixture requires sandbox root." >&2; exit 64; }
mkdir -p "$socket_dir"; chown -R 1000:1000 "$work_dir"
setpriv --reuid=1000 --regid=1000 --clear-groups initdb -D "$data_dir" --no-locale --encoding=UTF8 --auth-local=trust -U lovable >/dev/null
printf "listen_addresses=''\nport=%s\nunix_socket_directories='%s'\nshared_memory_type=mmap\ndynamic_shared_memory_type=mmap\n" "$port" "$socket_dir" >> "$data_dir/postgresql.conf"
setpriv --reuid=1000 --regid=1000 --clear-groups postgres -D "$data_dir" >/dev/null 2>&1 & server_pid=$!
for _ in $(seq 1 150); do psql --host="$socket_dir" --port="$port" --username=lovable --dbname=postgres -Atqc 'SELECT 1' >/dev/null 2>&1 && break; sleep 0.1; done
psql --host="$socket_dir" --port="$port" --username=lovable --dbname=postgres -Atqc 'SELECT 1' >/dev/null
createdb --host="$socket_dir" --port="$port" --username=lovable procurement_local
args=(--set=ON_ERROR_STOP=1 --host="$socket_dir" --port="$port" --username=lovable --dbname=procurement_local)
psql "${args[@]}" -f "$root/supabase/pending/tests/project_bom_procurement_review_local_fixture.sql"
psql "${args[@]}" -f "$root/supabase/pending/20261012_project_bom_procurement_review_contract.sql"
psql "${args[@]}" -f "$root/supabase/pending/tests/project_bom_procurement_review_local_acceptance.sql"
python3 "$root/supabase/pending/tests/check_project_bom_procurement_review_contract_static.py"
printf 'PROJECT_BOM_PROCUREMENT_REVIEW_LOCAL_ACCEPTANCE_PASS=true\n'

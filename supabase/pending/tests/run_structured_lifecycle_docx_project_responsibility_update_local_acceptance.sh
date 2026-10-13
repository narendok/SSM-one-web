#!/usr/bin/env bash
set -euo pipefail
[[ "${LOCAL_STRUCTURED_LIFECYCLE_DOCX_REGISTRY_DISPOSABLE:-}" == "yes" ]] || { echo 'Set LOCAL_STRUCTURED_LIFECYCLE_DOCX_REGISTRY_DISPOSABLE=yes for local disposable execution.' >&2; exit 64; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; work_dir="$(mktemp -d /tmp/structured_docx_responsibility_update_XXXXXX)"; data_dir="$work_dir/data"; socket_dir="$work_dir/socket"; port=55477; server_pid=""
cleanup(){ status=$?; if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi; rm -rf "$work_dir"; printf 'CLEANUP_VERIFIED responsibility_update_fixture_removed=true\n'; exit "$status"; }; trap cleanup EXIT
[[ "$(id -u)" == 0 ]] || { echo 'Requires disposable root runner only.' >&2; exit 64; }
mkdir -p "$socket_dir"; chown -R 1000:1000 "$work_dir"; setpriv --reuid=1000 --regid=1000 --clear-groups initdb -D "$data_dir" --no-locale --encoding=UTF8 --auth-local=trust -U lovable >/dev/null
printf "listen_addresses=''\nport=%s\nunix_socket_directories='%s'\nshared_memory_type=mmap\ndynamic_shared_memory_type=mmap\n" "$port" "$socket_dir" >> "$data_dir/postgresql.conf"; setpriv --reuid=1000 --regid=1000 --clear-groups postgres -D "$data_dir" >/dev/null 2>&1 & server_pid=$!
for _ in $(seq 1 150); do psql --host="$socket_dir" --port="$port" --username=lovable --dbname=postgres -Atqc 'SELECT 1' >/dev/null 2>&1 && break; sleep .1; done
createdb --host="$socket_dir" --port="$port" --username=lovable structured_docx_responsibility_update; args=(--set=ON_ERROR_STOP=1 --host="$socket_dir" --port="$port" --username=lovable --dbname=structured_docx_responsibility_update)
psql "${args[@]}" -f "$root/supabase/pending/tests/structured_lifecycle_docx_registry_local_fixture.sql"
psql "${args[@]}" -f "$root/supabase/pending/20261012_structured_lifecycle_docx_registry_contract.sql"
psql "${args[@]}" -f "$root/supabase/pending/20261013_structured_lifecycle_docx_project_responsibility_update_contract.sql"
psql "${args[@]}" -f "$root/supabase/pending/tests/structured_lifecycle_docx_project_responsibility_update_local_acceptance.sql"
printf 'STRUCTURED_LIFECYCLE_DOCX_PROJECT_RESPONSIBILITY_UPDATE_LOCAL_ACCEPTANCE_PASS=true\n'
#!/usr/bin/env bash
set -euo pipefail
# LOCAL DISPOSABLE PostgreSQL ONLY. It never contacts a managed backend.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
[[ "${LOCAL_DEVIATION_SUBMISSION_DISPOSABLE:-}" == "yes" ]] || { echo "Set LOCAL_DEVIATION_SUBMISSION_DISPOSABLE=yes to run a disposable fixture." >&2; exit 64; }
work_dir="$(mktemp -d /tmp/project_deviation_submission_local_XXXXXX)"; data_dir="$work_dir/data"; socket_dir="$work_dir/socket"; database="project_deviation_submission_local"; port=55463; server_pid=""
cleanup() { local status=$?; if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi; rm -rf "$work_dir"; printf 'CLEANUP_VERIFIED project_deviation_submission_fixture_removed=true\n'; exit "$status"; }
trap cleanup EXIT
[[ "$(id -u)" == "0" ]] || { echo "This disposable fixture requires sandbox root." >&2; exit 64; }
mkdir -p "$socket_dir"; chown -R 1000:1000 "$work_dir"
setpriv --reuid=1000 --regid=1000 --clear-groups initdb -D "$data_dir" --no-locale --encoding=UTF8 --auth-local=trust -U lovable >/dev/null
cat >>"$data_dir/postgresql.conf" <<EOF
listen_addresses = ''
port = $port
unix_socket_directories = '$socket_dir'
shared_memory_type = mmap
dynamic_shared_memory_type = mmap
EOF
setpriv --reuid=1000 --regid=1000 --clear-groups postgres -D "$data_dir" >/dev/null 2>&1 & server_pid=$!
for _ in $(seq 1 150); do psql --host="$socket_dir" --port="$port" --username=lovable --dbname=postgres -Atqc 'SELECT 1' >/dev/null 2>&1 && break; sleep 0.1; done
psql --host="$socket_dir" --port="$port" --username=lovable --dbname=postgres -Atqc 'SELECT 1' >/dev/null
createdb --host="$socket_dir" --port="$port" --username=lovable "$database"
psql_args=(--set=ON_ERROR_STOP=1 --host="$socket_dir" --port="$port" --username=lovable --dbname="$database")
psql "${psql_args[@]}" -f "$root/supabase/pending/tests/project_deviation_submission_local_fixture.sql"
psql "${psql_args[@]}" -f "$root/supabase/pending/20261011_project_deviation_submission.sql"
psql "${psql_args[@]}" -c "CREATE TRIGGER project_deviation_receipt_fail BEFORE INSERT ON public.project_deviation_submission_request_receipts FOR EACH ROW EXECUTE FUNCTION public.deviation_test_failpoint();"
psql "${psql_args[@]}" -f "$root/supabase/pending/tests/project_deviation_submission_local_acceptance.sql"
printf 'PROJECT_DEVIATION_SUBMISSION_LOCAL_ACCEPTANCE_PASS=true\n'
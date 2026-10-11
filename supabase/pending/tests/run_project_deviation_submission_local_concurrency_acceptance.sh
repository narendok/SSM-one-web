#!/usr/bin/env bash
set -euo pipefail
# LOCAL DISPOSABLE PostgreSQL ONLY. It never contacts a managed backend.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
[[ "${LOCAL_DEVIATION_SUBMISSION_DISPOSABLE:-}" == "yes" ]] || { echo "Set LOCAL_DEVIATION_SUBMISSION_DISPOSABLE=yes to run a disposable fixture." >&2; exit 64; }
work_dir="$(mktemp -d /tmp/project_deviation_submission_local_concurrency_XXXXXX)"; data_dir="$work_dir/data"; socket_dir="$work_dir/socket"; database="project_deviation_submission_local_concurrency"; port=55464; server_pid=""
cleanup() { local status=$?; if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi; rm -rf "$work_dir"; printf 'CLEANUP_VERIFIED project_deviation_submission_concurrency_fixture_removed=true\n'; exit "$status"; }
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
psql "${psql_args[@]}" -f "$root/supabase/pending/tests/project_deviation_submission_local_fixture.sql" >/dev/null
psql "${psql_args[@]}" -f "$root/supabase/pending/20261011_project_deviation_submission.sql" >/dev/null
psql "${psql_args[@]}" -f "$root/supabase/pending/tests/project_deviation_submission_local_concurrency_setup.sql" >/dev/null
project='50000000-0000-4000-8000-000000000016'; source_register='50000000-0000-4000-8000-000000000026'; source_revision='50000000-0000-4000-8000-000000000023'; evidence='[{"documentRegisterId":"50000000-0000-4000-8000-000000000027","documentRevisionId":"50000000-0000-4000-8000-000000000024"}]'; payload='{"reason":"Concurrent supplier difference","risk":"Heat drift","safeguards":"Incoming inspection","customerImpact":false,"affectedPartReference":"R7","affectedRevisionReference":"B","affectedQuantity":25}'; changed_payload='{"reason":"Different concurrent reason","risk":"Heat drift","safeguards":"Incoming inspection","customerImpact":false,"affectedPartReference":"R7","affectedRevisionReference":"B","affectedQuantity":25}'
q() { psql "${psql_args[@]}" -Atqc "$1"; }
assert_eq() { [[ "$1" == "$2" ]] || { echo "ASSERT_FAIL $3 expected=$2 actual=$1" >&2; exit 1; }; }
reset_authority_and_pins() { q "UPDATE public.employees SET employment_status = 'ACTIVE' WHERE id = '50000000-0000-4000-8000-000000000014'; UPDATE public.project_team_members SET employee_id = '50000000-0000-4000-8000-000000000014' WHERE id = '50000000-0000-4000-8000-000000000018'; UPDATE public.document_control_registers SET document_status = 'APPROVED', controlled_version = CASE id WHEN '50000000-0000-4000-8000-000000000026' THEN 3 ELSE 2 END;"; }
run_worker() { local label=$1 req=$2 body=$3; local pidfile="$work_dir/$label.pid"; psql "${psql_args[@]}" -v pidfile="$pidfile" -v request_key="$req" -v payload="$body" -v evidence="$evidence" -v project="$project" -v source_register="$source_register" -v source_revision="$source_revision" >"$work_dir/$label.out" 2>"$work_dir/$label.err" <<'SQL' &
\set ON_ERROR_STOP on
\o :pidfile
\pset tuples_only on
\pset format unaligned
SELECT pg_backend_pid();
\o
SELECT set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000001', false);
SELECT deviation_submission_id, deviation_revision_id, replayed FROM public.submit_project_deviation(:'project'::uuid, :'source_register'::uuid, :'source_revision'::uuid, :'payload'::jsonb, :'evidence'::jsonb, :'request_key'::uuid);
SQL
worker_pid=$!; echo "$worker_pid"; }
wait_for_file() { local file=$1; for _ in $(seq 1 200); do [[ -s "$file" ]] && return; sleep 0.02; done; echo "worker PID file missing: $file" >&2; exit 1; }
hold_lock() { local token=$1; q "INSERT INTO public.deviation_test_sync(token) VALUES ('$token')"; psql "${psql_args[@]}" -v token="$token" -v project="$project" >"$work_dir/$token.holder.out" 2>"$work_dir/$token.holder.err" <<'SQL' &
\set ON_ERROR_STOP on
BEGIN;
SELECT public.deviation_test_hold_project_lock(:'project'::uuid, :'token');
COMMIT;
SQL
holder_pid=$!; echo "$holder_pid"; }
assert_waiting_exact_lock() { local pid=$1; local actual; actual="$(q "SELECT count(*) FROM pg_locks WHERE pid = $pid AND locktype = 'advisory' AND NOT granted AND classid = ((hashtextextended('project-deviation-project:' || '$project', 0) >> 32) & 4294967295)::bigint AND objid = (hashtextextended('project-deviation-project:' || '$project', 0) & 4294967295)::bigint")"; assert_eq "$actual" 1 "same worker prewait exact project advisory lock"; }
release_lock() { local token=$1 holder=$2; q "UPDATE public.deviation_test_sync SET released = true WHERE token = '$token'"; wait "$holder"; }
counts() { q "SELECT count(*) || ':' || (SELECT count(*) FROM public.project_deviation_submission_revisions) || ':' || (SELECT count(*) FROM public.project_deviation_submission_evidence) || ':' || (SELECT count(*) FROM public.project_deviation_submission_audit_events) || ':' || (SELECT count(*) FROM public.project_deviation_submission_request_receipts) FROM public.project_deviation_submissions"; }
reset_authority_and_pins
hold_lock IDENTICAL_REPLAY; holder=$holder_pid; run_worker identical_one 50000000-0000-4000-8000-000000000101 "$payload"; w1=$worker_pid; run_worker identical_two 50000000-0000-4000-8000-000000000101 "$payload"; w2=$worker_pid; wait_for_file "$work_dir/identical_one.pid"; wait_for_file "$work_dir/identical_two.pid"; assert_waiting_exact_lock "$(cat "$work_dir/identical_one.pid")"; assert_waiting_exact_lock "$(cat "$work_dir/identical_two.pid")"; release_lock IDENTICAL_REPLAY "$holder"; wait "$w1"; wait "$w2"; assert_eq "$(counts)" '1:1:1:1:1' 'identical workers create one immutable graph'; replay_count="$(awk -F '|' '$3 ~ /^[[:space:]]*t[[:space:]]*$/ { count++ } END { print count + 0 }' "$work_dir/identical_one.out" "$work_dir/identical_two.out")"; assert_eq "$replay_count" 1 'identical submission returns exactly one replay'; printf 'IDENTICAL_REPLAY_PASS=true\n'
hold_lock CONFLICTING_PAYLOAD; holder=$holder_pid; run_worker conflict_one 50000000-0000-4000-8000-000000000102 "$payload"; w1=$worker_pid; run_worker conflict_two 50000000-0000-4000-8000-000000000102 "$changed_payload"; w2=$worker_pid; wait_for_file "$work_dir/conflict_one.pid"; wait_for_file "$work_dir/conflict_two.pid"; assert_waiting_exact_lock "$(cat "$work_dir/conflict_one.pid")"; assert_waiting_exact_lock "$(cat "$work_dir/conflict_two.pid")"; release_lock CONFLICTING_PAYLOAD "$holder"; s1=0; s2=0; wait "$w1" || s1=$?; wait "$w2" || s2=$?; assert_eq "$(( (s1 == 0 ? 1 : 0) + (s2 == 0 ? 1 : 0) ))" 1 'conflicting payload has one winner'; grep -q 'Request key conflicts with a different actor or canonical payload' "$work_dir/conflict_one.err" "$work_dir/conflict_two.err"; assert_eq "$(counts)" '2:2:2:2:2' 'conflicting payload denial preserves one added graph'; printf 'CONFLICTING_PAYLOAD_PASS=true\n'
run_revocation_case() { local label=$1 mutation=$2 req=$3 expected_counts=$4; reset_authority_and_pins; hold_lock "$label"; holder=$holder_pid; run_worker "$label" "$req" "$payload"; worker=$worker_pid; wait_for_file "$work_dir/$label.pid"; assert_waiting_exact_lock "$(cat "$work_dir/$label.pid")"; q "$mutation"; release_lock "$label" "$holder"; status=0; wait "$worker" || status=$?; [[ $status -ne 0 ]] || { echo "ASSERT_FAIL $label unexpectedly succeeded" >&2; exit 1; }; grep -q 'Deviation submission requires\|Deviation evidence requires' "$work_dir/$label.err"; assert_eq "$(counts)" "$expected_counts" "$label preserves immutable history"; printf '%s_PASS=true\n' "$label"; }
run_revocation_case REVOKED_NEW "UPDATE public.employees SET employment_status = 'INACTIVE' WHERE id = '50000000-0000-4000-8000-000000000014'" 50000000-0000-4000-8000-000000000103 '2:2:2:2:2'
reset_authority_and_pins; q "SELECT set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000001', false); SELECT * FROM public.submit_project_deviation('$project'::uuid, '$source_register'::uuid, '$source_revision'::uuid, '$payload'::jsonb, '$evidence'::jsonb, '50000000-0000-4000-8000-000000000104'::uuid);" >/dev/null; run_revocation_case REVOKED_REPLAY "UPDATE public.employees SET employment_status = 'INACTIVE' WHERE id = '50000000-0000-4000-8000-000000000014'" 50000000-0000-4000-8000-000000000104 '3:3:3:3:3'
run_revocation_case SOURCE_STATUS_CHANGED "UPDATE public.document_control_registers SET document_status = 'DRAFT' WHERE id = '$source_register'" 50000000-0000-4000-8000-000000000105 '3:3:3:3:3'
run_revocation_case SOURCE_REVISION_CHANGED "UPDATE public.document_control_registers SET controlled_version = 4 WHERE id = '$source_register'" 50000000-0000-4000-8000-000000000106 '3:3:3:3:3'
run_revocation_case EVIDENCE_STATUS_CHANGED "UPDATE public.document_control_registers SET document_status = 'DRAFT' WHERE id = '50000000-0000-4000-8000-000000000027'" 50000000-0000-4000-8000-000000000107 '3:3:3:3:3'
run_revocation_case EVIDENCE_REVISION_CHANGED "UPDATE public.document_control_registers SET controlled_version = 3 WHERE id = '50000000-0000-4000-8000-000000000027'" 50000000-0000-4000-8000-000000000108 '3:3:3:3:3'
printf 'PROJECT_DEVIATION_SUBMISSION_LOCAL_CONCURRENCY_ACCEPTANCE_PASS=true\n'
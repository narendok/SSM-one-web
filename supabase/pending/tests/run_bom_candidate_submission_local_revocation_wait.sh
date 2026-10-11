#!/usr/bin/env bash
set -euo pipefail
# LOCAL DISPOSABLE PostgreSQL ONLY. This uses the contract's exact project
# advisory key; it never contacts a managed backend or changes production SQL.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
[[ "${LOCAL_BOM_CANDIDATE_DISPOSABLE:-}" == "yes" ]] || { echo "Set LOCAL_BOM_CANDIDATE_DISPOSABLE=yes to run a disposable fixture." >&2; exit 64; }
work_dir="$(mktemp -d /tmp/bom_candidate_submission_revocation_wait_XXXXXX)"; data_dir="$work_dir/data"; socket_dir="$work_dir/socket"; log_dir="$work_dir/logs"; database="bom_candidate_submission_revocation_wait_local"; port=55459; server_pid=""
mkdir -p "$socket_dir" "$log_dir"
cleanup() { local status=$?; if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi; rm -rf "$work_dir"; printf 'CLEANUP_VERIFIED candidate_revocation_wait_fixture_removed=true\n'; exit "$status"; }
trap cleanup EXIT
[[ "$(id -u)" == "0" ]] || { echo "This disposable fixture requires sandbox root." >&2; exit 64; }
chown -R 1000:1000 "$work_dir"
setpriv --reuid=1000 --regid=1000 --clear-groups initdb -D "$data_dir" --no-locale --encoding=UTF8 --auth-local=trust -U lovable >/dev/null
cat >>"$data_dir/postgresql.conf" <<EOF
listen_addresses = ''
port = $port
unix_socket_directories = '$socket_dir'
shared_memory_type = mmap
dynamic_shared_memory_type = mmap
EOF
setpriv --reuid=1000 --regid=1000 --clear-groups postgres -D "$data_dir" >"$log_dir/postgres.log" 2>&1 & server_pid=$!
for _ in $(seq 1 150); do psql --host="$socket_dir" --port="$port" --username=lovable --dbname=postgres -Atqc 'SELECT 1' >/dev/null 2>&1 && break; sleep 0.1; done
psql --host="$socket_dir" --port="$port" --username=lovable --dbname=postgres -Atqc 'SELECT 1' >/dev/null
createdb --host="$socket_dir" --port="$port" --username=lovable "$database"
psql_args=(--set=ON_ERROR_STOP=1 --host="$socket_dir" --port="$port" --username=lovable --dbname="$database")
run_psql() { psql "${psql_args[@]}" "$@"; }
run_psql -f "$root/supabase/pending/tests/bom_candidate_submission_local_fixture.sql"
run_psql -f "$root/supabase/pending/20261011_bom_candidate_submission.sql"
run_psql -f "$root/supabase/pending/tests/bom_candidate_submission_local_concurrency_setup.sql"

# Creates one authorized receipt before the replay-wait revocation case.
run_psql -Atqc "SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', false); SELECT * FROM public.submit_component_candidate('00000000-0000-4000-8000-000000000116', '00000000-0000-4000-8000-000000000117', '{\"categoryId\":\"cat-1\",\"name\":\"Existing receipt\",\"partNumber\":\"R-REVOKED-REPLAY\"}'::jsonb, '00000000-0000-4000-8000-000000000191')" >/dev/null
project_id='00000000-0000-4000-8000-000000000116'
employee_id='00000000-0000-4000-8000-000000000115'
team_id='00000000-0000-4000-8000-000000000119'
waiter_name='bom_candidate_submission_revocation_waiter'

wait_for_exact_project_lock() {
  local expected_request_key="$1"
  for _ in $(seq 1 100); do
    local observed
    observed="$(run_psql -Atqc "WITH key AS (SELECT hashtextextended('component-candidate-project:' || '$project_id', 0) AS value), waiter AS (SELECT pid FROM pg_stat_activity WHERE application_name = '$waiter_name' AND query LIKE '%submit_component_candidate%' ORDER BY query_start DESC LIMIT 1) SELECT CASE WHEN EXISTS (SELECT 1 FROM pg_stat_activity activity JOIN waiter ON waiter.pid = activity.pid JOIN pg_locks lock ON lock.pid = activity.pid CROSS JOIN key WHERE activity.wait_event_type = 'Lock' AND lock.locktype = 'advisory' AND NOT lock.granted AND lock.classid::bigint = ((key.value >> 32) & 4294967295) AND lock.objid::bigint = (key.value & 4294967295)) THEN 'waiting-on-exact-project-lock' ELSE '' END")"
    [[ "$observed" == 'waiting-on-exact-project-lock' ]] && return 0
    sleep 0.02
  done
  echo "LOCAL_CASE_FAIL waiter did not wait on exact project advisory lock for $expected_request_key" >&2
  return 1
}

run_case() {
  local label="$1" request_key="$2" payload="$3" revoke_sql="$4" before_counts="$5"
  psql "${psql_args[@]}" <<SQL >"$log_dir/$label-locker.out" 2>"$log_dir/$label-locker.err" & locker_pid=$!
BEGIN;
SELECT pg_advisory_xact_lock(hashtextextended('component-candidate-project:' || '$project_id', 0));
SELECT pg_sleep(0.25);
COMMIT;
SQL
  sleep 0.02
  psql "${psql_args[@]}" --set=request_key="$request_key" --set=candidate_payload="$payload" -f "$root/supabase/pending/tests/bom_candidate_submission_local_revocation_wait_worker.sql" >"$log_dir/$label-waiter.out" 2>"$log_dir/$label-waiter.err" & waiter_pid=$!
  wait_for_exact_project_lock "$request_key"
  run_psql -c "$revoke_sql" >/dev/null
  wait "$locker_pid"
  waiter_status=0; wait "$waiter_pid" || waiter_status=$?
  [[ "$waiter_status" == '3' ]] || { cat "$log_dir/$label-waiter.err" >&2; exit 1; }
  grep -Fq 'ERROR:  Candidate submission requires a project-manager team member, an approved project-initiated baseline, a completed exact-project handover, exact customer/opportunity linkage, and an active HARDWARE department' "$log_dir/$label-waiter.err" || { cat "$log_dir/$label-waiter.err" >&2; exit 1; }
  local returned_rows
  returned_rows="$(grep -Ec '^[0-9a-f-]{36}\|[0-9a-f-]{36}\|(t|f)$' "$log_dir/$label-waiter.out" || true)"
  [[ "$returned_rows" == '0' ]] || { cat "$log_dir/$label-waiter.out" >&2; echo "LOCAL_CASE_FAIL $label returned a candidate result after revocation" >&2; exit 1; }
  local after_counts
  after_counts="$(run_psql -Atqc "SELECT count(*)::text || '/' || (SELECT count(*) FROM public.component_candidate_payload_revisions)::text || '/' || (SELECT count(*) FROM public.component_candidate_submission_audit_events)::text || '/' || (SELECT count(*) FROM public.component_candidate_submission_request_receipts)::text FROM public.component_candidate_submissions")"
  [[ "$after_counts" == "$before_counts" ]] || { echo "LOCAL_CASE_FAIL $label changed candidate graph before=$before_counts after=$after_counts" >&2; exit 1; }
}

before_replay="$(run_psql -Atqc "SELECT count(*)::text || '/' || (SELECT count(*) FROM public.component_candidate_payload_revisions)::text || '/' || (SELECT count(*) FROM public.component_candidate_submission_audit_events)::text || '/' || (SELECT count(*) FROM public.component_candidate_submission_request_receipts)::text FROM public.component_candidate_submissions")"
run_case 'replay' '00000000-0000-4000-8000-000000000191' '{"categoryId":"cat-1","name":"Existing receipt","partNumber":"R-REVOKED-REPLAY"}' "DELETE FROM public.project_team_members WHERE id = '$team_id';" "$before_replay"
[[ "$(run_psql -Atqc "SELECT count(*) FROM public.component_candidate_submission_request_receipts WHERE request_key = '00000000-0000-4000-8000-000000000191'")" == '1' ]] || { echo 'LOCAL_CASE_FAIL revoked replay mutated existing receipt count' >&2; exit 1; }
run_psql -c "INSERT INTO public.project_team_members VALUES ('$team_id', '$project_id', '$employee_id');" >/dev/null

before_new="$(run_psql -Atqc "SELECT count(*)::text || '/' || (SELECT count(*) FROM public.component_candidate_payload_revisions)::text || '/' || (SELECT count(*) FROM public.component_candidate_submission_audit_events)::text || '/' || (SELECT count(*) FROM public.component_candidate_submission_request_receipts)::text FROM public.component_candidate_submissions")"
run_case 'new' '00000000-0000-4000-8000-000000000192' '{"categoryId":"cat-1","name":"New after revocation","partNumber":"R-REVOKED-NEW"}' "UPDATE public.employees SET employment_status = 'INACTIVE' WHERE id = '$employee_id';" "$before_new"
[[ "$(run_psql -Atqc "SELECT count(*) FROM public.component_candidate_submission_request_receipts WHERE request_key = '00000000-0000-4000-8000-000000000192'")" == '0' ]] || { echo 'LOCAL_CASE_FAIL revoked new request created a receipt' >&2; exit 1; }
printf 'BOM_CANDIDATE_SUBMISSION_LOCAL_REVOCATION_WAIT_PASS exact_project_lock_verified=true replay_result_returned=false replay_graph_unchanged=true new_request_graph_unchanged=true\n'
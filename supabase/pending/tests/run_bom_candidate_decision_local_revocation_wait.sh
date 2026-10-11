#!/usr/bin/env bash
set -euo pipefail
# LOCAL DISPOSABLE PostgreSQL ONLY. This uses the contract's exact decision
# advisory key; it never contacts a managed backend or changes production SQL.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
[[ "${LOCAL_BOM_CANDIDATE_DISPOSABLE:-}" == "yes" ]] || { echo "Set LOCAL_BOM_CANDIDATE_DISPOSABLE=yes to run a disposable fixture." >&2; exit 64; }
work_dir="$(mktemp -d /tmp/bom_candidate_decision_revocation_wait_XXXXXX)"; data_dir="$work_dir/data"; socket_dir="$work_dir/socket"; log_dir="$work_dir/logs"; database="bom_candidate_decision_revocation_wait_local"; port=55461; server_pid=""
mkdir -p "$socket_dir" "$log_dir"
cleanup() { local status=$?; if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi; if [[ "$status" != '0' ]]; then cp -R "$log_dir" /tmp/bom-candidate-decision-revocation-failure-logs; printf 'LOCAL_FAILURE_LOGS_PRESERVED path=/tmp/bom-candidate-decision-revocation-failure-logs\n'; fi; rm -rf "$work_dir"; printf 'CLEANUP_VERIFIED candidate_decision_revocation_wait_fixture_removed=true\n'; exit "$status"; }
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

run_psql <<'SQL'
BEGIN;
INSERT INTO public.customers VALUES ('30000000-0000-4000-8000-000000000010');
INSERT INTO public.sales_opportunities VALUES ('30000000-0000-4000-8000-000000000011', '30000000-0000-4000-8000-000000000010');
INSERT INTO public.customer_requirements VALUES ('30000000-0000-4000-8000-000000000012', '30000000-0000-4000-8000-000000000010', '30000000-0000-4000-8000-000000000011');
INSERT INTO public.requirement_baselines VALUES ('30000000-0000-4000-8000-000000000013', '30000000-0000-4000-8000-000000000012', 'project_initiated', '30000000-0000-4000-8000-000000000001', clock_timestamp());
INSERT INTO public.departments VALUES ('30000000-0000-4000-8000-000000000014', 'HARDWARE', true);
INSERT INTO public.employees VALUES ('30000000-0000-4000-8000-000000000015', '30000000-0000-4000-8000-000000000001', 'ACTIVE'), ('30000000-0000-4000-8000-000000000025', '30000000-0000-4000-8000-000000000002', 'ACTIVE');
INSERT INTO public.employee_departments VALUES ('30000000-0000-4000-8000-000000000015', '30000000-0000-4000-8000-000000000014'), ('30000000-0000-4000-8000-000000000025', '30000000-0000-4000-8000-000000000014');
INSERT INTO public.access_roles(id, name) VALUES ('30000000-0000-4000-8000-000000000028', 'Local engineering approver');
INSERT INTO public.employee_access_roles VALUES ('30000000-0000-4000-8000-000000000025', '30000000-0000-4000-8000-000000000028');
INSERT INTO public.access_role_permissions(role_id, permission_id) SELECT '30000000-0000-4000-8000-000000000028', id FROM public.permissions WHERE key = 'engineering.approve';
INSERT INTO public.projects VALUES ('30000000-0000-4000-8000-000000000016', '30000000-0000-4000-8000-000000000010', '30000000-0000-4000-8000-000000000011', '30000000-0000-4000-8000-000000000013', '30000000-0000-4000-8000-000000000015');
INSERT INTO public.project_boms VALUES ('30000000-0000-4000-8000-000000000017', '30000000-0000-4000-8000-000000000016');
INSERT INTO public.project_team_members VALUES ('30000000-0000-4000-8000-000000000019', '30000000-0000-4000-8000-000000000016', '30000000-0000-4000-8000-000000000015');
INSERT INTO public.sales_project_handovers VALUES ('30000000-0000-4000-8000-000000000020', '30000000-0000-4000-8000-000000000013', '30000000-0000-4000-8000-000000000016', 'completed');
COMMIT;
SQL

create_candidate() {
  local part="$1" request_key="$2"
  run_psql -Atqc "SELECT set_config('request.jwt.claim.sub', '30000000-0000-4000-8000-000000000001', false); SELECT candidate_id FROM public.submit_component_candidate('30000000-0000-4000-8000-000000000016', '30000000-0000-4000-8000-000000000017', jsonb_build_object('categoryId', 'local-category', 'name', '$part', 'partNumber', '$part'), '$request_key');" | tail -n 1
}
revision_for() { run_psql -Atqc "SELECT id FROM public.component_candidate_payload_revisions WHERE candidate_id = '$1'::uuid"; }
assert_authorized_fixture() {
  local candidate_id="$1" revision_id="$2" label="$3"
  local preflight
  preflight="$(run_psql -Atqc "SELECT set_config('request.jwt.claim.sub', '30000000-0000-4000-8000-000000000002', false); WITH actor AS (SELECT auth.uid() AS id), facts AS (SELECT (SELECT id FROM actor) AS auth_uid, (SELECT EXISTS (SELECT 1 FROM public.employees employee WHERE employee.user_id = (SELECT id FROM actor) AND employee.employment_status = 'ACTIVE')) AS active_employee, public.has_permission((SELECT id FROM actor), 'engineering.approve') AS has_permission, (SELECT EXISTS (SELECT 1 FROM public.employees employee JOIN public.employee_departments membership ON membership.employee_id = employee.id JOIN public.departments department ON department.id = membership.department_id WHERE employee.user_id = (SELECT id FROM actor) AND department.code = 'HARDWARE' AND department.is_active)) AS active_hardware_membership, (SELECT submitted_by <> (SELECT id FROM actor) FROM public.component_candidate_submissions WHERE id = '$candidate_id'::uuid) AS not_self_review, (SELECT EXISTS (SELECT 1 FROM public.component_candidate_submissions candidate JOIN public.component_candidate_payload_revisions revision ON revision.candidate_id = candidate.id AND revision.id = '$revision_id'::uuid AND revision.revision_number = 1 WHERE candidate.id = '$candidate_id'::uuid)) AS exact_revision, (SELECT status FROM public.component_candidate_submissions WHERE id = '$candidate_id'::uuid) AS candidate_status, (SELECT EXISTS (SELECT 1 FROM public.component_candidate_submissions candidate JOIN public.projects project ON project.id = candidate.project_id JOIN public.project_boms bom ON bom.id = candidate.project_bom_id AND bom.project_id = project.id JOIN public.requirement_baselines baseline ON baseline.id = candidate.requirement_baseline_id AND baseline.id = project.requirement_baseline_id JOIN public.sales_project_handovers handover ON handover.id = candidate.sales_handover_id AND handover.project_id = project.id AND handover.baseline_id = baseline.id AND handover.status = 'completed' WHERE candidate.id = '$candidate_id'::uuid)) AS project_lineage) SELECT 'LOCAL_PREFLIGHT label=$label auth_uid=' || auth_uid || ' active_employee=' || active_employee || ' has_permission=' || has_permission || ' active_hardware_membership=' || active_hardware_membership || ' not_self_review=' || not_self_review || ' exact_revision=' || exact_revision || ' candidate_status=' || candidate_status || ' project_lineage=' || project_lineage || ' scope_rows=' || (SELECT count(*) FROM public.component_candidate_decision_scope((SELECT id FROM actor), '$candidate_id'::uuid, '$revision_id'::uuid)) FROM facts;")"
  printf '%s\n' "$preflight"
  [[ "$preflight" == *'active_employee=true has_permission=true active_hardware_membership=true not_self_review=true exact_revision=true '*' project_lineage=true scope_rows=1'* ]] || { echo "LOCAL_PREFLIGHT_FAIL $label authorization fixture is not valid" >&2; exit 1; }
}
waiter_name='bom_candidate_decision_revocation_waiter'
wait_for_locker_lock() {
  local lock_prefix="$1" lock_value="$2"
  for _ in $(seq 1 100); do
    local observed
    observed="$(run_psql -Atqc "WITH key AS (SELECT hashtextextended('$lock_prefix' || '$lock_value', 0) AS value) SELECT CASE WHEN EXISTS (SELECT 1 FROM pg_locks lock CROSS JOIN key WHERE lock.locktype = 'advisory' AND lock.granted AND lock.classid::bigint = ((key.value >> 32) & 4294967295) AND lock.objid::bigint = (key.value & 4294967295)) THEN 'locker-holds-exact-decision-lock' ELSE '' END")"
    [[ "$observed" == 'locker-holds-exact-decision-lock' ]] && return 0
    sleep 0.02
  done
  echo "LOCAL_CASE_FAIL locker did not hold exact decision advisory lock for $lock_prefix$lock_value" >&2
  return 1
}
wait_for_exact_lock() {
  local lock_prefix="$1" lock_value="$2"
  for _ in $(seq 1 100); do
    local observed
    observed="$(run_psql -Atqc "WITH key AS (SELECT hashtextextended('$lock_prefix' || '$lock_value', 0) AS value), waiter AS (SELECT pid FROM pg_stat_activity WHERE application_name = '$waiter_name' AND query LIKE '%decide_component_candidate%' ORDER BY query_start DESC LIMIT 1) SELECT CASE WHEN EXISTS (SELECT 1 FROM pg_stat_activity activity JOIN waiter ON waiter.pid = activity.pid JOIN pg_locks lock ON lock.pid = activity.pid CROSS JOIN key WHERE activity.wait_event_type = 'Lock' AND lock.locktype = 'advisory' AND NOT lock.granted AND lock.classid::bigint = ((key.value >> 32) & 4294967295) AND lock.objid::bigint = (key.value & 4294967295)) THEN 'waiting-on-exact-decision-lock' ELSE '' END")"
    [[ "$observed" == 'waiting-on-exact-decision-lock' ]] && return 0
    sleep 0.02
  done
  echo "LOCAL_CASE_FAIL waiter did not wait on exact decision advisory lock for $lock_prefix$lock_value" >&2
  return 1
}
graph_counts() { run_psql -Atqc "SELECT (SELECT status FROM public.component_candidate_submissions WHERE id = '$1'::uuid) || '/' || (SELECT count(*) FROM public.component_candidate_decisions WHERE candidate_id = '$1'::uuid)::text || '/' || (SELECT count(*) FROM public.component_candidate_submission_audit_events WHERE candidate_id = '$1'::uuid)::text || '/' || (SELECT count(*) FROM public.component_candidate_decision_request_receipts WHERE candidate_id = '$1'::uuid)::text"; }
run_case() {
  local label="$1" candidate_id="$2" revision_id="$3" request_key="$4" decision="$5" note="$6" lock_prefix="$7" lock_value="$8" revoke_sql="$9" before="${10}"
  psql "${psql_args[@]}" <<SQL >"$log_dir/$label-locker.out" 2>"$log_dir/$label-locker.err" & locker_pid=$!
BEGIN;
SELECT pg_advisory_xact_lock(hashtextextended('$lock_prefix' || '$lock_value', 0));
SELECT pg_sleep(3);
COMMIT;
SQL
  wait_for_locker_lock "$lock_prefix" "$lock_value"
  psql "${psql_args[@]}" --set=candidate_id="$candidate_id" --set=revision_id="$revision_id" --set=decision="$decision" --set=decision_note="$note" --set=request_key="$request_key" -f "$root/supabase/pending/tests/bom_candidate_decision_local_revocation_wait_worker.sql" >"$log_dir/$label-waiter.out" 2>"$log_dir/$label-waiter.err" & waiter_pid=$!
  wait_for_exact_lock "$lock_prefix" "$lock_value"
  run_psql -c "$revoke_sql" >/dev/null
  wait "$locker_pid"
  waiter_status=0; wait "$waiter_pid" || waiter_status=$?
  grep -Fq 'LOCAL_WORKER_PREWAIT auth_uid=30000000-0000-4000-8000-000000000002 has_permission=true active_hardware_membership=true scope_rows=1' "$log_dir/$label-waiter.out" || { cat "$log_dir/$label-waiter.out" "$log_dir/$label-waiter.err" >&2; echo "LOCAL_CASE_FAIL $label worker prewait authorization did not hold" >&2; exit 1; }
  [[ "$waiter_status" == '3' ]] || { cat "$log_dir/$label-waiter.err" >&2; exit 1; }
  grep -Fq 'ERROR:  Candidate decision requires active Hardware membership and engineering.approve authority' "$log_dir/$label-waiter.err" || { cat "$log_dir/$label-waiter.err" >&2; exit 1; }
  [[ "$(grep -Ec '^[0-9a-f-]{36}\|[0-9a-f-]{36}\|(t|f)$' "$log_dir/$label-waiter.out" || true)" == '0' ]] || { cat "$log_dir/$label-waiter.out" >&2; echo "LOCAL_CASE_FAIL $label returned a decision result after revocation" >&2; exit 1; }
  local after; after="$(graph_counts "$candidate_id")"
  [[ "$after" == "$before" ]] || { echo "LOCAL_CASE_FAIL $label changed candidate decision graph before=$before after=$after" >&2; exit 1; }
}

new_candidate="$(create_candidate 'REVOKED-DECISION-NEW' '30000000-0000-4000-8000-000000000090')"; new_revision="$(revision_for "$new_candidate")"; new_before="$(graph_counts "$new_candidate")"
assert_authorized_fixture "$new_candidate" "$new_revision" 'new'
run_case 'new' "$new_candidate" "$new_revision" '30000000-0000-4000-8000-000000000091' 'APPROVE' 'Revoked permission during wait' 'component-candidate-decision-request:' '30000000-0000-4000-8000-000000000091' "DELETE FROM public.access_role_permissions WHERE role_id = '30000000-0000-4000-8000-000000000028';" "$new_before"
[[ "$(graph_counts "$new_candidate")" == 'SUBMITTED/0/1/0' ]] || { echo 'LOCAL_CASE_FAIL revoked new decision graph was not unchanged' >&2; exit 1; }
run_psql -c "INSERT INTO public.access_role_permissions(role_id, permission_id) SELECT '30000000-0000-4000-8000-000000000028', id FROM public.permissions WHERE key = 'engineering.approve';" >/dev/null

replay_candidate="$(create_candidate 'REVOKED-DECISION-REPLAY' '30000000-0000-4000-8000-000000000092')"; replay_revision="$(revision_for "$replay_candidate")"
run_psql -Atqc "SELECT set_config('request.jwt.claim.sub', '30000000-0000-4000-8000-000000000002', false); SELECT * FROM public.decide_component_candidate('$replay_candidate'::uuid, '$replay_revision'::uuid, 'APPROVE', 'Authorized receipt before revocation', '30000000-0000-4000-8000-000000000093');" >/dev/null
replay_before="$(graph_counts "$replay_candidate")"
run_psql -c "INSERT INTO public.employee_departments(employee_id, department_id) SELECT '30000000-0000-4000-8000-000000000025', '30000000-0000-4000-8000-000000000014' WHERE NOT EXISTS (SELECT 1 FROM public.employee_departments WHERE employee_id = '30000000-0000-4000-8000-000000000025' AND department_id = '30000000-0000-4000-8000-000000000014');" >/dev/null
assert_authorized_fixture "$replay_candidate" "$replay_revision" 'replay'
run_case 'replay' "$replay_candidate" "$replay_revision" '30000000-0000-4000-8000-000000000093' 'APPROVE' 'Authorized receipt before revocation' 'component-candidate-decision-request:' '30000000-0000-4000-8000-000000000093' "DELETE FROM public.employee_departments WHERE employee_id = '30000000-0000-4000-8000-000000000025';" "$replay_before"
[[ "$(graph_counts "$replay_candidate")" == 'APPROVED_PENDING_PURCHASE/1/2/1' ]] || { echo 'LOCAL_CASE_FAIL revoked replay mutated terminal receipt history' >&2; exit 1; }
printf 'BOM_CANDIDATE_DECISION_LOCAL_REVOCATION_WAIT_PASS exact_decision_lock_verified=true new_decision_result_returned=false new_decision_graph_unchanged=true replay_result_returned=false replay_history_unchanged=true authority_revoked_before_unlock=true\n'
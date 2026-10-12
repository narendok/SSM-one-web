#!/usr/bin/env bash
set -euo pipefail
# LOCAL DISPOSABLE PostgreSQL ONLY. It never contacts a managed backend.
[[ "${LOCAL_PROJECT_BOM_PROCUREMENT_DISPOSABLE:-}" == "yes" ]] || { echo "Set LOCAL_PROJECT_BOM_PROCUREMENT_DISPOSABLE=yes to run a disposable fixture." >&2; exit 64; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
work_dir="$(mktemp -d /tmp/project_bom_procurement_concurrency_XXXXXX)"; data_dir="$work_dir/data"; socket_dir="$work_dir/socket"; database="project_bom_procurement_concurrency"; port=55479; server_pid=""
cleanup() { status=$?; if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi; rm -rf "$work_dir"; printf 'CLEANUP_VERIFIED project_bom_procurement_concurrency_fixture_removed=true\n'; exit "$status"; }
trap cleanup EXIT
[[ "$(id -u)" == "0" ]] || { echo "This disposable fixture requires sandbox root." >&2; exit 64; }
mkdir -p "$socket_dir"; chown -R 1000:1000 "$work_dir"
setpriv --reuid=1000 --regid=1000 --clear-groups initdb -D "$data_dir" --no-locale --encoding=UTF8 --auth-local=trust -U lovable >/dev/null
printf "listen_addresses=''\nport=%s\nunix_socket_directories='%s'\nshared_memory_type=mmap\ndynamic_shared_memory_type=mmap\n" "$port" "$socket_dir" >> "$data_dir/postgresql.conf"
setpriv --reuid=1000 --regid=1000 --clear-groups postgres -D "$data_dir" >/dev/null 2>&1 & server_pid=$!
for _ in $(seq 1 150); do psql --host="$socket_dir" --port="$port" --username=lovable --dbname=postgres -Atqc 'SELECT 1' >/dev/null 2>&1 && break; sleep 0.1; done
psql --host="$socket_dir" --port="$port" --username=lovable --dbname=postgres -Atqc 'SELECT 1' >/dev/null
createdb --host="$socket_dir" --port="$port" --username=lovable "$database"
psql_args=(--set=ON_ERROR_STOP=1 --host="$socket_dir" --port="$port" --username=lovable --dbname="$database")
psql "${psql_args[@]}" -f "$root/supabase/pending/tests/project_bom_procurement_review_local_fixture.sql" >/dev/null
psql "${psql_args[@]}" -f "$root/supabase/pending/20261012_project_bom_procurement_review_contract.sql" >/dev/null
q() { psql "${psql_args[@]}" -Atqc "$1"; }
assert_eq() { [[ "$1" == "$2" ]] || { echo "ASSERT_FAIL $3 expected=$2 actual=$1" >&2; exit 1; }; }

q "INSERT INTO public.employees VALUES ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','ACTIVE'),('00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000002','ACTIVE'); INSERT INTO public.departments VALUES ('00000000-0000-4000-8000-000000000010','PURCHASE',true); INSERT INTO public.employee_departments VALUES ('00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000010'); INSERT INTO public.projects VALUES ('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000001'); INSERT INTO public.project_team_members VALUES ('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000001'),('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000002'); INSERT INTO public.project_boms(id,project_id,bom_number,revision) VALUES ('00000000-0000-4000-8000-000000000030','00000000-0000-4000-8000-000000000020','BOM-CONCURRENCY','7'); INSERT INTO public.components VALUES ('00000000-0000-4000-8000-000000000040','CAT-001','Catalog Inc','Authoritative component'); INSERT INTO public.project_bom_items VALUES ('00000000-0000-4000-8000-000000000031','00000000-0000-4000-8000-000000000030',1,'00000000-0000-4000-8000-000000000040'); INSERT INTO public.permission_test_grants VALUES ('00000000-0000-4000-8000-000000000001','projects.manage'),('00000000-0000-4000-8000-000000000002','procurement.edit'); GRANT EXECUTE ON FUNCTION public.submit_project_bom_procurement_review(uuid,uuid,text,jsonb,uuid), public.analyze_project_bom_procurement_review(uuid,uuid,integer,jsonb,uuid), public.decide_project_bom_procurement_review(uuid,text,timestamptz,jsonb,text,text,uuid) TO procurement_requester_test, procurement_assigned_test;"

submit_request() { local request_key=$1; PGOPTIONS="-c role=procurement_requester_test -c request.jwt.claim.sub=00000000-0000-4000-8000-000000000001" psql "${psql_args[@]}" -Atqc "SELECT request_id FROM public.submit_project_bom_procurement_review('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000030','7','[{\"kind\":\"existing\",\"sourceBomItemId\":\"00000000-0000-4000-8000-000000000031\",\"componentId\":\"00000000-0000-4000-8000-000000000040\",\"referenceDesignators\":\"R1\",\"quantity\":1}]'::jsonb,'$request_key'::uuid);"; }
analyze() { local request=$1 line=$2 expected=$3 note=$4 key=$5; PGOPTIONS="-c role=procurement_assigned_test -c request.jwt.claim.sub=00000000-0000-4000-8000-000000000002" psql "${psql_args[@]}" -Atqc "SELECT analysis_revision FROM public.analyze_project_bom_procurement_review('$request'::uuid,'$line'::uuid,$expected,'{\"availabilityState\":\"AVAILABLE\",\"costState\":\"AVAILABLE\",\"sourcingState\":\"AVAILABLE\",\"observedUnitCost\":12.5,\"currency\":\"INR\",\"leadTimeDays\":7,\"analysisNote\":\"$note\"}'::jsonb,'$key'::uuid);"; }
decide_allow() { local request=$1 updated=$2 line=$3 revision=$4 key=$5; PGOPTIONS="-c role=procurement_assigned_test -c request.jwt.claim.sub=00000000-0000-4000-8000-000000000002" psql "${psql_args[@]}" -Atqc "SELECT replayed FROM public.decide_project_bom_procurement_review('$request'::uuid,'7','$updated'::timestamptz,jsonb_build_array(jsonb_build_object('requestLineId','$line'::uuid,'analysisRevision',$revision)),'ALLOW','Reviewed current commercial analysis','$key'::uuid);"; }

request_one="$(submit_request 00000000-0000-4000-8000-000000000101)"; line_one="$(q "SELECT id FROM public.project_bom_procurement_review_request_lines WHERE request_id='$request_one'")"; updated_one="$(q "SELECT pinned_bom_updated_at FROM public.project_bom_procurement_review_requests WHERE id='$request_one'")"; assert_eq "$(analyze "$request_one" "$line_one" 0 'Initial commercial analysis' 00000000-0000-4000-8000-000000000102)" 1 'initial analysis revision'
PGOPTIONS="-c role=procurement_assigned_test -c request.jwt.claim.sub=00000000-0000-4000-8000-000000000002" psql "${psql_args[@]}" -Atqc "BEGIN; SELECT * FROM public.analyze_project_bom_procurement_review('$request_one'::uuid,'$line_one'::uuid,1,'{\"availabilityState\":\"UNAVAILABLE\",\"costState\":\"UNAVAILABLE\",\"sourcingState\":\"UNAVAILABLE\",\"analysisNote\":\"Concurrent supplier withdrawal\"}'::jsonb,'00000000-0000-4000-8000-000000000103'::uuid); SELECT pg_sleep(1.2); COMMIT;" >"$work_dir/analyze.out" 2>"$work_dir/analyze.err" & analyze_pid=$!
sleep 0.2
allow_status=0; decide_allow "$request_one" "$updated_one" "$line_one" 1 00000000-0000-4000-8000-000000000104 >"$work_dir/allow.out" 2>"$work_dir/allow.err" || allow_status=$?
wait "$analyze_pid"
[[ $allow_status -ne 0 ]] || { echo 'ASSERT_FAIL analyze-vs-allow unexpectedly allowed stale analysis' >&2; exit 1; }
grep -q 'Reviewed Procurement analysis is missing or stale' "$work_dir/allow.err"
assert_eq "$(q "SELECT status FROM public.project_bom_procurement_review_requests WHERE id='$request_one'")" 'PENDING_PROCUREMENT_ANALYSIS' 'analyze-vs-allow leaves request pending'
assert_eq "$(q "SELECT count(*) FROM public.project_bom_procurement_review_receipts WHERE request_id='$request_one' AND action='ALLOW'")" 0 'analyze-vs-allow writes no allow receipt'
assert_eq "$(q "SELECT count(*) FROM public.project_bom_procurement_review_audit_events WHERE request_id='$request_one' AND event_type='ALLOWED_PENDING_HARDWARE_SELECTION'")" 0 'analyze-vs-allow writes no allow audit'
assert_eq "$(q "SELECT analysis_revision FROM public.project_bom_procurement_review_analyses WHERE request_line_id='$line_one' ORDER BY analysis_revision DESC LIMIT 1")" 2 'concurrent analysis becomes immutable current revision'
printf 'ANALYZE_VS_ALLOW_STALE_PIN_PASS=true\n'

request_two="$(submit_request 00000000-0000-4000-8000-000000000105)"; line_two="$(q "SELECT id FROM public.project_bom_procurement_review_request_lines WHERE request_id='$request_two'")"; updated_two="$(q "SELECT pinned_bom_updated_at FROM public.project_bom_procurement_review_requests WHERE id='$request_two'")"; assert_eq "$(analyze "$request_two" "$line_two" 0 'Manual-edit comparison analysis' 00000000-0000-4000-8000-000000000106)" 1 'manual-edit initial analysis revision'
q "UPDATE public.project_boms SET updated_at=clock_timestamp() + interval '1 microsecond' WHERE id='00000000-0000-4000-8000-000000000030';"
bom_status=0; decide_allow "$request_two" "$updated_two" "$line_two" 1 00000000-0000-4000-8000-000000000107 >"$work_dir/manual-edit.out" 2>"$work_dir/manual-edit.err" || bom_status=$?
[[ $bom_status -ne 0 ]] || { echo 'ASSERT_FAIL same-revision manual BOM edit unexpectedly allowed stale decision' >&2; exit 1; }
grep -q 'The project BOM source is stale' "$work_dir/manual-edit.err"
assert_eq "$(q "SELECT revision FROM public.project_boms WHERE id='00000000-0000-4000-8000-000000000030'")" 7 'same-revision manual edit preserves BOM revision'
assert_eq "$(q "SELECT status FROM public.project_bom_procurement_review_requests WHERE id='$request_two'")" 'PENDING_PROCUREMENT_ANALYSIS' 'manual BOM edit leaves request pending'
assert_eq "$(q "SELECT count(*) FROM public.project_bom_procurement_review_receipts WHERE request_id='$request_two' AND action='ALLOW'")" 0 'manual BOM edit writes no allow receipt'
assert_eq "$(q "SELECT count(*) FROM public.project_bom_procurement_review_audit_events WHERE request_id='$request_two' AND event_type='ALLOWED_PENDING_HARDWARE_SELECTION'")" 0 'manual BOM edit writes no allow audit'
printf 'SAME_REVISION_BOM_MANUAL_EDIT_STALE_DECISION_PASS=true\n'

request_three="$(submit_request 00000000-0000-4000-8000-000000000108)"; line_three="$(q "SELECT id FROM public.project_bom_procurement_review_request_lines WHERE request_id='$request_three'")"; assert_eq "$(analyze "$request_three" "$line_three" 0 'Refreshed caller-pin comparison analysis' 00000000-0000-4000-8000-000000000109)" 1 'refreshed caller pin initial analysis revision'
q "UPDATE public.project_boms SET updated_at=clock_timestamp() + interval '1 microsecond' WHERE id='00000000-0000-4000-8000-000000000030';"
refreshed_updated_three="$(q "SELECT updated_at FROM public.project_boms WHERE id='00000000-0000-4000-8000-000000000030'")"
refreshed_status=0; decide_allow "$request_three" "$refreshed_updated_three" "$line_three" 1 00000000-0000-4000-8000-000000000110 >"$work_dir/refreshed-pin.out" 2>"$work_dir/refreshed-pin.err" || refreshed_status=$?
[[ $refreshed_status -ne 0 ]] || { echo 'ASSERT_FAIL refreshed caller timestamp unexpectedly allowed stale submitted BOM snapshot' >&2; exit 1; }
grep -q 'The project BOM source is stale' "$work_dir/refreshed-pin.err"
assert_eq "$(q "SELECT status FROM public.project_bom_procurement_review_requests WHERE id='$request_three'")" 'PENDING_PROCUREMENT_ANALYSIS' 'refreshed caller timestamp leaves request pending'
assert_eq "$(q "SELECT count(*) FROM public.project_bom_procurement_review_receipts WHERE request_id='$request_three' AND action='ALLOW'")" 0 'refreshed caller timestamp writes no allow receipt'
assert_eq "$(q "SELECT count(*) FROM public.project_bom_procurement_review_audit_events WHERE request_id='$request_three' AND event_type='ALLOWED_PENDING_HARDWARE_SELECTION'")" 0 'refreshed caller timestamp writes no allow audit'
printf 'REFRESHED_CALLER_TIMESTAMP_OLD_REQUEST_STALE_PASS=true\n'
printf 'PROJECT_BOM_PROCUREMENT_REVIEW_LOCAL_CONCURRENCY_ACCEPTANCE_PASS=true\n'
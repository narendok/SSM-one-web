#!/usr/bin/env bash
set -euo pipefail

# LOCAL DISPOSABLE POSTGRESQL ONLY. This coordinated two-session acceptance
# never contacts a managed, preview, shared, production, or remote database.
# It installs the source-only proposal into a fresh fixture solely for local
# behavioral evidence. The pending proposal continues to revoke its transport.
#
# Usage mirrors run_sales_atomic_intake_local_acceptance.sh. The supplied URL
# must name a fresh local database, and LOCAL_SALES_INTAKE_DISPOSABLE=yes is
# required. The two workers are synchronized by database advisory barriers;
# no timing sleep is used to assume a race.

: "${LOCAL_SALES_INTAKE_ACCEPTANCE_DATABASE_URL:?Set a local disposable PostgreSQL URL.}"
: "${LOCAL_SALES_INTAKE_DISPOSABLE:?Set LOCAL_SALES_INTAKE_DISPOSABLE=yes for a disposable database.}"
if [[ "$LOCAL_SALES_INTAKE_DISPOSABLE" != "yes" ]]; then
  echo "Refusing to run without LOCAL_SALES_INTAKE_DISPOSABLE=yes." >&2
  exit 64
fi

node --input-type=module - "$LOCAL_SALES_INTAKE_ACCEPTANCE_DATABASE_URL" <<'NODE'
const parsed = new URL(process.argv[2])
const decodedHost = decodeURIComponent(parsed.hostname)
const privateSocketRoot = process.env.LOCAL_SALES_INTAKE_PRIVATE_SOCKET_ROOT
const isLoopback = /^(localhost|127\.0\.0\.1|\[::1\])$/.test(parsed.hostname)
const isPrivateSocket = Boolean(privateSocketRoot)
  && decodedHost.startsWith(`${privateSocketRoot}/`)
  && !decodedHost.includes('..')
  && decodedHost.startsWith('/tmp/sales_atomic_acceptance_')
if (!['postgresql:', 'postgres:'].includes(parsed.protocol) || !(isLoopback || isPrivateSocket)) {
  throw new Error('Refusing a non-local PostgreSQL target.')
}
if ((isLoopback && parsed.port && !/^(5432|55432)$/.test(parsed.port)) || parsed.search || parsed.hash) {
  throw new Error('Connection options are not accepted by the local runner.')
}
if (!/^\/sales_atomic_acceptance_[a-z0-9_]+$/i.test(parsed.pathname)) {
  throw new Error('The local database name must start with sales_atomic_acceptance_.')
}
NODE

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fixture="$root/supabase/pending/tests/sales_atomic_intake_replay_local_fixture.sql"
proposal="$root/supabase/pending/20261010_sales_atomic_intake_replay.sql"
setup="$root/supabase/pending/tests/sales_atomic_intake_replay_local_race_setup.sql"
worker="$root/supabase/pending/tests/sales_atomic_intake_replay_local_race_worker.sql"
assertions="$root/supabase/pending/tests/sales_atomic_intake_replay_local_race_assertions.sql"
lock_setup="$root/supabase/pending/tests/sales_atomic_intake_replay_local_lock_setup.sql"
lock_worker="$root/supabase/pending/tests/sales_atomic_intake_replay_local_lock_worker.sql"
lock_assertions="$root/supabase/pending/tests/sales_atomic_intake_replay_local_lock_assertions.sql"
failpoints="$root/supabase/pending/tests/sales_atomic_intake_replay_local_failpoint_acceptance.sql"

psql_args=(--set=ON_ERROR_STOP=1)
if [[ -n "${LOCAL_SALES_INTAKE_PRIVATE_SOCKET_ROOT:-}" ]]; then
  socket_host="$(node --input-type=module - "$LOCAL_SALES_INTAKE_ACCEPTANCE_DATABASE_URL" <<'NODE'
const parsed = new URL(process.argv[2])
console.log(decodeURIComponent(parsed.hostname))
NODE
)"
  database_name="$(node --input-type=module - "$LOCAL_SALES_INTAKE_ACCEPTANCE_DATABASE_URL" <<'NODE'
const parsed = new URL(process.argv[2])
console.log(parsed.pathname.slice(1))
NODE
)"
  psql_args+=(--host="$socket_host" --port="${LOCAL_SALES_INTAKE_PRIVATE_SOCKET_PORT:-55432}" --username="${LOCAL_SALES_INTAKE_PRIVATE_SOCKET_USER:-sales_atomic_local}" --dbname="$database_name")
else
  psql_args+=("$LOCAL_SALES_INTAKE_ACCEPTANCE_DATABASE_URL")
fi

run_psql() { psql "${psql_args[@]}" "$@"; }
run_psql -f "$fixture"
run_psql -f "$proposal"
# Fixture-only transport; intentionally absent from the proposal.
run_psql <<'SQL'
GRANT EXECUTE ON FUNCTION public.create_sales_opportunity_with_initial_master_specification(uuid, uuid, uuid, jsonb, uuid) TO authenticated;
SQL
run_psql -f "$setup"

run_psql -f "$failpoints"
# Recreate fixture state for revocation-after-lock-wait cases and preserve race coverage.
run_psql -f "$fixture"
run_psql -f "$proposal"
run_psql <<'SQL'
GRANT EXECUTE ON FUNCTION public.create_sales_opportunity_with_initial_master_specification(uuid, uuid, uuid, jsonb, uuid) TO authenticated;
SQL
run_psql -f "$lock_setup"

run_race() {
  local label="$1" key_a="$2" key_b="$3" payload_a="$4" payload_b="$5" actor_a="$6" actor_b="$7"
  local log_dir
  log_dir="$(mktemp -d /tmp/sales_atomic_acceptance_race_XXXXXX)"
  cleanup_logs() { rm -rf "$log_dir"; }
  trap cleanup_logs RETURN
  timeout 20s psql "${psql_args[@]}" -v race_label="$label" -v worker_label=a -v request_key="$key_a" -v payload_variant="$payload_a" -v actor_id="$actor_a" -f "$worker" >"$log_dir/a.log" 2>&1 &
  local pid_a=$!
  timeout 20s psql "${psql_args[@]}" -v race_label="$label" -v worker_label=b -v request_key="$key_b" -v payload_variant="$payload_b" -v actor_id="$actor_b" -f "$worker" >"$log_dir/b.log" 2>&1 &
  local pid_b=$!
  local status_a status_b
  wait "$pid_a" && status_a=0 || status_a=$?
  wait "$pid_b" && status_b=0 || status_b=$?
  printf 'RACE_WORKER_STATUS label=%s a=%s b=%s\n' "$label" "$status_a" "$status_b"
  case "$label" in
    same_key_same_payload|different_keys)
      [[ "$status_a" == 0 && "$status_b" == 0 ]] || { cat "$log_dir/a.log" "$log_dir/b.log" >&2; return 1; }
      ;;
    same_key_changed_payload|same_key_actor_conflict)
      [[ "$status_a" != 0 && "$status_b" == 0 || "$status_a" == 0 && "$status_b" != 0 ]] || { cat "$log_dir/a.log" "$log_dir/b.log" >&2; return 1; }
      ;;
  esac
}

run_lock_wait_case() {
  local label="$1" key="$2" log_dir status
  log_dir="$(mktemp -d /tmp/sales_atomic_acceptance_lock_XXXXXX)"
  timeout 20s psql "${psql_args[@]}" -v case_label="$label" -v request_key="$key" -f "$lock_worker" >"$log_dir/worker.log" 2>&1 &
  local pid=$!
  for attempt in $(seq 1 150); do
    if [[ "$(run_psql -Atqc "SELECT ready::text || ':' || released::text FROM public.sales_intake_lock_wait_cases WHERE case_label = '$label'")" == "true:false" ]]; then break; fi
    sleep 0.1
  done
  [[ "$(run_psql -Atqc "SELECT ready::text || ':' || released::text FROM public.sales_intake_lock_wait_cases WHERE case_label = '$label'")" == "true:false" ]] || { cat "$log_dir/worker.log" >&2; return 1; }
  printf 'LOCK_WAIT_DEMONSTRATED case=%s
' "$label"
  run_psql -v case_label="$label" -v phase=release -f "$lock_assertions"
  wait "$pid" && status=0 || status=$?
  printf 'LOCK_WAIT_WORKER_STATUS case=%s status=%s
' "$label" "$status"
  [[ "$status" != 0 ]] || { cat "$log_dir/worker.log" >&2; return 1; }
  [[ "$(run_psql -Atqc "SELECT count(*) FROM public.sales_opportunity_intake_receipts WHERE request_key = '$key'")" == "0" ]] || return 1
  [[ "$(run_psql -Atqc "SELECT count(*) FROM public.sales_opportunities")" == "0" ]] || return 1
  printf 'LOCK_WAIT_DENIAL_PASS case=%s receipts=0 opportunities=0
' "$label"
  rm -rf "$log_dir"
}

run_lock_wait_case new_request 00000000-0000-4000-8000-000000000201
-- Seed an authorized exact-replay receipt, then reset the caller permission before lock wait.
run_psql <<'SQL'
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', false);
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT * FROM public.create_sales_opportunity_with_initial_master_specification(
  '00000000-0000-4000-8000-000000000010'::uuid, '00000000-0000-4000-8000-000000000011'::uuid, '00000000-0000-4000-8000-000000000012'::uuid,
  '{"name":"Lock wait intake","application":"Vehicle tracking","productType":"Tracker","primarySalesOwnerUserId":null,"ndaRequired":false,"estimatedVolume":"20","targetTimeline":"Q4","priority":"medium","nextAction":"Review","nextActionDate":null,"masterSpecification":{"changeSummary":"Initial intake","proposedName":"Lock wait intake","customerOrInternalOwner":"Disposable customer","industryApplication":"Automotive","productFamily":"Tracker","developmentScope":"Prototype scope","workstreams":["HARDWARE"],"requirementSummary":"Track test vehicles","powerAndUnits":"12V","interfaces":"CAN","connectivityAndGnss":"LTE/GNSS","environmentAndIp":"IP67","volumes":"20","schedule":"Q4","requestedStandards":"TBC","exclusions":"None"}}'::jsonb,
  '00000000-0000-4000-8000-000000000202'::uuid
);
UPDATE public.sales_test_permissions SET sales_manage = true WHERE user_id = '00000000-0000-4000-8000-000000000001';
SQL
run_lock_wait_case receipt_replay 00000000-0000-4000-8000-000000000202

-- Restore a clean fixture before the pre-existing exact replay/conflict/different-key race suite.
run_psql -f "$fixture"
run_psql -f "$proposal"
run_psql <<'SQL'
GRANT EXECUTE ON FUNCTION public.create_sales_opportunity_with_initial_master_specification(uuid, uuid, uuid, jsonb, uuid) TO authenticated;
SQL
run_psql -f "$setup"

# Each pair waits on the same server-side barrier. The assertion transaction
# releases it only after both independent sessions have registered readiness.
run_race same_key_same_payload 00000000-0000-4000-8000-000000000101 00000000-0000-4000-8000-000000000101 base base 00000000-0000-4000-8000-000000000001 00000000-0000-4000-8000-000000000001 &
race_pid=$!
for attempt in $(seq 1 150); do
  if [[ "$(run_psql -Atqc "SELECT ready_workers FROM public.sales_intake_race_barriers WHERE race_label = 'same_key_same_payload'")" == "2" ]]; then break; fi
  sleep 0.1
done
run_psql -v race_label=same_key_same_payload -v release_only=yes -f "$assertions"
wait "$race_pid"
run_psql -v race_label=same_key_same_payload -v release_only=no -f "$assertions"

run_race same_key_changed_payload 00000000-0000-4000-8000-000000000102 00000000-0000-4000-8000-000000000102 base changed 00000000-0000-4000-8000-000000000001 00000000-0000-4000-8000-000000000001 &
race_pid=$!
for attempt in $(seq 1 150); do
  if [[ "$(run_psql -Atqc "SELECT ready_workers FROM public.sales_intake_race_barriers WHERE race_label = 'same_key_changed_payload'")" == "2" ]]; then break; fi
  sleep 0.1
done
run_psql -v race_label=same_key_changed_payload -v release_only=yes -f "$assertions"
wait "$race_pid"
run_psql -v race_label=same_key_changed_payload -v release_only=no -f "$assertions"

run_race same_key_actor_conflict 00000000-0000-4000-8000-000000000103 00000000-0000-4000-8000-000000000103 base base 00000000-0000-4000-8000-000000000001 00000000-0000-4000-8000-000000000002 &
race_pid=$!
for attempt in $(seq 1 150); do
  if [[ "$(run_psql -Atqc "SELECT ready_workers FROM public.sales_intake_race_barriers WHERE race_label = 'same_key_actor_conflict'")" == "2" ]]; then break; fi
  sleep 0.1
done
run_psql -v race_label=same_key_actor_conflict -v release_only=yes -f "$assertions"
wait "$race_pid"
run_psql -v race_label=same_key_actor_conflict -v release_only=no -f "$assertions"

run_race different_keys 00000000-0000-4000-8000-000000000104 00000000-0000-4000-8000-000000000105 base alternate 00000000-0000-4000-8000-000000000001 00000000-0000-4000-8000-000000000001 &
race_pid=$!
for attempt in $(seq 1 150); do
  if [[ "$(run_psql -Atqc "SELECT ready_workers FROM public.sales_intake_race_barriers WHERE race_label = 'different_keys'")" == "2" ]]; then break; fi
  sleep 0.1
done
run_psql -v race_label=different_keys -v release_only=yes -f "$assertions"
wait "$race_pid"
run_psql -v race_label=different_keys -v release_only=no -f "$assertions"

run_psql -v race_label=final -v release_only=no -f "$assertions"
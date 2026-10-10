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

run_race() {
  local label="$1" key_a="$2" key_b="$3" payload_a="$4" payload_b="$5" actor_a="$6" actor_b="$7"
  local log_dir
  log_dir="$(mktemp -d /tmp/sales_atomic_acceptance_race_XXXXXX)"
  cleanup_logs() { rm -rf "$log_dir"; }
  trap cleanup_logs RETURN
  timeout 20s psql "${psql_args[@]}" -v race_label="$label" -v request_key="$key_a" -v payload_variant="$payload_a" -v actor_id="$actor_a" -f "$worker" >"$log_dir/a.log" 2>&1 &
  local pid_a=$!
  timeout 20s psql "${psql_args[@]}" -v race_label="$label" -v request_key="$key_b" -v payload_variant="$payload_b" -v actor_id="$actor_b" -f "$worker" >"$log_dir/b.log" 2>&1 &
  local pid_b=$!
  if ! wait "$pid_a" || ! wait "$pid_b"; then
    cat "$log_dir/a.log" "$log_dir/b.log" >&2
    return 1
  fi
}

# Each pair waits on the same server-side barrier. The assertion transaction
# releases it only after both independent sessions have registered readiness.
run_race same_key_same_payload 00000000-0000-4000-8000-000000000101 00000000-0000-4000-8000-000000000101 base base 00000000-0000-4000-8000-000000000001 00000000-0000-4000-8000-000000000001 &
race_pid=$!
run_psql -v race_label=same_key_same_payload -f "$assertions"
wait "$race_pid"

run_race same_key_changed_payload 00000000-0000-4000-8000-000000000102 00000000-0000-4000-8000-000000000102 base changed 00000000-0000-4000-8000-000000000001 00000000-0000-4000-8000-000000000001 &
race_pid=$!
run_psql -v race_label=same_key_changed_payload -f "$assertions"
wait "$race_pid"

run_race same_key_actor_conflict 00000000-0000-4000-8000-000000000103 00000000-0000-4000-8000-000000000103 base base 00000000-0000-4000-8000-000000000001 00000000-0000-4000-8000-000000000002 &
race_pid=$!
run_psql -v race_label=same_key_actor_conflict -f "$assertions"
wait "$race_pid"

run_race different_keys 00000000-0000-4000-8000-000000000104 00000000-0000-4000-8000-000000000105 base alternate 00000000-0000-4000-8000-000000000001 00000000-0000-4000-8000-000000000001 &
race_pid=$!
run_psql -v race_label=different_keys -f "$assertions"
wait "$race_pid"

run_psql -v race_label=final -f "$assertions"
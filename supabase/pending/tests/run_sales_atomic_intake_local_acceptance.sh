#!/usr/bin/env bash
set -euo pipefail

# LOCAL DISPOSABLE POSTGRESQL ONLY. This runner refuses managed, preview,
# shared, production, and remote targets before invoking psql. It is a source
# acceptance aid; it never contacts a backend unless an operator explicitly
# supplies a local loopback database URL.
#
# Usage:
#   LOCAL_SALES_INTAKE_ACCEPTANCE_DATABASE_URL=postgresql://.../sales_atomic_acceptance_demo \
#   LOCAL_SALES_INTAKE_DISPOSABLE=yes \
#   bash supabase/pending/tests/run_sales_atomic_intake_local_acceptance.sh preinstall
#
# `installed` recreates only the supplied disposable local test schema, loads
# the pending proposal into it, and grants EXECUTE solely to the local fixture
# role so behavioral cases can run. The pending proposal itself remains revoked.

mode="${1:-}"
if [[ "$mode" != "preinstall" && "$mode" != "installed" ]]; then
  echo "Usage: $0 <preinstall|installed>" >&2
  exit 64
fi

: "${LOCAL_SALES_INTAKE_ACCEPTANCE_DATABASE_URL:?Set a local disposable PostgreSQL URL.}"
: "${LOCAL_SALES_INTAKE_DISPOSABLE:?Set LOCAL_SALES_INTAKE_DISPOSABLE=yes for a disposable database.}"
if [[ "$LOCAL_SALES_INTAKE_DISPOSABLE" != "yes" ]]; then
  echo "Refusing to run without LOCAL_SALES_INTAKE_DISPOSABLE=yes." >&2
  exit 64
fi

LOCALHOST_ONLY_HOSTS='^(localhost|127\.0\.0\.1|\[::1\])$'
node --input-type=module - "$LOCAL_SALES_INTAKE_ACCEPTANCE_DATABASE_URL" "$LOCALHOST_ONLY_HOSTS" <<'NODE'
const [url, hostPattern] = process.argv.slice(2)
let parsed
try { parsed = new URL(url) } catch { throw new Error('The local acceptance URL is invalid.') }
if (!['postgresql:', 'postgres:'].includes(parsed.protocol) || !new RegExp(hostPattern).test(parsed.hostname)) {
  throw new Error('Refusing a non-local PostgreSQL target.')
}
if (!/^\/sales_atomic_acceptance_[a-z0-9_]+$/i.test(parsed.pathname)) {
  throw new Error('The local database name must start with sales_atomic_acceptance_.')
}
NODE

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fixture="$root/supabase/pending/tests/sales_atomic_intake_replay_local_fixture.sql"
proposal="$root/supabase/pending/20261010_sales_atomic_intake_replay.sql"
preinstall="$root/supabase/pending/tests/sales_atomic_intake_replay_local_preinstall.sql"
acceptance="$root/supabase/pending/tests/sales_atomic_intake_replay_local_installed_acceptance.sql"

if [[ "$mode" == "preinstall" ]]; then
  psql "$LOCAL_SALES_INTAKE_ACCEPTANCE_DATABASE_URL" --set=ON_ERROR_STOP=1 -f "$preinstall"
  exit 0
fi

psql "$LOCAL_SALES_INTAKE_ACCEPTANCE_DATABASE_URL" --set=ON_ERROR_STOP=1 -f "$fixture"
psql "$LOCAL_SALES_INTAKE_ACCEPTANCE_DATABASE_URL" --set=ON_ERROR_STOP=1 -f "$proposal"
# This grant is local disposable fixture only; it is intentionally absent from
# the pending proposal and must not be copied into a reviewed deployment.
psql "$LOCAL_SALES_INTAKE_ACCEPTANCE_DATABASE_URL" --set=ON_ERROR_STOP=1 <<'SQL'
GRANT EXECUTE ON FUNCTION public.create_sales_opportunity_with_initial_master_specification(uuid, uuid, uuid, jsonb, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.lookup_sales_opportunity_intake_receipt(uuid) TO authenticated;
SQL
psql "$LOCAL_SALES_INTAKE_ACCEPTANCE_DATABASE_URL" --set=ON_ERROR_STOP=1 -f "$acceptance"
#!/usr/bin/env bash
set -euo pipefail

# LOCAL DISPOSABLE POSTGRESQL ONLY. Refuses every remote or managed target.
: "${LOCAL_STRUCTURED_DRAFT_ACCEPTANCE_DATABASE_URL:?Set a local disposable PostgreSQL URL.}"
: "${LOCAL_STRUCTURED_DRAFT_ACCEPTANCE_DISPOSABLE:?Set LOCAL_STRUCTURED_DRAFT_ACCEPTANCE_DISPOSABLE=yes.}"
[[ "$LOCAL_STRUCTURED_DRAFT_ACCEPTANCE_DISPOSABLE" == "yes" ]] || { echo "Refusing without disposable acknowledgement." >&2; exit 64; }

node --input-type=module - "$LOCAL_STRUCTURED_DRAFT_ACCEPTANCE_DATABASE_URL" <<'NODE'
const parsed = new URL(process.argv[2]); const host = decodeURIComponent(parsed.hostname); const root = process.env.LOCAL_STRUCTURED_DRAFT_PRIVATE_SOCKET_ROOT;
if (!['postgres:', 'postgresql:'].includes(parsed.protocol) || !root || !host.startsWith(`${root}/`) || host.includes('..') || !host.startsWith('/tmp/structured_draft_acceptance_') || !/^\/structured_draft_acceptance_[a-z0-9_]+$/i.test(parsed.pathname) || parsed.search || parsed.hash) throw new Error('Refusing a non-private local structured-draft acceptance target.');
NODE

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
host="$(node --input-type=module - "$LOCAL_STRUCTURED_DRAFT_ACCEPTANCE_DATABASE_URL" <<'NODE'
console.log(decodeURIComponent(new URL(process.argv[2]).hostname))
NODE
)"
database="$(node --input-type=module - "$LOCAL_STRUCTURED_DRAFT_ACCEPTANCE_DATABASE_URL" <<'NODE'
console.log(new URL(process.argv[2]).pathname.slice(1))
NODE
)"
psql_args=(--set=ON_ERROR_STOP=1 --host="$host" --port="${LOCAL_STRUCTURED_DRAFT_PRIVATE_SOCKET_PORT:-55433}" --username="${LOCAL_STRUCTURED_DRAFT_PRIVATE_SOCKET_USER:-structured_draft_local}" --dbname="$database")
psql "${psql_args[@]}" -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_fixture.sql"
psql "${psql_args[@]}" -f "$root/supabase/pending/20261009_sales_opportunity_structured_draft_metadata.sql"
# Fixture-only transport, deliberately absent from the pending proposal.
psql "${psql_args[@]}" -c "GRANT EXECUTE ON FUNCTION public.save_sales_opportunity_structured_draft_revision(uuid, uuid, uuid, uuid, text, integer, jsonb, uuid) TO authenticated;"
psql "${psql_args[@]}" -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_installed_acceptance.sql"
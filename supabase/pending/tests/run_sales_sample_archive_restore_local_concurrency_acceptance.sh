#!/usr/bin/env bash
set -euo pipefail
# LOCAL DISPOSABLE PostgreSQL ONLY. It never contacts a managed backend.
[[ "${LOCAL_SALES_SAMPLE_ARCHIVE_DISPOSABLE:-}" == "yes" ]] || { echo "Set LOCAL_SALES_SAMPLE_ARCHIVE_DISPOSABLE=yes to run a disposable fixture." >&2; exit 64; }
[[ "$(id -u)" == "0" ]] || { echo "This disposable fixture requires sandbox root." >&2; exit 64; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; work_dir="$(mktemp -d /tmp/sales_sample_archive_concurrency_XXXXXX)"; data_dir="$work_dir/data"; socket_dir="$work_dir/socket"; database="sales_archive_concurrency"; port=55463; server_pid=""
cleanup() { status=$?; if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi; rm -rf "$work_dir"; printf 'CLEANUP_VERIFIED sales_sample_archive_concurrency_fixture_removed=true\n'; exit "$status"; }
trap cleanup EXIT
mkdir -p "$socket_dir"; chown -R 1000:1000 "$work_dir"
setpriv --reuid=1000 --regid=1000 --clear-groups initdb -D "$data_dir" --no-locale --encoding=UTF8 --auth-local=trust -U lovable >/dev/null
printf "listen_addresses=''\nport=%s\nunix_socket_directories='%s'\nshared_memory_type=mmap\ndynamic_shared_memory_type=mmap\n" "$port" "$socket_dir" >> "$data_dir/postgresql.conf"
setpriv --reuid=1000 --regid=1000 --clear-groups postgres -D "$data_dir" >/dev/null 2>&1 & server_pid=$!
for _ in $(seq 1 150); do psql --host="$socket_dir" --port="$port" --username=lovable --dbname=postgres -Atqc 'SELECT 1' >/dev/null 2>&1 && break; sleep 0.1; done
psql --host="$socket_dir" --port="$port" --username=lovable --dbname=postgres -Atqc 'SELECT 1' >/dev/null
createdb --host="$socket_dir" --port="$port" --username=lovable "$database"
psql_args=(--set=ON_ERROR_STOP=1 --host="$socket_dir" --port="$port" --username=lovable --dbname="$database")
psql "${psql_args[@]}" -f "$root/supabase/pending/tests/sales_sample_archive_restore_local_fixture.sql" >/dev/null
psql "${psql_args[@]}" -f "$root/supabase/pending/20261012_sales_sample_archive_restore_contract.sql" >/dev/null
q() { psql "${psql_args[@]}" -Atqc "$1"; }
assert_eq() { [[ "$1" == "$2" ]] || { echo "ASSERT_FAIL $3 expected=$2 actual=$1" >&2; exit 1; }; }
roots='[{"kind":"OPPORTUNITY","id":"104fb9e2-7f83-40f9-a295-64b37aa8c7ee","displayNumber":"OPPORTUNITY-2026-0006"},{"kind":"OPPORTUNITY","id":"becebb23-e0f2-4264-a78f-fda04275cade","displayNumber":"OPPORTUNITY-2026-0007"},{"kind":"OPPORTUNITY","id":"428d7d9e-25bf-4e98-94d5-416ea56155e3","displayNumber":"OPPORTUNITY-2026-0008"},{"kind":"OPPORTUNITY","id":"dc101dd9-89a2-4dad-9903-3b2301a97d3b","displayNumber":"OPPORTUNITY-2026-0009"},{"kind":"OPPORTUNITY","id":"d79f58c1-bbee-4940-9e67-88f267f5449b","displayNumber":"OPPORTUNITY-2026-0010"},{"kind":"REQUIREMENT","id":"aaabd18c-5885-45de-9e0e-da70d4ec491f","displayNumber":"CUSTOMER-2026-0003"},{"kind":"REQUIREMENT","id":"36cdc159-57c7-4568-a1b0-ec481f5d3d93","displayNumber":"CUSTOMER-2026-0004"},{"kind":"REQUIREMENT","id":"6aa2fc2f-eb75-48c2-a9de-d13008cf1c5c","displayNumber":"CUSTOMER-2026-0005"},{"kind":"REQUIREMENT","id":"2db48440-5424-4e5e-bb5b-01f203a7662f","displayNumber":"CUSTOMER-2026-0006"},{"kind":"REQUIREMENT","id":"e829dd82-381d-42ab-a808-62979e9156f4","displayNumber":"CUSTOMER-2026-0007"}]'
q "INSERT INTO public.permission_test_grants VALUES ('00000000-0000-4000-8000-000000000001','sales.manage');"

# The writer uses the same archive advisory key. A future downstream writer must
# take this established root lock before a linked record can be committed.
PGOPTIONS="-c request.jwt.claim.sub=00000000-0000-4000-8000-000000000001" psql "${psql_args[@]}" -Atqc "BEGIN; SELECT pg_advisory_xact_lock(hashtextextended('reviewed-sales-sample-archive',0)); SELECT pg_sleep(1.1); INSERT INTO public.sales_opportunity_structured_docx_assignments(id,opportunity_id) VALUES ('00000000-0000-4000-8000-000000000031','104fb9e2-7f83-40f9-a295-64b37aa8c7ee'); COMMIT;" >"$work_dir/writer.out" 2>"$work_dir/writer.err" & writer_pid=$!
sleep 0.2
archive_status=0
PGOPTIONS="-c request.jwt.claim.sub=00000000-0000-4000-8000-000000000001" psql "${psql_args[@]}" -Atqc "SELECT * FROM public.archive_reviewed_sales_samples('$roots'::jsonb,'concurrent downstream writer','00000000-0000-4000-8000-000000000032');" >"$work_dir/archive.out" 2>"$work_dir/archive.err" || archive_status=$?
wait "$writer_pid"
[[ $archive_status -ne 0 ]] || { echo 'ASSERT_FAIL downstream writer race unexpectedly archived roots' >&2; exit 1; }
grep -q 'Archived opportunity is missing, changed, or already archived\|Archive is blocked by a live business dependency' "$work_dir/archive.err"
assert_eq "$(q "SELECT count(*) FROM public.sales_opportunities WHERE archived_at IS NOT NULL")" 0 'writer race leaves opportunity roots active'
assert_eq "$(q "SELECT count(*) FROM public.customer_requirements WHERE archived_at IS NOT NULL")" 0 'writer race leaves requirement roots active'
assert_eq "$(q "SELECT count(*) FROM public.sales_sample_archive_manifests")" 0 'writer race rolls back manifest'
assert_eq "$(q "SELECT count(*) FROM public.sales_sample_archive_manifest_items")" 0 'writer race rolls back manifest items'
assert_eq "$(q "SELECT count(*) FROM public.sales_sample_archive_audit_events")" 0 'writer race writes no audit'
assert_eq "$(q "SELECT count(*) FROM public.sales_opportunity_structured_docx_assignments WHERE id='00000000-0000-4000-8000-000000000031'")" 1 'writer committed a new downstream lineage record'
printf 'DOWNSTREAM_WRITER_VS_ARCHIVE_ATOMIC_REJECT_PASS=true\n'
printf 'SALES_SAMPLE_ARCHIVE_RESTORE_LOCAL_CONCURRENCY_ACCEPTANCE_PASS=true\n'
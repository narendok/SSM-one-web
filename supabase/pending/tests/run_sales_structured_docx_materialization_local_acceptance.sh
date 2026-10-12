#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"; work_dir="$(mktemp -d /tmp/sales_structured_docx_XXXXXX)"; data_dir="$work_dir/data"; socket_dir="$work_dir/socket"; database="sales_structured_docx"; port=55474; server_pid=""
cleanup(){ status=$?; if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi; rm -rf "$work_dir"; printf 'CLEANUP_VERIFIED docx_fixture_removed=true\n'; exit "$status"; }; trap cleanup EXIT
[[ "${LOCAL_SALES_STRUCTURED_DOCX_DISPOSABLE:-}" == "yes" ]] || { echo 'Set LOCAL_SALES_STRUCTURED_DOCX_DISPOSABLE=yes for local disposable execution.' >&2; exit 64; }; [[ "$(id -u)" == 0 ]] || { echo 'Requires disposable root runner only.' >&2; exit 64; }
mkdir -p "$socket_dir"; chown -R 1000:1000 "$work_dir"; setpriv --reuid=1000 --regid=1000 --clear-groups initdb -D "$data_dir" --no-locale --encoding=UTF8 --auth-local=trust -U lovable >/dev/null; printf "listen_addresses = ''\nport = %s\nunix_socket_directories = '%s'\nshared_memory_type = mmap\ndynamic_shared_memory_type = mmap\n" "$port" "$socket_dir" >> "$data_dir/postgresql.conf"; setpriv --reuid=1000 --regid=1000 --clear-groups postgres -D "$data_dir" >/dev/null 2>&1 & server_pid=$!
for _ in $(seq 1 150); do psql --host="$socket_dir" --port="$port" --username=lovable --dbname=postgres -Atqc 'select 1' >/dev/null 2>&1 && break; sleep .1; done
createdb --host="$socket_dir" --port="$port" --username=lovable "$database"; args=(--set=ON_ERROR_STOP=1 --host="$socket_dir" --port="$port" --username=lovable --dbname="$database")
psql "${args[@]}" -f "$root/supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_fixture.sql"
psql "${args[@]}" -f "$root/supabase/pending/20261009_sales_opportunity_structured_draft_metadata.sql"
psql "${args[@]}" -f "$root/supabase/pending/20261011_sales_opportunity_structured_draft_audit_location.sql"
psql "${args[@]}" -f "$root/supabase/pending/20261011_sales_opportunity_structured_draft_materialization.sql"
psql "${args[@]}" -f "$root/supabase/pending/20261012_structured_lifecycle_docx_registry_contract.sql"
psql "${args[@]}" -f "$root/supabase/pending/20261012_sales_structured_docx_materialization_contract.sql"
psql "${args[@]}" -f "$root/supabase/pending/20261012_structured_lifecycle_docx_trusted_receipt_authority.sql"
psql "${args[@]}" -f "$root/supabase/pending/20261012_structured_lifecycle_docx_private_object_enforcement.sql"
psql "${args[@]}" -c "GRANT EXECUTE ON FUNCTION public.save_sales_opportunity_structured_draft_at_location(uuid,uuid,uuid,uuid,text,integer,jsonb,uuid,uuid) TO authenticated; GRANT EXECUTE ON FUNCTION public.request_sales_structured_docx_materialization(uuid,uuid,uuid,uuid,text,integer,text,uuid) TO authenticated; GRANT EXECUTE ON FUNCTION public.commit_sales_structured_docx_materialization(uuid,uuid,uuid,uuid,text,text,text,text,text,bigint,uuid) TO authenticated; GRANT EXECUTE ON FUNCTION public.read_sales_structured_docx_materializations(uuid,uuid,uuid) TO authenticated;"
psql "${args[@]}" -f "$root/supabase/pending/tests/sales_structured_docx_materialization_local_acceptance.sql"
python3 "$root/supabase/pending/tests/check_structured_lifecycle_docx_private_object_enforcement_static.py"
printf 'SALES_STRUCTURED_DOCX_EXECUTION_COMPLETE=true\n'

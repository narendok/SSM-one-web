#!/usr/bin/env bash
set -euo pipefail
# LOCAL DISPOSABLE POSTGRESQL ONLY. It creates a private socket and never
# contacts a managed backend, preview, or production database.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
work_dir="$(mktemp -d /tmp/sales_feasibility_handover_XXXXXX)"; data_dir="$work_dir/data"; socket_dir="$work_dir/socket"; log_dir="$work_dir/logs"; database="sales_feasibility_handover_local"; port=55439; server_pid=""
mkdir -p "$socket_dir" "$log_dir"
cleanup() { local status=$?; if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi; rm -rf "$work_dir"; printf 'CLEANUP_VERIFIED private_fixture_removed_on_exit=true\n'; exit "$status"; }
trap cleanup EXIT
[[ "$(id -u)" == "0" ]] || { echo "This disposable fixture requires the sandbox root user." >&2; exit 64; }
chown -R 1000:1000 "$work_dir"
setpriv --reuid=1000 --regid=1000 --clear-groups initdb -D "$data_dir" --no-locale --encoding=UTF8 --auth-local=trust -U lovable >/dev/null
cat >>"$data_dir/postgresql.conf" <<PGCONF
listen_addresses = ''
port = $port
unix_socket_directories = '$socket_dir'
shared_memory_type = mmap
dynamic_shared_memory_type = mmap
logging_collector = off
PGCONF
setpriv --reuid=1000 --regid=1000 --clear-groups postgres -D "$data_dir" >"$log_dir/postgres.log" 2>&1 & server_pid=$!
for _ in $(seq 1 150); do psql --host="$socket_dir" --port="$port" --username=lovable --dbname=postgres -Atqc 'SELECT 1' >/dev/null 2>&1 && break; sleep 0.1; done
psql --host="$socket_dir" --port="$port" --username=lovable --dbname=postgres -Atqc 'SELECT 1' >/dev/null
createdb --host="$socket_dir" --port="$port" --username=lovable "$database"
args=(--set=ON_ERROR_STOP=1 --host="$socket_dir" --port="$port" --username=lovable --dbname="$database")
psql "${args[@]}" -f "$root/supabase/pending/tests/client_requirement_intake_local_fixture.sql"
psql "${args[@]}" -f "$root/supabase/pending/20261013_sales_feasibility_handover.sql"
# Fixture-only execution grant: intentionally absent from the pending proposal.
psql "${args[@]}" -c 'GRANT EXECUTE ON FUNCTION public.submit_sales_feasibility_handover(uuid, uuid, uuid, uuid, text, text, text, uuid[], uuid[], timestamptz, uuid) TO authenticated;'
psql "${args[@]}" -f "$root/supabase/pending/tests/sales_feasibility_handover_local_acceptance.sql"
psql "${args[@]}" -f "$root/supabase/pending/tests/sales_feasibility_handover_graph_lock_local_acceptance.sql"
psql "${args[@]}" -f "$root/supabase/pending/tests/sales_feasibility_handover_root_serialization_local_acceptance.sql"
# Same request key: replay validation holds the root; ordinary writer only commits after it returns.
psql "${args[@]}" -f "$root/supabase/pending/tests/sales_feasibility_handover_same_key_root_a.sql" >"$log_dir/root-same-key-replay.log" 2>&1 & root_same_key_replay_pid=$!
psql "${args[@]}" -c 'SELECT pg_advisory_lock(20261015, 11); SELECT pg_advisory_unlock(20261015, 11);' >/dev/null
psql "${args[@]}" -f "$root/supabase/pending/tests/sales_feasibility_handover_same_key_root_b.sql" >"$log_dir/root-same-key-writer.log" 2>&1 & root_same_key_writer_pid=$!
psql "${args[@]}" -c 'SELECT pg_advisory_lock(20261015, 12); SELECT pg_advisory_unlock(20261015, 12);' >/dev/null
wait "$root_same_key_replay_pid"; wait "$root_same_key_writer_pid"
cat "$log_dir/root-same-key-replay.log" "$log_dir/root-same-key-writer.log"
psql "${args[@]}" -Atqc "SELECT CASE WHEN (SELECT count(*) FROM public.sales_feasibility_handover_requests WHERE request_key='00000000-0000-4000-8000-000000000198')=1 AND (SELECT findings FROM public.requirement_feasibility_reviews WHERE requirement_id=(SELECT requirement_id FROM public.sales_feasibility_handover_requests WHERE request_key='00000000-0000-4000-8000-000000000198'))='same-key writer ran after replay' THEN 'SALES_FEASIBILITY_HANDOVER_ROOT_SAME_KEY_PASS receipt=1 writer_after_replay=true' ELSE 'SALES_FEASIBILITY_HANDOVER_ROOT_SAME_KEY_FAIL' END" | grep -Fx 'SALES_FEASIBILITY_HANDOVER_ROOT_SAME_KEY_PASS receipt=1 writer_after_replay=true'
# Different request key: the existing protected assignment contract must wait on the same root.
psql "${args[@]}" -f "$root/supabase/pending/tests/sales_feasibility_handover_different_key_a.sql" >"$log_dir/root-different-key-holder.log" 2>&1 & root_different_holder_pid=$!
psql "${args[@]}" -c 'SELECT pg_advisory_lock(20261015, 13); SELECT pg_advisory_unlock(20261015, 13);' >/dev/null
psql "${args[@]}" -f "$root/supabase/pending/tests/sales_feasibility_handover_different_key_b.sql" >"$log_dir/root-different-key-writer.log" 2>&1 & root_different_writer_pid=$!
psql "${args[@]}" -c 'SELECT pg_advisory_lock(20261015, 14); SELECT pg_advisory_unlock(20261015, 14);' >/dev/null
wait "$root_different_holder_pid"; wait "$root_different_writer_pid"
cat "$log_dir/root-different-key-holder.log" "$log_dir/root-different-key-writer.log"
printf 'SALES_FEASIBILITY_HANDOVER_ROOT_DIFFERENT_KEY_PASS protected_assignment_serialized=true\n'
# New-review insertion: the root guard delays the direct fixture writer; it is still proof only
# for a writer that takes the accepted root lock, never a replacement for live direct-write removal.
psql "${args[@]}" -f "$root/supabase/pending/tests/sales_feasibility_handover_new_review_phantom.sql" >"$log_dir/root-phantom-holder.log" 2>&1 & root_phantom_holder_pid=$!
psql "${args[@]}" -c 'SELECT pg_advisory_lock(20261015, 15); SELECT pg_advisory_unlock(20261015, 15);' >/dev/null
psql "${args[@]}" -f "$root/supabase/pending/tests/sales_feasibility_handover_new_review_writer.sql" >"$log_dir/root-phantom-writer.log" 2>&1 & root_phantom_writer_pid=$!
psql "${args[@]}" -c 'SELECT pg_advisory_lock(20261015, 16); SELECT pg_advisory_unlock(20261015, 16);' >/dev/null
wait "$root_phantom_holder_pid"; wait "$root_phantom_writer_pid"
cat "$log_dir/root-phantom-holder.log" "$log_dir/root-phantom-writer.log"
psql "${args[@]}" -Atqc "SELECT CASE WHEN (SELECT count(*) FROM public.requirement_feasibility_reviews WHERE requirement_id=(SELECT requirement_id FROM public.sales_feasibility_handover_requests WHERE request_key='00000000-0000-4000-8000-000000000198'))=2 THEN 'SALES_FEASIBILITY_HANDOVER_ROOT_PHANTOM_PASS guarded_writer_after_root_release=true' ELSE 'SALES_FEASIBILITY_HANDOVER_ROOT_PHANTOM_FAIL' END" | grep -Fx 'SALES_FEASIBILITY_HANDOVER_ROOT_PHANTOM_PASS guarded_writer_after_root_release=true'
psql "${args[@]}" -f "$root/supabase/pending/tests/sales_feasibility_handover_replay_held.sql" >"$log_dir/replay-held.log" 2>&1 & replay_held_pid=$!
psql "${args[@]}" -c 'SELECT pg_advisory_lock(20261015, 1); SELECT pg_advisory_unlock(20261015, 1);' >/dev/null
psql "${args[@]}" -f "$root/supabase/pending/tests/sales_feasibility_handover_plain_writer_after_replay.sql" >"$log_dir/replay-held-writer.log" 2>&1 & replay_held_writer_pid=$!
psql "${args[@]}" -c 'SELECT pg_advisory_lock(20261015, 2); SELECT pg_advisory_unlock(20261015, 2);' >/dev/null
wait "$replay_held_pid"
wait "$replay_held_writer_pid"
cat "$log_dir/replay-held.log" "$log_dir/replay-held-writer.log"
psql "${args[@]}" -Atqc "SELECT CASE WHEN (SELECT applicable_workstreams FROM public.requirement_feasibility_reviews WHERE requirement_id = (SELECT requirement_id FROM public.sales_feasibility_handover_requests WHERE request_key = '00000000-0000-4000-8000-000000000197')) = '[\"FIRMWARE\"]'::jsonb THEN 'SALES_FEASIBILITY_HANDOVER_REPLAY_HELD_PLAIN_UPDATE_PASS' ELSE 'SALES_FEASIBILITY_HANDOVER_REPLAY_HELD_PLAIN_UPDATE_FAIL' END" | grep -Fx 'SALES_FEASIBILITY_HANDOVER_REPLAY_HELD_PLAIN_UPDATE_PASS'
psql "${args[@]}" -c "UPDATE public.requirement_feasibility_reviews SET applicable_workstreams = '[\"HARDWARE\"]'::jsonb WHERE requirement_id = (SELECT requirement_id FROM public.sales_feasibility_handover_requests WHERE request_key = '00000000-0000-4000-8000-000000000197');"
psql "${args[@]}" -f "$root/supabase/pending/tests/sales_feasibility_handover_plain_writer_held.sql" >"$log_dir/writer-held.log" 2>&1 & writer_held_pid=$!
psql "${args[@]}" -c 'SELECT pg_advisory_lock(20261015, 3); SELECT pg_advisory_unlock(20261015, 3);' >/dev/null
psql "${args[@]}" -f "$root/supabase/pending/tests/sales_feasibility_handover_replay_after_writer.sql" >"$log_dir/writer-held-replay.log" 2>&1 & writer_held_replay_pid=$!
psql "${args[@]}" -c 'SELECT pg_advisory_lock(20261015, 4); SELECT pg_advisory_unlock(20261015, 4);' >/dev/null
wait "$writer_held_pid"
wait "$writer_held_replay_pid"
cat "$log_dir/writer-held.log" "$log_dir/writer-held-replay.log"
psql "${args[@]}" -Atqc "SELECT CASE WHEN (SELECT count(*) FROM public.sales_feasibility_handover_requests WHERE request_key = '00000000-0000-4000-8000-000000000197') = 1 AND (SELECT count(*) FROM public.requirement_feasibility_reviews WHERE requirement_id = (SELECT requirement_id FROM public.sales_feasibility_handover_requests WHERE request_key = '00000000-0000-4000-8000-000000000197')) = 1 AND (SELECT applicable_workstreams FROM public.requirement_feasibility_reviews WHERE requirement_id = (SELECT requirement_id FROM public.sales_feasibility_handover_requests WHERE request_key = '00000000-0000-4000-8000-000000000197')) = '[\"FIRMWARE\"]'::jsonb THEN 'SALES_FEASIBILITY_HANDOVER_WRITER_HELD_PLAIN_UPDATE_PASS receipt=1 reviews=1 replay=denied' ELSE 'SALES_FEASIBILITY_HANDOVER_WRITER_HELD_PLAIN_UPDATE_FAIL' END" | grep -Fx 'SALES_FEASIBILITY_HANDOVER_WRITER_HELD_PLAIN_UPDATE_PASS receipt=1 reviews=1 replay=denied'
printf 'SALES_FEASIBILITY_HANDOVER_LOCAL_ACCEPTANCE_EXECUTION_COMPLETE=true\n'

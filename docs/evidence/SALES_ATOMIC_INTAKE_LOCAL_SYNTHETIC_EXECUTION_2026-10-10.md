# Sales Atomic Intake — Local Synthetic Execution Evidence (2026-10-10 UTC)

Status: **executed local synthetic evidence only**. This is a sanitized factual extract from the disposable PostgreSQL 17.9 private-socket/mmap execution summary. It contains no database connection URL, credential, token, or caller session.

## Executed outcome

- The local race/rollback runner exited `0`.
- The fixture used PostgreSQL 17.9 with `shared_memory_type=mmap` and `dynamic_shared_memory_type=mmap`.
- Three failpoints rolled back at Master Specification header, version, and receipt insertion. Their SQL assertions cover opportunity, specification, version, activity/audit, receipt, and both numbering sequences.
- Each contested-lock case observed the RPC worker waiting on the exact advisory lock before the fixture permission was revoked and released. The denied new request left every tracked record count at zero; the replay case retained only its pre-existing records.
- Race evidence records exact replay convergence, changed-payload and actor conflicts, and independent different-key numbering.

## Limits

This does **not** prove managed authentication, real caller JWT transport, deployed RLS/policies, approved transport grants, original-schema compatibility, or installation safety. It is not authority to install or grant anything.

## Sanitized execution markers

```text
FIXTURE postgres_version=17.9 mmap mmap 
psql:/dev-server/supabase/pending/tests/sales_atomic_intake_replay_local_failpoint_acceptance.sql:43: NOTICE:  FAILPOINT_ROLLBACK_PASS=master_specifications
psql:/dev-server/supabase/pending/tests/sales_atomic_intake_replay_local_failpoint_acceptance.sql:43: NOTICE:  FAILPOINT_ROLLBACK_PASS=master_specification_versions
psql:/dev-server/supabase/pending/tests/sales_atomic_intake_replay_local_failpoint_acceptance.sql:43: NOTICE:  FAILPOINT_ROLLBACK_PASS=sales_opportunity_intake_receipts
CONTRACT_LOCK_WAIT_OBSERVED case=new_request evidence=3503:Lock:advisory:1
CONTRACT_LOCK_WAIT_STATUS case=new_request holder=0 worker=3
CONTRACT_LOCK_DENIAL_PASS case=new_request receipts=0 opportunities=0 specifications=0 versions=0 audits=0
CONTRACT_LOCK_WAIT_OBSERVED case=receipt_replay evidence=3541:Lock:advisory:1
CONTRACT_LOCK_WAIT_STATUS case=receipt_replay holder=0 worker=3
CONTRACT_LOCK_DENIAL_PASS case=receipt_replay receipts=1 opportunities=1 specifications=1 versions=1 audits=1
RACE_WORKER_STATUS label=same_key_same_payload a=0 b=0
 same_key_same_payload | a            | 1c857ba0-734b-4554-94b0-4d19daed4138 | OPP-0001           | 8c02dad3-8f43-446d-b914-bb330be8c0bc | MS-0001                     | 0451749c-db3f-46de-8a2e-939380c28d3b |                                   1 | t
 same_key_same_payload | b            | 1c857ba0-734b-4554-94b0-4d19daed4138 | OPP-0001           | 8c02dad3-8f43-446d-b914-bb330be8c0bc | MS-0001                     | 0451749c-db3f-46de-8a2e-939380c28d3b |                                   1 | f
RACE_WORKER_STATUS label=same_key_changed_payload a=3 b=0
 same_key_changed_payload | b            | 5059c483-ed00-4269-a6f1-e710887d57d1 | OPP-0002           | ce699129-d683-491b-bdc5-fa7a81f9cb47 | MS-0002                     | bcea81ed-d037-44b4-b18d-ef1017245c7e |                                   1 | f
RACE_WORKER_STATUS label=same_key_actor_conflict a=3 b=0
 same_key_actor_conflict | b            | 930a1219-8d4d-45fc-a214-7d70d7839d8c | OPP-0003           | 4fd19b19-7f1b-4778-8adb-a628885b038d | MS-0003                     | f47f0e07-5fd0-4a51-b8f5-3516b436d12d |                                   1 | f
RACE_WORKER_STATUS label=different_keys a=0 b=0
 different_keys | a            | e8405245-1377-4c0b-9931-c0899fdef55b | OPP-0005           | a89ec794-1478-4120-b262-3f0b9cc38e07 | MS-0005                     | 8f1293ee-c2b3-42f2-87b9-3329f1385f87 |                                   1 | f
 different_keys | b            | 4ec6db4c-2c02-495a-bbad-f2630379e91a | OPP-0004           | fbea0790-5e0f-4a20-8233-5678a04ce5d9 | MS-0004                     | 5bfc68cf-ccb5-40f8-940c-74f4c94ebef7 |                                   1 | f
SUITE_EXIT=0
CLEANUP socket_absent=yes process_absent=yes root=/tmp/sales_atomic_acceptance_contested_A8JsYV
CLEANUP root_removed=yes
```

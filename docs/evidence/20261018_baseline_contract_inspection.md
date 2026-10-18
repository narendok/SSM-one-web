# Baseline/commercial contract inspection — 18 October 2026

Original Lovable project d758dbf2-2f0e-44b3-b149-1ec51def58eb; backend yyrvduosyyaluifqvwkr. Cloud SQL executed a catalog-only BEGIN TRANSACTION READ ONLY / SELECT / ROLLBACK. Export contains schema/policy/routine metadata, no business rows or credentials. Raw and parsed files: 20261018_baseline_contract_catalog.csv/.json. Local evidence only; no backend changes or installation approval implied.

Verified contracts:
- requirement_baselines has requirement_id, baseline_number, revision_number, requirement_snapshot, commercial_snapshot, status, approved_by, approved_at. Its INSERT policy accepts sales.manage or admin; policy alone does not establish exact-Master checks, conflict resolution, immutable client consent or idempotent approval.
- sales_commercial_records has requirement_id, status, customer_authorized_at, authorization_reference and commercial fields, with broad Sales-manage/admin ALL policy. No revision/Master version or private immutable approval receipt columns were captured. A timestamp on this mutable row is not client-bound authorization proof.
- customer_requirement_revisions stores requirement_data JSONB and has no top-level source_master_specification_version_id column. Protected adapters must retain their explicit provenance extraction/verification; do not invent a column for an aggregate read.
- master_specification_versions stores specification_id, version_number and specification_data JSONB. INSERT and SELECT policies exist. Future baseline lock must bind exact immutable version identity and accepted content, not only the mutable current-version header.
- No public routine whose NAME contains baseline, commercial or conflict was found. This name-limited inventory does not exclude differently named functions, dynamic SQL or other schema routines.

Next contract scope: independently capture the existing protected response receipt/provenance signatures and helper/numbering semantics; compose an exact-revision/Master conflict-resolution and client-authorization receipt before baseline locking. Existing baseline rows must not be backfilled with guessed consent or request keys. Restriction/restore, atomic audit, replay, source mutation races and real caller acceptance require separate verification before requesting installation. Current baseline server handler remains closed and UI approval disabled.

Managed editor also displays Build unsuccessful / Preview out of date for recent GitHub imports despite local Vite/Nitro success. Build Details interaction timed out before dispatch; no failure logs or root cause obtained. Do not equate local build success with managed preview deployment. No build-fix generation, sidebar/BOM plan activation or Publish was requested.

## Managed-preview follow-up — 07:51Z

GitHub fetch confirms local HEAD matches origin/main (0/0); no Lovable file changes to reconcile. Both existing original-project browser tabs failed browser-control focus initialization with timeouts. The diagnostic response requested earlier could not be retrieved; no managed root cause, repair or preview success is claimed. No additional Lovable prompt, generation, dependency change, backend action, Publish or unchanged tests were performed. Existing local metadata/evidence remains preserved and unsynced.

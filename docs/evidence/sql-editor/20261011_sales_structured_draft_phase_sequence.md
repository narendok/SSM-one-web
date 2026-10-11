# Sales structured-draft staged SQL editor sequence — 2026-10-11

## Status

The former combined four-source bundle is **deprecated and must not be executed**. It activated Storage policies and authenticated execution before the required private binding and managed caller acceptance. The four approved contract files remain byte-identical and SHA-pinned.

## Verified read-only inputs

- Opportunity: `a6c62c81-1cc2-4804-b1c5-c004c6730b52`
- Customer: `03e06115-a7d4-4965-9e92-9c37462f5ddc`
- Master: `7a3aba95-61f6-495a-a280-f37a3be77670`
- Master version 1: `4914fba5-43a0-4486-b62f-d775a9bb16b9`
- Sales client folder: `020dcca5-7809-4287-88cd-537d837a3eee`, locked, not trashed
- Sales department: `db21a9b2-2cd4-4891-9151-064bef8a7cb4`
- Dependencies present; all ten proposed relations absent; eight reviewed Storage-policy predicates match; future entrypoint functions absent.

## Ordered phases

1. **Preflight.** Run the existing read-only preflight, then Phase B review. Stop on any discrepancy.
2. **Phase A.** Run `20261011_sales_structured_draft_phase_a_install.sql` as one transaction. It embeds only sources 1–3, with no authenticated EXECUTE grants and no Storage policy changes.
3. **Phase B.** Run `20261011_sales_structured_draft_phase_b_binding_review.sql` read-only. A separately reviewed administrator action may later create exactly one active `STRUCTURED_DRAFT` binding using the verified Sales root/target ancestry and prefix `sales/opportunity/a6c62c81-1cc2-4804-b1c5-c004c6730b52/`. This package does not contain that write because the root and approver/authorization provenance must be independently verified.
4. **Phase C.** Run managed caller acceptance through the real authenticated transport, with the rollback-only review script as its boundary/checklist. `SET LOCAL ROLE authenticated` changes database privileges only; it does not populate or authenticate `auth.uid()`. Any temporary EXECUTE grant is transaction-local and must roll back. No policy or persistent grant may be used before evidence is accepted.
5. **Phase D.** After Phases B/C evidence and separate action-time approval, run `20261011_sales_structured_draft_phase_d_activation.sql` as one transaction. It contains only approved source 4: policy replacement and the five persistent authenticated grants.

## Unresolved gates

- An administrator must still verify and approve the exact Sales root ancestor and binding provenance; the target folder alone is insufficient.
- Managed acceptance requires a real existing authorized actor and a supported caller-authenticated transport. SQL editor `postgres` execution and `SET ROLE` are not evidence of that actor.
- Phase D requires accepted managed evidence and renewed action-time approval because it changes Storage policies and grants.

## Source manifest

| Source | SHA-256 | Bytes | Phase |
|---|---|---:|---|
| `20261009_sales_opportunity_structured_draft_metadata.sql` | `c69253e49431844fc4ac08df2bf450378965bee01499ef6d37df1451f5bcc65f` | 21699 | A |
| `20261011_sales_opportunity_structured_draft_audit_location.sql` | `731837c077b6a1b83a7c74a1a0e1a5b0649f4779d752e55705e0f61b9fb4b090` | 10665 | A |
| `20261011_sales_opportunity_structured_draft_materialization.sql` | `368324a32f498c719bfd425edfb528ab27de3b1ffe302d5b5e08068aa5795c15` | 21462 | A |
| `20261011_sales_opportunity_structured_draft_materialization_activation.sql` | `dc3809675ccbe1eb886eae6e879e6cf8638fcc6955565f541883b64b8b776f2e` | 4702 | D |

# Managed feasibility/task authority audit — 16 October 2026

Original project d758dbf2-2f0e-44b3-b149-1ec51def58eb; backend yyrvduosyyaluifqvwkr. One read-only Lovable request reported the following managed findings; this record is an attributed audit summary, not an independently executed SQL capture or caller acceptance.

- submit_sales_feasibility_handover and protected assignment/reviewer-response routines are not installed.
- customer_requirements, customer_requirement_revisions and requirement_feasibility_reviews have RLS enabled, separate read policies and broad Sales/admin FOR ALL policies. Direct INSERT/UPDATE/DELETE grants remain for anon/authenticated/service_role; ordinary access still depends on RLS.
- No installed root-serialization writer protocol was found. Authorized direct Sales graph writes bypass the pending design. Only number/timestamp adjacent triggers were reported.
- project_tasks has no installed department-delegated edit contract. Broad projects.manage governs mutations, with separate creator/admin/project-manager insert/delete rules. lifecycle_can_manage_department is not wired to task policy.
- Missing gates: target-bound exact policy/grant capture and reviewed restore, protected routine installation, writer compatibility/direct-write restriction, production-like caller/RLS and concurrency/restore acceptance. No database installation authorized or performed.

## Source reconciliation exception

Although the request explicitly prohibited file edits, origin advanced through 2d45d95, a016b2e and 50b2c35, changing the managed Vite config dependency and previewAuthStorage. Clean local source was fast-forwarded normally to inspect/preserve that history. These unrelated runtime changes were then restored to their previously validated dd662a2 contents in a normal follow-up commit; no reset, force push or history deletion. Auth behavior and dependency version remain as before this audit. No further managed generation requested. Continue local source work.

The audit narrows the blocker but is not deployment approval. Existing source-only pending SQL must remain disabled until accepted protected deployment and specific permission-change authorization. User-facing local trial is unchanged.

Prepared a read-only catalog capture at supabase/pending/20261016_feasibility_task_authority_capture_read_only.sql for exact policy expressions, role OIDs/raw ACLs including column ACLs, RLS flags, triggers and known-routine fingerprints. Explicitly reports target identity as unverified, compares expected/found table counts and avoids data rows/function bodies. Not executed: no SQL parsing/database acceptance claimed. It supports drift/restore review but cannot itself restore routines or prove absence of dynamic/external writers.

Managed catalog artifact received: captured 2026-10-15T23:21:22.692607Z, 4 tables, 10 policies, 136 grant entries, 7 triggers, 6 routine fingerprints. Original downloaded artifact retained locally in Downloads as 20261015_feasibility_task_authority_metadata_capture.json; SHA256 843BE622B18A4E04B2F41673188CC4EEB79AC0D2E1C78EE99895121EF74EEAFC. Raw security metadata is not copied into the GitHub repository. Artifact normalizes grant role OIDs to labels; target binding is attributed to the managed tool session, not proven by SQL. Validated three permissive authenticated graph policies have identical USING/CHECK expressions and 18 historical anon/authenticated I/U/D grants. A source-only restore review draft now names only the compatibility proposal's removed policies/grants. No SQL execution or restore acceptance. Exact SELECT/unrelated ACL drift and full caller/concurrency checks remain required.

Second read-only managed request again produced the same unrelated dependency/preview-auth changes in 6425e12/dad3348/6aa2a54. Preserved via clean fast-forward and restored exact pre-request runtime contents. Do not request further managed generation for this capture; continue locally.

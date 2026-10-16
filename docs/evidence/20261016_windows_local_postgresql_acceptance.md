# Windows disposable PostgreSQL acceptance — 16 October 2026

Implemented `supabase/pending/tests/run_requirement_feasibility_windows_local.ps1`. It accepts only a local binary directory, creates a unique temporary cluster/database, binds PostgreSQL to loopback on a temporary port, uses a generated fixture password and executes existing SQL with ON_ERROR_STOP. It retains diagnostic logs, stops the cluster and removes the password file. No managed connection, installation service or production identity is used.

Runtime: PostgreSQL 17.11 Windows x64, EDB portable binaries linked from https://www.postgresql.org/download/windows/ and https://www.enterprisedb.com/download-postgresql-binaries. Download archive SHA256: 80379B2C04D51C30225532E0AE04509899141E9957ED096FE749D7FD9DF8F82F (locally computed provenance, not a vendor checksum).

Executed fixture schema, client intake proposal, feasibility handover proposal and original-target compatibility local acceptance. All four psql executions exited successfully. Acceptance marker:

```
ORIGINAL_TARGET_COMPATIBILITY_ACCESS_PASS
reads_before_after=sales_manage,sales_view,engineering_manage,engineering_view_preserved
unauthorized_authenticated,anon_denied
protected_handover,assignment,response=allowed
authenticated_anon_direct_iud_all_tables=denied
```

Logs retained locally at `C:/Users/Admin/AppData/Local/Temp/ssm-feasibility-2093c078f10c449da24ed059f948f76c`. Final shutdown reported server stopped; independent pg_ctl status reported no server running; temporary password file was absent. Earlier startup trials were stopped too. Windows runner fixes avoid waiting for the server descendant tree and remove an empty PGSERVICE setting, which libpq otherwise interprets as a named service.

This is actual SQL execution against synthetic local schema/roles/helpers. It does not reproduce managed JWT verification, production policies, deployment, target rollback, all concurrent writers or browser persistence. Protected feature availability remains disabled. Existing approved non-production environment and identities are still needed for target acceptance. No screenshot: this increment is infrastructure/SQL verification, not a successful visible feature.

#!/usr/bin/env bash
set -euo pipefail
# Static source-only guard: this does not establish managed caller-RLS behavior.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
sql="$root/supabase/pending/20261005_client_requirement_intake.sql"
view_block="$(sed -n '/CREATE OR REPLACE VIEW public.requirement_feasibility_review_provenance/,/REVOKE ALL ON TABLE public.requirement_feasibility_review_provenance/p' "$sql")"
[[ "$view_block" == *"security_invoker = true"* ]]
[[ "$view_block" != *"SECURITY DEFINER" ]]
[[ "$view_block" != *"GRANT SELECT ON TABLE public.requirement_feasibility_review_provenance TO authenticated" ]]
[[ "$view_block" != *"LEFT JOIN public.customer_requirement_revisions"* ]]
[[ "$view_block" == *"REVOKE ALL ON TABLE public.requirement_feasibility_review_provenance FROM PUBLIC, anon, authenticated;" ]]
printf 'FEASIBILITY_PROVENANCE_STATIC_SECURITY_PASS invoker=true definer=false authenticated_grant=false hidden_joins_suppress_rows=true\n'
#!/usr/bin/env bash
set -euo pipefail
# Static source-only guard. It proves proposal separation, not managed privilege safety.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
main="$root/supabase/pending/20261005_client_requirement_intake.sql"
transition="$root/supabase/pending/20261011_requirement_feasibility_direct_write_compatibility_transition.sql"
legacy_scope='public.external_requirement_scope_allows(uuid,uuid,uuid)'
direct_write='REVOKE INSERT, UPDATE, DELETE ON TABLE public.requirement_feasibility_reviews FROM authenticated;'
sales_policy='DROP POLICY IF EXISTS "Sales users manage feasibility reviews" ON public.requirement_feasibility_reviews;'
[[ -f "$transition" ]]
! grep -Fq "$legacy_scope" "$main"
! grep -Fq "$direct_write" "$main"
! grep -Fq "$sales_policy" "$main"
grep -Fq 'CREATE OR REPLACE FUNCTION public.submit_external_customer_requirement' "$main"
grep -Fq 'DROP FUNCTION public.submit_external_customer_requirement(uuid,uuid,text,text,jsonb)' "$main"
grep -Fq 'DROP FUNCTION public.record_requirement_feasibility_response(uuid,text,text,text,text)' "$main"
grep -Fq 'WITH (security_invoker = true)' "$main"
grep -Fq 'UNIQUE (source_revision_id, department_id)' "$main"
grep -Fq "$legacy_scope" "$transition"
grep -Fq "$direct_write" "$transition"
grep -Fq "$sales_policy" "$transition"
grep -Fq 'egjotuxqguifnvdnflan' "$transition"
grep -Fq 'yyrvduosyyaluifqvwkr' "$transition"
grep -Fq 'Do not use CASCADE.' "$transition"
printf 'CLIENT_REQUIREMENT_COMPATIBILITY_SPLIT_STATIC_PASS main_retains_legacy=true transition_contains_exact_operations=true protected_paths_retained=true\n'

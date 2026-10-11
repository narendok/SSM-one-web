from pathlib import Path

contract = Path('supabase/pending/20261012_sales_sample_archive_restore_contract.sql').read_text()
assert 'SOURCE-ONLY, UNDEPLOYED REVIEW CONTRACT' in contract
assert 'DELETE FROM public.sales_' not in contract
assert 'TRUNCATE' not in contract
assert 'GRANT EXECUTE' not in contract
assert "OPPORTUNITY-2026-0013" not in contract
assert 'archive_reviewed_sales_samples(jsonb,text,uuid)' in contract
assert 'restore_reviewed_sales_samples(uuid,text,uuid)' in contract
assert 'read_sales_sample_archive_history(uuid)' in contract
assert 'REVOKE ALL ON FUNCTION public.archive_reviewed_sales_samples' in contract
assert 'REVOKE ALL ON FUNCTION public.restore_reviewed_sales_samples' in contract
assert 'archive_manifest_id' in contract
assert 'sales_sample_archive_dependency_snapshot' in contract
print('SALES_SAMPLE_ARCHIVE_RESTORE_STATIC_PASS=true')
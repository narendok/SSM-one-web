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
assert 'sales_sample_archive_assert_expected_facts' in contract
assert 'extensions.digest' in contract
assert 'extensions.gen_random_uuid()' in contract
for revision_id in ['dc0ccda7-b4ee-4d16-b4d5-a11a9ee8e7c6','23e2a05a-d8b3-421c-b760-e0273143d766','a3c747a3-cb61-43a6-805a-788848143680','1bced975-c1c6-445c-be44-fa988c01e434','2a238167-050c-4e31-92a3-6d0ab0e611d9']:
    assert revision_id in contract
print('SALES_SAMPLE_ARCHIVE_RESTORE_STATIC_PASS=true')
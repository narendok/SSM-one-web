#!/usr/bin/env python3
"""Static boundary guard for the uninstalled assigned-person DOCX proposal."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
sql = (root / '20261012_sales_structured_docx_materialization_contract.sql').read_text()
folder = (root / '20261012_sales_structured_docx_folder_discovery.sql').read_text()
acceptance = (Path(__file__).parent / 'sales_structured_docx_materialization_local_acceptance.sql').read_text()
runner = (Path(__file__).parent / 'run_sales_structured_docx_materialization_local_acceptance.sh').read_text()

def need(text: str, value: str, label: str):
    if value not in text:
        raise SystemExit(f'MISSING {label}')

def forbid(text: str, value: str, label: str):
    if value in text:
        raise SystemExit(f'FORBIDDEN {label}')

for table in ('sales_opportunity_structured_docx_assignments', 'sales_opportunity_structured_docx_requests', 'sales_opportunity_structured_docx_storage_attempts', 'sales_opportunity_structured_docx_materializations', 'sales_opportunity_structured_docx_audit_events'):
    need(sql, f'CREATE TABLE public.{table}', table)
    need(sql, f'GRANT ALL ON public.{table} TO service_role;', f'{table} service grant only')
    need(sql, f'ALTER TABLE public.{table} ENABLE ROW LEVEL SECURITY;', f'{table} RLS')
need(sql, "responsible_employee_id", 'responsible employee pin')
need(sql, 'registry_assignment_id', 'registry assignment pin')
need(sql, "scope_type='SALES_OPPORTUNITY'", 'pre-handover Sales scope')
need(sql, "scope_type='PROJECT'", 'post-handover project scope')
need(sql, 'sales_project_handovers', 'handover-only project association')
need(sql, "user_id = v_actor AND employment_status = 'ACTIVE'", 'active employee actor check')
need(sql, 'public.employee_departments', 'department membership recheck')
need(sql, 'public.can_access_department_drive', 'scoped Drive recheck')
need(sql, "application/vnd.openxmlformats-officedocument.wordprocessingml.document", 'OOXML MIME pin')
need(sql, "'-draft.docx'", 'DOCX private object suffix')
need(sql, 'record_sales_structured_docx_object_verification', 'trusted object verifier receipt')
need(sql, 'stored_object.version = p_object_version', 'immutable object version check')
need(sql, 'p_ooxml_content_types', 'OOXML content types verification')
need(sql, 'p_ooxml_word_document', 'OOXML Word document verification')
need(sql, 'p_html_detected', 'renamed HTML rejection')
need(sql, 'current_version.version_number=current_specification.current_version', 'current Master version recheck')
need(sql, "document_kind IN ('SOR','CONTRACT_REVIEW')", 'Sales category boundary')
forbidden_kinds = ("'PRS'", "'BOM'", "'DFMEA'")
for value in forbidden_kinds:
    forbid(sql, value, f'unsupported Sales DOCX kind {value}')
need(sql, 'source_fingerprint', 'immutable source pin')
need(sql, 'template_schema_hash', 'immutable schema pin')
need(sql, 'FOR UPDATE', 'locked rechecks')
need(sql, 'pg_advisory_xact_lock', 'request lock')
need(sql, 'DOCX request key conflicts', 'replay conflict')
need(sql, 'Structured Sales DOCX history is append-only', 'append-only mutation guard')
for signature in (
  'public.request_sales_structured_docx_materialization(uuid,uuid,uuid,uuid,text,integer,text,uuid)',
  'public.authorize_sales_structured_docx_upload(uuid,uuid,uuid,uuid,text,bigint)',
  'public.record_sales_structured_docx_object_verification(uuid,text,text,text,text,bigint,boolean,boolean,boolean,text)',
  'public.commit_sales_structured_docx_materialization(uuid,uuid,uuid,uuid,text,text,text,text,text,bigint,uuid)',
  'public.read_sales_structured_docx_materializations(uuid,uuid,uuid)',
):
    need(sql, f'REVOKE ALL ON FUNCTION {signature} FROM PUBLIC, anon, authenticated, service_role;', f'default revoke {signature}')
    forbid(sql, f'GRANT EXECUTE ON FUNCTION {signature}', f'pre-grant {signature}')
forbidden = ('CREATE POLICY', 'INSERT INTO public.sales_opportunity_structured_draft_materializations', "mime_type='text/html'", "'-draft.html'")
for value in forbidden:
    forbid(sql, value, value)
need(folder, 'resolve_sales_opportunity_structured_draft_location', 'trusted folder resolver')
need(folder, 'public.can_access_department_drive', 'folder department access recheck')
need(folder, 'target_folder_node_id', 'narrow folder identifier')
need(folder, 'REVOKE ALL ON FUNCTION public.discover_sales_opportunity_structured_draft_folder', 'folder transport revoke')
for value in ('storage_bucket', 'storage_path_prefix'):
    forbid(folder, f'RETURNS TABLE(location_id uuid, department_id uuid, target_folder_node_id uuid, {value}', f'folder read does not expose {value}')
for expected in ('LOCAL_DOCX_FAIL pre-handover Sales scope did not resolve without a project', 'LOCAL_DOCX_FAIL other opportunity/customer resolved Sales responsibility', 'LOCAL_DOCX_FAIL post-handover project scope did not resolve', 'LOCAL_DOCX_FAIL exact protected upload authority missing', 'LOCAL_DOCX_FAIL non-DOCX upload accepted', 'LOCAL_DOCX_FAIL unassigned actor read the DOCX object past restrictive policy', 'LOCAL_DOCX_FAIL unassigned reader accepted', 'LOCAL_DOCX_FAIL cross-department/source accepted', 'LOCAL_DOCX_FAIL changed replay accepted', 'LOCAL_DOCX_FAIL revoked assignment accepted', 'SALES_STRUCTURED_DOCX_LOCAL_ACCEPTANCE_PASS'):
    need(acceptance, expected, expected)
need(runner, 'LOCAL_SALES_STRUCTURED_DOCX_DISPOSABLE=yes', 'explicit disposable opt-in')
need(runner, 'CLEANUP_VERIFIED docx_fixture_removed=true', 'fixture cleanup')
print('SALES_STRUCTURED_DOCX_STATIC_GUARD_PASS')

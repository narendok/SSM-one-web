-- REVIEW-ONLY: Sample-data cleanup inventory. Do not execute any UPDATE, DELETE,
-- archive, trash, storage, policy, grant, or migration statement from this file.
--
-- Retained anchor: OPPORTUNITY-2026-0013 / MASTER-2026-0001 rev 1 and every
-- dependent structured-draft revision, receipt, audit, materialization, Drive
-- revision, register, and private object remain excluded from any future cleanup.
--
-- This query reports exact candidate identifiers, provenance, and dependency
-- counts/IDs only. It deliberately has no mutation statement and does not rely
-- on requested_by as a selector. Requirement display numbers are requirement
-- numbers, never customer-table IDs. A matching title alone is never sufficient.

WITH candidate_requirements AS (
  SELECT r.id, r.requirement_number, r.title, r.customer_id, r.opportunity_id,
    r.status, r.current_revision, r.created_at
  FROM public.customer_requirements AS r
  WHERE r.requirement_number IN (
    'CUSTOMER-2026-0003', 'CUSTOMER-2026-0004', 'CUSTOMER-2026-0005',
    'CUSTOMER-2026-0006', 'CUSTOMER-2026-0007'
  )
), candidate_opportunities AS (
  SELECT o.id, o.opportunity_number, o.name, o.customer_id, o.stage, o.status, o.created_at
  FROM public.sales_opportunities AS o
  WHERE o.opportunity_number IN (
    'OPPORTUNITY-2026-0006', 'OPPORTUNITY-2026-0007', 'OPPORTUNITY-2026-0008',
    'OPPORTUNITY-2026-0009', 'OPPORTUNITY-2026-0010'
  )
)
SELECT
  'customer_requirement'::text AS candidate_type,
  r.id AS candidate_id,
  r.requirement_number AS candidate_key,
  r.title AS candidate_name,
  r.status::text AS candidate_status,
  r.customer_id,
  r.opportunity_id,
  r.created_at,
  jsonb_build_object(
    'current_revision', r.current_revision,
    'requirement_revisions', (SELECT count(*) FROM public.customer_requirement_revisions rr WHERE rr.requirement_id = r.id),
    'requirement_revision_ids', COALESCE((SELECT jsonb_agg(rr.id ORDER BY rr.id) FROM public.customer_requirement_revisions rr WHERE rr.requirement_id = r.id), '[]'::jsonb),
    'feasibility_reviews', (SELECT count(*) FROM public.requirement_feasibility_reviews fr WHERE fr.requirement_id = r.id),
    'commercial_records', (SELECT count(*) FROM public.sales_commercial_records sc WHERE sc.requirement_id = r.id),
    'baselines', (SELECT count(*) FROM public.requirement_baselines rb WHERE rb.requirement_id = r.id),
    'change_requests', (SELECT count(*) FROM public.requirement_change_requests rc WHERE rc.requirement_id = r.id),
    'project_links', (SELECT count(*) FROM public.projects p JOIN public.requirement_baselines rb ON rb.id = p.requirement_baseline_id WHERE rb.requirement_id = r.id),
    'handover_links', (SELECT count(*) FROM public.sales_project_handovers sh JOIN public.requirement_baselines rb ON rb.id = sh.baseline_id WHERE rb.requirement_id = r.id),
    'portal_shared_items', (SELECT count(*) FROM public.customer_portal_shares ps WHERE ps.entity_id = r.id),
    'activity_history', (SELECT count(*) FROM public.activity_log al WHERE al.entity_id = r.id)
  ) AS dependencies
FROM candidate_requirements AS r
UNION ALL
SELECT
  'sales_opportunity'::text AS candidate_type,
  o.id AS candidate_id,
  o.opportunity_number AS candidate_key,
  o.name AS candidate_name,
  o.status::text AS candidate_status,
  o.customer_id,
  NULL::uuid AS opportunity_id,
  o.created_at,
  jsonb_build_object(
    'stage', o.stage,
    'requirements', (SELECT count(*) FROM public.customer_requirements cr WHERE cr.opportunity_id = o.id),
    'master_specifications', (SELECT count(*) FROM public.master_specifications ms WHERE ms.opportunity_id = o.id),
    'nda_records', (SELECT count(*) FROM public.sales_nda_records nda WHERE nda.opportunity_id = o.id),
    'document_locations', (SELECT count(*) FROM public.sales_opportunity_document_locations dl WHERE dl.opportunity_id = o.id),
    'structured_drafts', (SELECT count(*) FROM public.sales_opportunity_structured_drafts sd WHERE sd.opportunity_id = o.id),
    'structured_requests', (SELECT count(*) FROM public.sales_opportunity_structured_draft_requests sr WHERE sr.opportunity_id = o.id),
    'structured_materializations', (SELECT count(*) FROM public.sales_opportunity_structured_draft_materializations sm WHERE sm.opportunity_id = o.id),
    'projects', (SELECT count(*) FROM public.projects p WHERE p.opportunity_id = o.id),
    'portal_shared_items', (SELECT count(*) FROM public.customer_portal_shares ps WHERE ps.entity_id = o.id),
    'activity_history', (SELECT count(*) FROM public.activity_log al WHERE al.entity_id = o.id)
  ) AS dependencies
FROM candidate_opportunities AS o
ORDER BY candidate_type, candidate_key;

-- Before considering a reversible archive proposal, separately inspect every
-- non-zero count above plus Drive nodes, Drive revisions, document registers,
-- structured revision locations, storage attempts, materialization audits and
-- private objects using their exact foreign-key rows. Stop on a retained-anchor,
-- non-draft status, shared relationship, or unsupported archive state.
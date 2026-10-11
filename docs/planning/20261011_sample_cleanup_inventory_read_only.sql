-- REVIEW-ONLY: Sample-data cleanup inventory. Do not execute any UPDATE, DELETE,
-- archive, trash, storage, policy, grant, or migration statement from this file.
--
-- Retained anchor: OPPORTUNITY-2026-0013 / MASTER-2026-0001 rev 1 and every
-- dependent structured-draft revision, receipt, audit, materialization, Drive
-- revision, register, and private object remain excluded from any future cleanup.
--
-- This query reports candidate labels and dependency counts only. It deliberately
-- has no mutation statement and does not rely on requested_by as a selector.

WITH candidate_opportunities AS (
  SELECT o.id, o.opportunity_number, o.name, o.created_at
  FROM public.sales_opportunities AS o
  WHERE (o.name ILIKE '%SAMPLE ONLY%' OR o.name ILIKE '%SYNTHETIC ONLY%')
    AND o.opportunity_number <> 'OPPORTUNITY-2026-0013'
), candidate_projects AS (
  SELECT p.id, p.project_code, p.name, p.created_at
  FROM public.projects AS p
  WHERE p.name ILIKE '%SAMPLE ONLY%' OR p.name ILIKE '%SYNTHETIC ONLY%'
)
SELECT
  'sales_opportunity'::text AS candidate_type,
  o.id AS candidate_id,
  o.opportunity_number AS candidate_key,
  o.name AS candidate_name,
  o.created_at,
  (SELECT count(*) FROM public.master_specifications ms WHERE ms.opportunity_id = o.id) AS master_specifications,
  (SELECT count(*) FROM public.customer_requirements cr WHERE cr.opportunity_id = o.id) AS customer_requirements,
  (SELECT count(*) FROM public.sales_opportunity_document_locations dl WHERE dl.opportunity_id = o.id) AS document_locations,
  (SELECT count(*) FROM public.sales_opportunity_structured_drafts sd WHERE sd.opportunity_id = o.id) AS structured_drafts,
  (SELECT count(*) FROM public.sales_opportunity_structured_draft_requests sr WHERE sr.opportunity_id = o.id) AS structured_requests,
  (SELECT count(*) FROM public.sales_opportunity_structured_draft_materializations sm WHERE sm.opportunity_id = o.id) AS structured_materializations,
  (SELECT count(*) FROM public.sales_project_handovers sh JOIN public.requirement_baselines rb ON rb.id = sh.baseline_id WHERE rb.opportunity_id = o.id) AS project_handovers
FROM candidate_opportunities AS o
UNION ALL
SELECT
  'project'::text,
  p.id,
  p.project_code,
  p.name,
  p.created_at,
  0, 0, 0, 0, 0, 0,
  (SELECT count(*) FROM public.project_tasks pt WHERE pt.project_id = p.id)
FROM candidate_projects AS p
ORDER BY candidate_type, candidate_key;

-- Before considering a reversible archive proposal, separately inspect every
-- non-zero count above plus Drive nodes, Drive revisions, document registers,
-- structured revision locations, storage attempts, and audits using their exact
-- foreign-key rows. Stop on a retained-anchor reference or unsupported archive state.
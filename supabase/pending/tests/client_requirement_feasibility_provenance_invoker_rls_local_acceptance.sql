-- LOCAL DISPOSABLE SYNTHETIC RLS MECHANIC ONLY. It uses the verified shared
-- SELECT predicate shape (has_permission(auth.uid(), 'sales.view') OR
-- has_permission(auth.uid(), 'engineering.view') OR has_role(auth.uid(),
-- 'admin')) but does not establish managed policy, JWT, or grant acceptance.
\set ON_ERROR_STOP on
BEGIN;

CREATE ROLE provenance_owner NOLOGIN;
CREATE ROLE provenance_nonowner NOLOGIN;
GRANT USAGE ON SCHEMA public TO provenance_owner, provenance_nonowner;
GRANT SELECT ON public.requirement_feasibility_reviews, public.requirement_feasibility_review_provenance TO provenance_owner, provenance_nonowner;
GRANT SELECT ON public.customer_requirements, public.customer_requirement_revisions, public.master_specifications, public.master_specification_versions TO provenance_owner, provenance_nonowner;

ALTER TABLE public.requirement_feasibility_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_requirements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_requirement_revisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.master_specifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.master_specification_versions ENABLE ROW LEVEL SECURITY;

CREATE POLICY local_visible_review ON public.requirement_feasibility_reviews
  FOR SELECT TO provenance_owner, provenance_nonowner USING (true);
CREATE POLICY local_visible_requirement ON public.customer_requirements
  FOR SELECT TO provenance_owner, provenance_nonowner USING (true);
CREATE POLICY local_visible_revision ON public.customer_requirement_revisions
  FOR SELECT TO provenance_owner USING (true);
CREATE POLICY local_hidden_revision ON public.customer_requirement_revisions
  FOR SELECT TO provenance_nonowner USING (false);
CREATE POLICY local_visible_specification ON public.master_specifications
  FOR SELECT TO provenance_owner USING (true);
CREATE POLICY local_hidden_specification ON public.master_specifications
  FOR SELECT TO provenance_nonowner USING (false);
CREATE POLICY local_visible_version ON public.master_specification_versions
  FOR SELECT TO provenance_owner USING (true);
CREATE POLICY local_hidden_version ON public.master_specification_versions
  FOR SELECT TO provenance_nonowner USING (false);

INSERT INTO public.requirement_feasibility_reviews (
  id, requirement_id, department_id, reviewer_user_id, status, created_by,
  source_revision_id, source_revision_number,
  master_specification_version_id, master_specification_version_number,
  applicable_workstreams
) VALUES (
  '00000000-0000-4000-8000-000000000085',
  '00000000-0000-4000-8000-000000000080',
  '00000000-0000-4000-8000-000000000060',
  '00000000-0000-4000-8000-000000000062', 'pending',
  '00000000-0000-4000-8000-000000000050',
  '00000000-0000-4000-8000-000000000081', 1,
  '00000000-0000-4000-8000-000000000071', 1,
  '["HARDWARE"]'::jsonb
);

SET LOCAL ROLE provenance_owner;
DO $owner$
DECLARE v_row record;
BEGIN
  SELECT * INTO v_row FROM public.requirement_feasibility_review_provenance
  WHERE review_id = '00000000-0000-4000-8000-000000000085';
  IF v_row.provenance_status <> 'AVAILABLE'
     OR v_row.source_revision_id IS DISTINCT FROM '00000000-0000-4000-8000-000000000081'::uuid
     OR v_row.master_specification_version_id IS DISTINCT FROM '00000000-0000-4000-8000-000000000071'::uuid THEN
    RAISE EXCEPTION 'LOCAL_CASE_FAIL owner invoker did not receive exact visible provenance';
  END IF;
END;
$owner$;
RESET ROLE;

SET LOCAL ROLE provenance_nonowner;
DO $nonowner$
DECLARE v_row record;
BEGIN
  BEGIN
    PERFORM 1 FROM public.customer_requirement_revisions
    WHERE id = '00000000-0000-4000-8000-000000000081';
    IF FOUND THEN
      RAISE EXCEPTION 'LOCAL_CASE_FAIL direct joined-table RLS unexpectedly exposed a row';
    END IF;
  END;

  SELECT * INTO v_row FROM public.requirement_feasibility_review_provenance
  WHERE review_id = '00000000-0000-4000-8000-000000000085';
  IF FOUND THEN
    RAISE EXCEPTION 'LOCAL_CASE_FAIL hidden joined rows bypassed invoker RLS or leaked a source-existence oracle';
  END IF;
END;
$nonowner$;
RESET ROLE;

REVOKE SELECT ON public.requirement_feasibility_review_provenance FROM provenance_nonowner;
SET LOCAL ROLE provenance_nonowner;
DO $denied$
BEGIN
  BEGIN
    PERFORM 1 FROM public.requirement_feasibility_review_provenance;
    RAISE EXCEPTION 'LOCAL_CASE_FAIL view access unexpectedly succeeded without fixture-only SELECT grant';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END;
$denied$;
RESET ROLE;

RAISE NOTICE 'FEASIBILITY_PROVENANCE_INVOKER_RLS_LOCAL_PASS owner_available=1 nonowner_hidden=1 direct_join_denied=1 view_grant_denied=1';
ROLLBACK;
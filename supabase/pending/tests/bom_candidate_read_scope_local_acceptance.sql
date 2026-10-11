-- LOCAL DISPOSABLE CALLER-RLS PROJECTION ACCEPTANCE ONLY.
\set ON_ERROR_STOP on
BEGIN;
INSERT INTO public.customers VALUES ('40000000-0000-4000-8000-000000000010');
INSERT INTO public.sales_opportunities VALUES ('40000000-0000-4000-8000-000000000011', '40000000-0000-4000-8000-000000000010');
INSERT INTO public.customer_requirements VALUES ('40000000-0000-4000-8000-000000000012', '40000000-0000-4000-8000-000000000010', '40000000-0000-4000-8000-000000000011');
INSERT INTO public.requirement_baselines VALUES ('40000000-0000-4000-8000-000000000013', '40000000-0000-4000-8000-000000000012', 'project_initiated', '40000000-0000-4000-8000-000000000001', clock_timestamp());
INSERT INTO public.departments VALUES ('40000000-0000-4000-8000-000000000014', 'HARDWARE', true), ('40000000-0000-4000-8000-000000000015', 'PURCHASE', true), ('40000000-0000-4000-8000-000000000016', 'FIRMWARE', true);
INSERT INTO public.employees VALUES
  ('40000000-0000-4000-8000-000000000021', '40000000-0000-4000-8000-000000000001', 'ACTIVE'),
  ('40000000-0000-4000-8000-000000000022', '40000000-0000-4000-8000-000000000002', 'ACTIVE'),
  ('40000000-0000-4000-8000-000000000023', '40000000-0000-4000-8000-000000000003', 'ACTIVE'),
  ('40000000-0000-4000-8000-000000000024', '40000000-0000-4000-8000-000000000004', 'ACTIVE'),
  ('40000000-0000-4000-8000-000000000025', '40000000-0000-4000-8000-000000000005', 'ACTIVE');
INSERT INTO public.employee_departments VALUES
  ('40000000-0000-4000-8000-000000000021', '40000000-0000-4000-8000-000000000014'),
  ('40000000-0000-4000-8000-000000000022', '40000000-0000-4000-8000-000000000014'),
  ('40000000-0000-4000-8000-000000000023', '40000000-0000-4000-8000-000000000015'),
  ('40000000-0000-4000-8000-000000000024', '40000000-0000-4000-8000-000000000016');
INSERT INTO public.access_roles VALUES ('40000000-0000-4000-8000-000000000026', 'Local Hardware reader'), ('40000000-0000-4000-8000-000000000027', 'Local Purchase reader');
INSERT INTO public.employee_access_roles VALUES ('40000000-0000-4000-8000-000000000022', '40000000-0000-4000-8000-000000000026'), ('40000000-0000-4000-8000-000000000023', '40000000-0000-4000-8000-000000000027');
INSERT INTO public.access_role_permissions(role_id, permission_id) SELECT '40000000-0000-4000-8000-000000000026', id FROM public.permissions WHERE key = 'engineering.approve';
INSERT INTO public.permissions(key, module_key, label, description) VALUES ('procurement.view', 'procurement', 'View purchasing handoffs', 'Local pending read fixture.') ON CONFLICT (key) DO NOTHING;
INSERT INTO public.access_role_permissions(role_id, permission_id) SELECT '40000000-0000-4000-8000-000000000027', id FROM public.permissions WHERE key = 'procurement.view';
INSERT INTO public.projects VALUES ('40000000-0000-4000-8000-000000000031', '40000000-0000-4000-8000-000000000010', '40000000-0000-4000-8000-000000000011', '40000000-0000-4000-8000-000000000013', '40000000-0000-4000-8000-000000000021');
INSERT INTO public.project_boms VALUES ('40000000-0000-4000-8000-000000000032', '40000000-0000-4000-8000-000000000031');
INSERT INTO public.project_team_members VALUES
  ('40000000-0000-4000-8000-000000000041', '40000000-0000-4000-8000-000000000031', '40000000-0000-4000-8000-000000000021'),
  ('40000000-0000-4000-8000-000000000042', '40000000-0000-4000-8000-000000000031', '40000000-0000-4000-8000-000000000022'),
  ('40000000-0000-4000-8000-000000000043', '40000000-0000-4000-8000-000000000031', '40000000-0000-4000-8000-000000000023');
INSERT INTO public.sales_project_handovers VALUES ('40000000-0000-4000-8000-000000000033', '40000000-0000-4000-8000-000000000013', '40000000-0000-4000-8000-000000000031', 'completed');
-- A distinct project where the same Hardware and Purchase callers are not team members.
INSERT INTO public.projects VALUES ('40000000-0000-4000-8000-000000000034', '40000000-0000-4000-8000-000000000010', '40000000-0000-4000-8000-000000000011', '40000000-0000-4000-8000-000000000013', '40000000-0000-4000-8000-000000000021');
INSERT INTO public.project_boms VALUES ('40000000-0000-4000-8000-000000000035', '40000000-0000-4000-8000-000000000034');
INSERT INTO public.project_team_members VALUES ('40000000-0000-4000-8000-000000000044', '40000000-0000-4000-8000-000000000034', '40000000-0000-4000-8000-000000000021');
INSERT INTO public.sales_project_handovers VALUES ('40000000-0000-4000-8000-000000000036', '40000000-0000-4000-8000-000000000013', '40000000-0000-4000-8000-000000000034', 'completed');

SELECT set_config('request.jwt.claim.sub', '40000000-0000-4000-8000-000000000001', false);
CREATE TEMP TABLE pending_candidate AS SELECT candidate_id FROM public.submit_component_candidate('40000000-0000-4000-8000-000000000031', '40000000-0000-4000-8000-000000000032', jsonb_build_object('categoryId', 'local', 'name', 'Pending read', 'partNumber', 'READ-PENDING'), '40000000-0000-4000-8000-000000000051');
CREATE TEMP TABLE pending_revision AS SELECT id AS revision_id FROM public.component_candidate_payload_revisions WHERE candidate_id = (SELECT candidate_id FROM pending_candidate);
CREATE TEMP TABLE approved_candidate AS SELECT candidate_id FROM public.submit_component_candidate('40000000-0000-4000-8000-000000000031', '40000000-0000-4000-8000-000000000032', jsonb_build_object('categoryId', 'local', 'name', 'Approved read', 'partNumber', 'READ-APPROVED', 'cost', 42, 'supplier', 'Hidden supplier'), '40000000-0000-4000-8000-000000000052');
CREATE TEMP TABLE approved_revision AS SELECT id AS revision_id FROM public.component_candidate_payload_revisions WHERE candidate_id = (SELECT candidate_id FROM approved_candidate);
CREATE TEMP TABLE project_b_candidate AS SELECT candidate_id FROM public.submit_component_candidate('40000000-0000-4000-8000-000000000034', '40000000-0000-4000-8000-000000000035', jsonb_build_object('categoryId', 'local', 'name', 'Project B hidden', 'partNumber', 'READ-PROJECT-B'), '40000000-0000-4000-8000-000000000054');
CREATE TEMP TABLE project_b_revision AS SELECT id AS revision_id FROM public.component_candidate_payload_revisions WHERE candidate_id = (SELECT candidate_id FROM project_b_candidate);
SELECT set_config('request.jwt.claim.sub', '40000000-0000-4000-8000-000000000002', false);
SELECT * FROM public.decide_component_candidate((SELECT candidate_id FROM approved_candidate), (SELECT revision_id FROM approved_revision), 'APPROVE', 'Approved Hardware handoff', '40000000-0000-4000-8000-000000000053') \g /dev/null
DELETE FROM public.project_team_members WHERE id = '40000000-0000-4000-8000-000000000044';
COMMIT;

-- Local-only selective joined-row policies model caller-RLS suppression without changing pending production policies.
ALTER TABLE public.component_candidate_payload_revisions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.component_candidate_decisions FORCE ROW LEVEL SECURITY;
CREATE POLICY local_read_scope_hide_pinned_revision ON public.component_candidate_payload_revisions AS RESTRICTIVE FOR SELECT TO authenticated
  USING (NOT (auth.uid() = '40000000-0000-4000-8000-000000000002'::uuid AND candidate_id = '40000000-0000-4000-8000-0000000000a2'::uuid));
CREATE POLICY local_read_scope_hide_approved_decision ON public.component_candidate_decisions AS RESTRICTIVE FOR SELECT TO authenticated
  USING (NOT (auth.uid() = '40000000-0000-4000-8000-000000000003'::uuid AND candidate_id = '40000000-0000-4000-8000-0000000000a2'::uuid));

SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '40000000-0000-4000-8000-000000000001', false);
DO $$ BEGIN
  IF (SELECT count(*) FROM public.component_candidate_submitter_read) <> 2 OR EXISTS (SELECT 1 FROM public.component_candidate_hardware_read) OR EXISTS (SELECT 1 FROM public.component_candidate_purchase_handoff_read) OR EXISTS (SELECT 1 FROM public.component_candidate_submitter_read WHERE project_id = '40000000-0000-4000-8000-000000000034'::uuid) THEN RAISE EXCEPTION 'Submitter read scope exposed or hid candidates incorrectly'; END IF;
END $$;
SELECT set_config('request.jwt.claim.sub', '40000000-0000-4000-8000-000000000002', false);
DO $$ BEGIN
  IF (SELECT count(*) FROM public.component_candidate_hardware_read) <> 2 OR EXISTS (SELECT 1 FROM public.component_candidate_hardware_read WHERE candidate_id = '40000000-0000-4000-8000-0000000000a2'::uuid) OR EXISTS (SELECT 1 FROM public.component_candidate_payload_revisions WHERE candidate_id = '40000000-0000-4000-8000-0000000000a2'::uuid) OR EXISTS (SELECT 1 FROM public.component_candidate_hardware_read WHERE project_id = '40000000-0000-4000-8000-000000000034'::uuid) OR EXISTS (SELECT 1 FROM public.component_candidate_purchase_handoff_read) THEN RAISE EXCEPTION 'Hardware reader scope exposed hidden revision, cross-project, or fallback candidate data'; END IF;
END $$;
SELECT set_config('request.jwt.claim.sub', '40000000-0000-4000-8000-000000000003', false);
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.component_candidate_purchase_handoff_read) OR EXISTS (SELECT 1 FROM public.component_candidate_decisions WHERE candidate_id = '40000000-0000-4000-8000-0000000000a2'::uuid) THEN RAISE EXCEPTION 'Purchase handoff fell back when its approving decision was caller-RLS hidden'; END IF;
END $$;
RESET ROLE;
DROP POLICY local_read_scope_hide_pinned_revision ON public.component_candidate_payload_revisions;
DROP POLICY local_read_scope_hide_approved_decision ON public.component_candidate_decisions;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '40000000-0000-4000-8000-000000000002', false);
DO $$ BEGIN
  IF (SELECT count(*) FROM public.component_candidate_hardware_read) <> 2 OR (SELECT count(*) FROM public.component_candidate_hardware_read WHERE candidate_id = '40000000-0000-4000-8000-0000000000a2'::uuid) <> 1 OR (SELECT count(*) FROM public.component_candidate_hardware_read WHERE project_id = '40000000-0000-4000-8000-000000000034'::uuid) <> 0 THEN RAISE EXCEPTION 'Hardware history cardinality, exact revision, or cross-project scope failed'; END IF;
END $$;
SELECT set_config('request.jwt.claim.sub', '40000000-0000-4000-8000-000000000003', false);
DO $$ BEGIN
  IF (SELECT count(*) FROM public.component_candidate_purchase_handoff_read) <> 1 OR EXISTS (SELECT 1 FROM public.component_candidate_purchase_handoff_read WHERE candidate_id IN ('40000000-0000-4000-8000-000000000051'::uuid, (SELECT candidate_id FROM project_b_candidate))) OR EXISTS (SELECT 1 FROM public.component_candidate_purchase_handoff_read WHERE row_to_json(component_candidate_purchase_handoff_read)::text LIKE '%Hidden supplier%') OR EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'component_candidate_purchase_handoff_read' AND column_name IN ('cost', 'supplier', 'supplier_url', 'datasheet_url', 'notes', 'submitted_by', 'decided_by')) THEN RAISE EXCEPTION 'Purchase handoff leaked non-approved, cross-project, or private payload data'; END IF;
END $$;
SELECT set_config('request.jwt.claim.sub', '40000000-0000-4000-8000-000000000004', false);
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.component_candidate_submitter_read) OR EXISTS (SELECT 1 FROM public.component_candidate_hardware_read) OR EXISTS (SELECT 1 FROM public.component_candidate_purchase_handoff_read) THEN RAISE EXCEPTION 'Cross-department caller received a projection'; END IF;
END $$;
SELECT set_config('request.jwt.claim.sub', '40000000-0000-4000-8000-000000000005', false);
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.component_candidate_submitter_read) OR EXISTS (SELECT 1 FROM public.component_candidate_hardware_read) OR EXISTS (SELECT 1 FROM public.component_candidate_purchase_handoff_read) THEN RAISE EXCEPTION 'Unrelated caller received a projection'; END IF;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub', '40000000-0000-4000-8000-000000000003', false);
DELETE FROM public.project_team_members WHERE employee_id = '40000000-0000-4000-8000-000000000023';
SET ROLE authenticated;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM public.component_candidate_purchase_handoff_read) THEN RAISE EXCEPTION 'Revoked project membership retained purchase read'; END IF; END $$;
RESET ROLE;
ROLLBACK;
SELECT 'BOM_CANDIDATE_READ_SCOPE_LOCAL_ACCEPTANCE_PASS=true';
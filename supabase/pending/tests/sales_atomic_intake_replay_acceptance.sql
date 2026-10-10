-- SOURCE-ONLY, UNEXECUTED ISOLATED ACCEPTANCE SPECIFICATION. DO NOT RUN
-- against preview, shared, or production. Apply only to a disposable isolated
-- database after the companion pending contract has undergone review.
--
-- Required isolated fixtures (not created here): sales_manager_user_id,
-- non_sales_user_id, customer_id, contact_id, enquiry_id, other_customer_id,
-- request_key, replay_request_key, and conflict_request_key. The customer,
-- contact and enquiry must be existing records. The active non-admin Sales
-- manager must prove current global sales.manage RLS visibility for each valid
-- source; no customer/account ownership is asserted. The non-Sales user must
-- lack sales.manage. This script creates no persistent fixture.
--
-- Source evidence: current policies are "Sales teams view customers/customer
-- contacts/enquiries" and the sales.manage write policies in
-- `supabase/migrations/20260923173813_447b78e0-6a60-4d69-875a-6b5c7d32691f.sql`.
-- Numbering evidence: deployed public.next_business_number locks its active
-- document_numbering_config row, while sales_opportunities_assign_business_code
-- assigns an opportunity number when the inserted value is NULL/blank. This
-- harness must prove concurrent behavior; source inspection alone is insufficient.

\set ON_ERROR_STOP on
BEGIN;
SELECT set_config('request.jwt.claim.sub', :'sales_manager_user_id', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
SELECT set_config('sales_intake.test.sales_manager_user_id', :'sales_manager_user_id', true);
SELECT set_config('sales_intake.test.non_sales_user_id', :'non_sales_user_id', true);
SELECT set_config('sales_intake.test.customer_id', :'customer_id', true);
SELECT set_config('sales_intake.test.contact_id', :'contact_id', true);
SELECT set_config('sales_intake.test.enquiry_id', :'enquiry_id', true);
SELECT set_config('sales_intake.test.other_customer_id', :'other_customer_id', true);
SELECT set_config('sales_intake.test.request_key', :'request_key', true);
SELECT set_config('sales_intake.test.conflict_request_key', :'conflict_request_key', true);

CREATE TEMP TABLE sales_intake_first AS
SELECT * FROM public.create_sales_opportunity_with_initial_master_specification(
  current_setting('sales_intake.test.customer_id')::uuid,
  current_setting('sales_intake.test.contact_id')::uuid,
  current_setting('sales_intake.test.enquiry_id')::uuid,
  jsonb_build_object(
    'name', 'Isolated atomic intake', 'application', 'Vehicle tracking', 'productType', 'Tracker',
    'primarySalesOwnerUserId', NULL, 'ndaRequired', false, 'estimatedVolume', '20',
    'targetTimeline', 'Q4', 'priority', 'medium', 'nextAction', 'Review', 'nextActionDate', NULL,
    'masterSpecification', jsonb_build_object(
      'changeSummary', 'Initial intake', 'proposedName', 'Isolated atomic intake',
      'customerOrInternalOwner', 'Fixture customer', 'industryApplication', 'Automotive',
      'productFamily', 'Tracker', 'developmentScope', 'Prototype scope',
      'workstreams', jsonb_build_array('HARDWARE'), 'requirementSummary', 'Track test vehicles',
      'powerAndUnits', '12V', 'interfaces', 'CAN', 'connectivityAndGnss', 'LTE/GNSS',
      'environmentAndIp', 'IP67', 'volumes', '20', 'schedule', 'Q4',
      'requestedStandards', 'TBC', 'exclusions', 'None'
    )
  ),
  current_setting('sales_intake.test.request_key')::uuid
);
DO $first$
BEGIN
  IF (SELECT count(*) FROM sales_intake_first) <> 1 OR (SELECT replayed FROM sales_intake_first) THEN
    RAISE EXCEPTION 'Expected one initial non-replayed atomic intake result';
  END IF;
  IF (SELECT count(*) FROM public.sales_opportunity_intake_receipts
      WHERE request_key = current_setting('sales_intake.test.request_key')::uuid) <> 1 THEN
    RAISE EXCEPTION 'Expected one intake receipt';
  END IF;
END;
$first$;

CREATE TEMP TABLE sales_intake_replay AS
SELECT * FROM public.create_sales_opportunity_with_initial_master_specification(
  current_setting('sales_intake.test.customer_id')::uuid,
  current_setting('sales_intake.test.contact_id')::uuid,
  current_setting('sales_intake.test.enquiry_id')::uuid,
  jsonb_build_object(
    'nextActionDate', NULL, 'nextAction', 'Review', 'priority', 'medium', 'targetTimeline', 'Q4',
    'estimatedVolume', '20', 'ndaRequired', false, 'primarySalesOwnerUserId', NULL,
    'productType', 'Tracker', 'application', 'Vehicle tracking', 'name', 'Isolated atomic intake',
    'masterSpecification', jsonb_build_object(
      'exclusions', 'None', 'requestedStandards', 'TBC', 'schedule', 'Q4', 'volumes', '20',
      'environmentAndIp', 'IP67', 'connectivityAndGnss', 'LTE/GNSS', 'interfaces', 'CAN',
      'powerAndUnits', '12V', 'requirementSummary', 'Track test vehicles',
      'workstreams', jsonb_build_array('HARDWARE'), 'developmentScope', 'Prototype scope',
      'productFamily', 'Tracker', 'industryApplication', 'Automotive',
      'customerOrInternalOwner', 'Fixture customer', 'proposedName', 'Isolated atomic intake',
      'changeSummary', 'Initial intake'
    )
  ), current_setting('sales_intake.test.request_key')::uuid
);
DO $replay$
BEGIN
  IF NOT (SELECT replayed FROM sales_intake_replay)
     OR (SELECT opportunity_id FROM sales_intake_replay) IS DISTINCT FROM (SELECT opportunity_id FROM sales_intake_first)
     OR (SELECT master_specification_id FROM sales_intake_replay) IS DISTINCT FROM (SELECT master_specification_id FROM sales_intake_first) THEN
    RAISE EXCEPTION 'Exact request replay must return the original atomic result';
  END IF;
END;
$replay$;

-- Required precondition: prove the active non-admin Sales manager has the
-- currently intended global RLS source access before exercising the RPC.
DO $manager_source_access$
BEGIN
  SET LOCAL ROLE authenticated;
  IF NOT EXISTS (SELECT 1 FROM public.customers WHERE id = current_setting('sales_intake.test.customer_id')::uuid)
     OR NOT EXISTS (SELECT 1 FROM public.customer_contacts WHERE id = current_setting('sales_intake.test.contact_id')::uuid)
     OR NOT EXISTS (SELECT 1 FROM public.sales_enquiries WHERE id = current_setting('sales_intake.test.enquiry_id')::uuid) THEN
    RAISE EXCEPTION 'Active non-admin Sales manager cannot read the required valid sources';
  END IF;
  RESET ROLE;
END;
$manager_source_access$;

-- Real role-bound non-Sales denial: no forged JWT-only claim is accepted as evidence.
DO $role_bound$
DECLARE
  v_before_receipts bigint;
  v_non_sales_user uuid := current_setting('sales_intake.test.non_sales_user_id')::uuid;
BEGIN
  SELECT count(*) INTO v_before_receipts FROM public.sales_opportunity_intake_receipts;
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claim.sub', v_non_sales_user::text, true);
  BEGIN
    PERFORM 1 FROM public.sales_opportunity_intake_receipts;
    RAISE EXCEPTION 'Expected direct receipt SELECT privilege denial';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLSTATE <> '42501' THEN RAISE EXCEPTION 'Expected SQLSTATE 42501, received %', SQLSTATE; END IF;
  END;
  BEGIN
    PERFORM public.lookup_sales_opportunity_intake_receipt(current_setting('sales_intake.test.request_key')::uuid);
    RAISE EXCEPTION 'Expected non-Sales receipt lookup denial';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLSTATE <> '42501' THEN RAISE EXCEPTION 'Expected SQLSTATE 42501, received %', SQLSTATE; END IF;
  END;
  RESET ROLE;
  IF (SELECT count(*) FROM public.sales_opportunity_intake_receipts) <> v_before_receipts THEN
    RAISE EXCEPTION 'Role-bound denial mutated intake receipts';
  END IF;
END;
$role_bound$;

-- Required isolated cases, intentionally not claimed as executed here:
-- 1. Same actor/key with changed payload, changed source, and other actor all
--    fail (SQLSTATE 23505) and leave every original row untouched.
-- 2. Wrong contact/customer, enquiry/customer/contact, inactive contact, and
--    missing customer all fail (22023) with no opportunity/spec/audit/receipt.
-- 3. Force each opportunity/spec/header/version/audit/receipt failure and prove
--    the complete transaction rolls back; no partial business number survives.
-- 4. Two distinct authenticated sessions race the same key and converge to one
--    receipt/result; different keys create independently only when intended.
-- 5. Revoke sales.manage after target locks in a two-session harness; no replay
--    result/write may return after the post-lock/post-receipt authorization checks.
-- 6. Verify owner-only receipt lookup/read, direct mutation denial for every
--    affected object, and actual application-RPC transport (not JWT settings).
-- 7. Run two active non-admin Sales-manager sessions against valid currently
--    RLS-visible sources: same request key converges to one receipt/result,
--    and different request keys prove the row-locked number allocator has no
--    duplicate opportunity/Master Specification number under concurrent calls.
--
-- Compatibility transition, not an execution instruction: only after the
-- companion contract is installed and all isolated acceptance passes may the
-- combined intake route call the protected atomic action. Existing legacy
-- opportunity/specification paths remain unchanged; their direct-write denial
-- is a separate pending controlled-write transition.
ROLLBACK;

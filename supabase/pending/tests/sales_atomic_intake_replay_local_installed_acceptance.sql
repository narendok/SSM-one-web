-- LOCAL DISPOSABLE INSTALLED-CONTRACT ACCEPTANCE ONLY. The runner creates the
-- fixture, installs the pending proposal, and grants its two actions to the
-- fixture role only. This does not prove managed RLS or HTTP/JWT transport.
\set ON_ERROR_STOP on
BEGIN;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
INSERT INTO public.sales_test_permissions VALUES
  ('00000000-0000-4000-8000-000000000001', true),
  ('00000000-0000-4000-8000-000000000002', false);
INSERT INTO public.customers VALUES ('00000000-0000-4000-8000-000000000010', 'Disposable customer');
INSERT INTO public.customer_contacts VALUES ('00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000010', true);
INSERT INTO public.sales_enquiries VALUES ('00000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000011');
SELECT set_config('sales_intake.test.customer_id', '00000000-0000-4000-8000-000000000010', true);
SELECT set_config('sales_intake.test.contact_id', '00000000-0000-4000-8000-000000000011', true);
SELECT set_config('sales_intake.test.enquiry_id', '00000000-0000-4000-8000-000000000012', true);
SELECT set_config('sales_intake.test.request_key', '00000000-0000-4000-8000-000000000090', true);

CREATE TEMP TABLE first_result AS
SELECT * FROM public.create_sales_opportunity_with_initial_master_specification(
  current_setting('sales_intake.test.customer_id')::uuid, current_setting('sales_intake.test.contact_id')::uuid,
  current_setting('sales_intake.test.enquiry_id')::uuid,
      '{"name":"Local atomic intake","application":"Vehicle tracking","productType":"Tracker","primarySalesOwnerUserId":null,"ndaRequired":false,"estimatedVolume":"20","targetTimeline":"Q4","priority":"medium","nextAction":"Review","nextActionDate":null,"masterSpecification":{"changeSummary":"Initial intake","proposedName":"Local atomic intake","customerOrInternalOwner":"Disposable customer","industryApplication":"Automotive","productFamily":"Tracker","developmentScope":"Prototype scope","workstreams":["HARDWARE"],"requirementSummary":"Track test vehicles","powerAndUnits":"12V","interfaces":"CAN","connectivityAndGnss":"LTE/GNSS","environmentAndIp":"IP67","volumes":"20","schedule":"Q4","requestedStandards":"TBC","exclusions":"None"}}'::jsonb,
  current_setting('sales_intake.test.request_key')::uuid
);
DO $first$
BEGIN
  IF (SELECT count(*) FROM first_result) <> 1 OR (SELECT replayed FROM first_result) THEN
    RAISE EXCEPTION 'Expected one non-replayed create';
  END IF;
  IF (SELECT count(*) FROM public.sales_opportunity_intake_receipts) <> 1 THEN RAISE EXCEPTION 'Expected one receipt'; END IF;
END;
$first$;
-- Exact replay returns the same persisted IDs.
CREATE TEMP TABLE replay_result AS SELECT * FROM public.create_sales_opportunity_with_initial_master_specification(
  current_setting('sales_intake.test.customer_id')::uuid, current_setting('sales_intake.test.contact_id')::uuid, current_setting('sales_intake.test.enquiry_id')::uuid,
  '{"nextActionDate":null,"nextAction":"Review","priority":"medium","targetTimeline":"Q4","estimatedVolume":"20","ndaRequired":false,"primarySalesOwnerUserId":null,"productType":"Tracker","application":"Vehicle tracking","name":"Local atomic intake","masterSpecification":{"exclusions":"None","requestedStandards":"TBC","schedule":"Q4","volumes":"20","environmentAndIp":"IP67","connectivityAndGnss":"LTE/GNSS","interfaces":"CAN","powerAndUnits":"12V","requirementSummary":"Track test vehicles","workstreams":["HARDWARE"],"developmentScope":"Prototype scope","productFamily":"Tracker","industryApplication":"Automotive","customerOrInternalOwner":"Disposable customer","proposedName":"Local atomic intake","changeSummary":"Initial intake"}}'::jsonb,
  current_setting('sales_intake.test.request_key')::uuid);
DO $replay$
BEGIN
  IF NOT (SELECT replayed FROM replay_result) OR (SELECT opportunity_id FROM replay_result) IS DISTINCT FROM (SELECT opportunity_id FROM first_result) THEN
    RAISE EXCEPTION 'Exact replay did not return the original receipt';
  END IF;
END;
$replay$;
-- A changed payload, a different actor, and an invalid source each fail.
DO $denials$
DECLARE v_key uuid := current_setting('sales_intake.test.request_key')::uuid;
BEGIN
  BEGIN
    PERFORM public.create_sales_opportunity_with_initial_master_specification(current_setting('sales_intake.test.customer_id')::uuid, NULL, NULL,
      '{"name":"Changed local intake","application":null,"productType":null,"primarySalesOwnerUserId":null,"ndaRequired":false,"estimatedVolume":null,"targetTimeline":null,"priority":"medium","nextAction":null,"nextActionDate":null,"masterSpecification":{"changeSummary":"Initial intake","proposedName":"Local atomic intake","customerOrInternalOwner":"Disposable customer","industryApplication":"Automotive","productFamily":"Tracker","developmentScope":"Prototype scope","workstreams":["HARDWARE"],"requirementSummary":"Track test vehicles","powerAndUnits":"12V","interfaces":"CAN","connectivityAndGnss":"LTE/GNSS","environmentAndIp":"IP67","volumes":"20","schedule":"Q4","requestedStandards":"TBC","exclusions":"None"}}'::jsonb, v_key);
    RAISE EXCEPTION 'Expected changed payload conflict';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000002', true);
  BEGIN
    PERFORM public.lookup_sales_opportunity_intake_receipt(v_key);
    RAISE EXCEPTION 'Expected different actor denial';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
  BEGIN
    PERFORM public.create_sales_opportunity_with_initial_master_specification('00000000-0000-4000-8000-000000000099'::uuid, NULL, NULL,
      '{"name":"Invalid source","application":null,"productType":null,"primarySalesOwnerUserId":null,"ndaRequired":false,"estimatedVolume":null,"targetTimeline":null,"priority":"medium","nextAction":null,"nextActionDate":null,"masterSpecification":{"changeSummary":"Initial intake","proposedName":"Invalid source","customerOrInternalOwner":"Disposable customer","industryApplication":"Automotive","productFamily":"Tracker","developmentScope":"Prototype scope","workstreams":["HARDWARE"],"requirementSummary":"Track test vehicles","powerAndUnits":"12V","interfaces":"CAN","connectivityAndGnss":"LTE/GNSS","environmentAndIp":"IP67","volumes":"20","schedule":"Q4","requestedStandards":"TBC","exclusions":"None"}}'::jsonb, '00000000-0000-4000-8000-000000000091'::uuid);
    RAISE EXCEPTION 'Expected invalid source denial';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
END;
$denials$;
-- Local failpoints prove the transaction rolls back every inserted record.
DO $rollback$
DECLARE v_before bigint; v_after bigint;
BEGIN
  SELECT count(*) INTO v_before FROM public.sales_opportunities;
  PERFORM set_config('sales_intake.test.failpoint', 'activity_log', true);
  BEGIN
    PERFORM public.create_sales_opportunity_with_initial_master_specification(current_setting('sales_intake.test.customer_id')::uuid, NULL, NULL,
      '{"name":"Rollback local intake","application":null,"productType":null,"primarySalesOwnerUserId":null,"ndaRequired":false,"estimatedVolume":null,"targetTimeline":null,"priority":"medium","nextAction":null,"nextActionDate":null,"masterSpecification":{"changeSummary":"Initial intake","proposedName":"Rollback local intake","customerOrInternalOwner":"Disposable customer","industryApplication":"Automotive","productFamily":"Tracker","developmentScope":"Prototype scope","workstreams":["HARDWARE"],"requirementSummary":"Track test vehicles","powerAndUnits":"12V","interfaces":"CAN","connectivityAndGnss":"LTE/GNSS","environmentAndIp":"IP67","volumes":"20","schedule":"Q4","requestedStandards":"TBC","exclusions":"None"}}'::jsonb, '00000000-0000-4000-8000-000000000092'::uuid);
    RAISE EXCEPTION 'Expected rollback failpoint';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;
  SELECT count(*) INTO v_after FROM public.sales_opportunities;
  IF v_after <> v_before THEN RAISE EXCEPTION 'Rollback left an opportunity'; END IF;
END;
$rollback$;
-- Two-session race: run two independent psql invocations with the same valid
-- request key after this fixture is committed. The race driver must prove one
-- receipt/result; it is intentionally separate because this transaction ends
-- in ROLLBACK and PGlite/single-connection tests cannot prove concurrency.
ROLLBACK;
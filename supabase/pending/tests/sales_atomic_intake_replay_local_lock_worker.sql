-- Invoked by one independent local psql worker. It holds the contract's exact
-- request-key advisory lock until the controller proves it is waiting.
\set ON_ERROR_STOP on
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', false);
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
BEGIN;
SELECT pg_advisory_xact_lock(hashtextextended(:'request_key', 0));
UPDATE public.sales_intake_lock_wait_cases SET ready = true WHERE case_label = :'case_label';
COMMIT;
DO $wait$
DECLARE v_deadline timestamptz := clock_timestamp() + interval '15 seconds'; v_released boolean;
BEGIN
  LOOP
    SELECT released INTO v_released FROM public.sales_intake_lock_wait_cases WHERE case_label = :'case_label';
    IF v_released THEN RETURN; END IF;
    IF clock_timestamp() >= v_deadline THEN RAISE EXCEPTION 'Lock-wait release timeout'; END IF;
    PERFORM pg_sleep(0.02);
  END LOOP;
END;
$wait$;
SELECT * FROM public.create_sales_opportunity_with_initial_master_specification(
  '00000000-0000-4000-8000-000000000010'::uuid,
  '00000000-0000-4000-8000-000000000011'::uuid,
  '00000000-0000-4000-8000-000000000012'::uuid,
  '{"name":"Lock wait intake","application":"Vehicle tracking","productType":"Tracker","primarySalesOwnerUserId":null,"ndaRequired":false,"estimatedVolume":"20","targetTimeline":"Q4","priority":"medium","nextAction":"Review","nextActionDate":null,"masterSpecification":{"changeSummary":"Initial intake","proposedName":"Lock wait intake","customerOrInternalOwner":"Disposable customer","industryApplication":"Automotive","productFamily":"Tracker","developmentScope":"Prototype scope","workstreams":["HARDWARE"],"requirementSummary":"Track test vehicles","powerAndUnits":"12V","interfaces":"CAN","connectivityAndGnss":"LTE/GNSS","environmentAndIp":"IP67","volumes":"20","schedule":"Q4","requestedStandards":"TBC","exclusions":"None"}}'::jsonb,
  :'request_key'::uuid
);

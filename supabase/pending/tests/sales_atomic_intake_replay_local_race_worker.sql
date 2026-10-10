-- Invoked by exactly one independent local psql process. The barrier is backed
-- by durable committed state; the worker cannot call the intake action
-- until the assertion process has observed two ready sessions and released it.
\set ON_ERROR_STOP on
BEGIN;
SELECT set_config('request.jwt.claim.sub', :'actor_id', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
SELECT pg_advisory_xact_lock(hashtextextended('sales-intake-race:' || :'race_label', 0));
UPDATE public.sales_intake_race_barriers
SET ready_workers = ready_workers + 1
WHERE race_label = :'race_label' AND NOT released AND ready_workers < expected_workers;
DO $ready$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.sales_intake_race_barriers
    WHERE race_label = :'race_label' AND ready_workers BETWEEN 1 AND expected_workers
  ) THEN
    RAISE EXCEPTION 'Race worker could not register readiness';
  END IF;
END;
$ready$;
COMMIT;

-- Polling is bounded and conditioned on durable barrier state, rather than a
-- time delay that assumes the competing session started.
DO $wait$
DECLARE v_released boolean; v_deadline timestamptz := clock_timestamp() + interval '15 seconds';
BEGIN
  LOOP
    SELECT released INTO v_released FROM public.sales_intake_race_barriers WHERE race_label = :'race_label';
    IF v_released THEN EXIT; END IF;
    IF clock_timestamp() >= v_deadline THEN RAISE EXCEPTION 'Race barrier timeout for %', :'race_label'; END IF;
    PERFORM pg_sleep(0.02);
  END LOOP;
END;
$wait$;

WITH response AS (
  SELECT * FROM public.create_sales_opportunity_with_initial_master_specification(
  '00000000-0000-4000-8000-000000000010'::uuid,
  '00000000-0000-4000-8000-000000000011'::uuid,
  '00000000-0000-4000-8000-000000000012'::uuid,
  CASE :'payload_variant'
    WHEN 'base' THEN '{"name":"Race intake","application":"Vehicle tracking","productType":"Tracker","primarySalesOwnerUserId":null,"ndaRequired":false,"estimatedVolume":"20","targetTimeline":"Q4","priority":"medium","nextAction":"Review","nextActionDate":null,"masterSpecification":{"changeSummary":"Initial intake","proposedName":"Race intake","customerOrInternalOwner":"Disposable customer","industryApplication":"Automotive","productFamily":"Tracker","developmentScope":"Prototype scope","workstreams":["HARDWARE"],"requirementSummary":"Track test vehicles","powerAndUnits":"12V","interfaces":"CAN","connectivityAndGnss":"LTE/GNSS","environmentAndIp":"IP67","volumes":"20","schedule":"Q4","requestedStandards":"TBC","exclusions":"None"}}'::jsonb
    WHEN 'changed' THEN '{"name":"Changed race intake","application":"Vehicle tracking","productType":"Tracker","primarySalesOwnerUserId":null,"ndaRequired":false,"estimatedVolume":"20","targetTimeline":"Q4","priority":"medium","nextAction":"Review","nextActionDate":null,"masterSpecification":{"changeSummary":"Initial intake","proposedName":"Changed race intake","customerOrInternalOwner":"Disposable customer","industryApplication":"Automotive","productFamily":"Tracker","developmentScope":"Prototype scope","workstreams":["HARDWARE"],"requirementSummary":"Track test vehicles","powerAndUnits":"12V","interfaces":"CAN","connectivityAndGnss":"LTE/GNSS","environmentAndIp":"IP67","volumes":"20","schedule":"Q4","requestedStandards":"TBC","exclusions":"None"}}'::jsonb
    WHEN 'alternate' THEN '{"name":"Separate race intake","application":"Vehicle tracking","productType":"Tracker","primarySalesOwnerUserId":null,"ndaRequired":false,"estimatedVolume":"20","targetTimeline":"Q4","priority":"medium","nextAction":"Review","nextActionDate":null,"masterSpecification":{"changeSummary":"Initial intake","proposedName":"Separate race intake","customerOrInternalOwner":"Disposable customer","industryApplication":"Automotive","productFamily":"Tracker","developmentScope":"Prototype scope","workstreams":["HARDWARE"],"requirementSummary":"Track test vehicles","powerAndUnits":"12V","interfaces":"CAN","connectivityAndGnss":"LTE/GNSS","environmentAndIp":"IP67","volumes":"20","schedule":"Q4","requestedStandards":"TBC","exclusions":"None"}}'::jsonb
  END,
  :'request_key'::uuid
  )
)
INSERT INTO public.sales_intake_race_results (
  race_label, worker_label, opportunity_id, opportunity_number,
  master_specification_id, master_specification_number,
  master_specification_version_id, master_specification_version_number, replayed
)
SELECT :'race_label', :'worker_label', opportunity_id, opportunity_number,
  master_specification_id, master_specification_number,
  master_specification_version_id, master_specification_version_number, replayed
FROM response
RETURNING worker_label, opportunity_id, opportunity_number, master_specification_id,
  master_specification_number, master_specification_version_id,
  master_specification_version_number, replayed;
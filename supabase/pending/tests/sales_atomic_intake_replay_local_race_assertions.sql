-- Releases a coordinated local race only after observing two independent
-- worker registrations, then asserts the completed scenario. This is a
-- synthetic fixture test, not managed RLS/JWT transport evidence.
\set ON_ERROR_STOP on
SELECT set_config('race_label', :'race_label', false);
WITH waited AS (
  SELECT ready_workers
  FROM public.sales_intake_race_barriers
  WHERE race_label = :'race_label'
    AND ready_workers = expected_workers
)
UPDATE public.sales_intake_race_barriers
SET released = true
WHERE race_label = :'race_label'
  AND EXISTS (SELECT 1 FROM waited)
RETURNING race_label;

DO $release_check$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.sales_intake_race_barriers WHERE race_label = current_setting('race_label', true) AND released) THEN
    RAISE EXCEPTION 'Race readiness timeout';
  END IF;
END;
$release_check$;

DO $assert$
DECLARE
  v_deadline timestamptz := clock_timestamp() + interval '15 seconds';
  v_receipts integer; v_opportunities integer; v_specs integer; v_versions integer; v_audits integer;
  v_results integer; v_distinct_opportunity_ids integer; v_distinct_spec_ids integer;
  v_distinct_version_ids integer; v_distinct_numbers integer; v_replayed integer;
BEGIN
  LOOP
    SELECT count(*) INTO v_receipts FROM public.sales_opportunity_intake_receipts;
    CASE current_setting('race_label', true)
      WHEN 'same_key_same_payload' THEN EXIT WHEN v_receipts = 1;
      WHEN 'same_key_changed_payload', 'same_key_actor_conflict' THEN EXIT WHEN v_receipts = 2;
      WHEN 'different_keys' THEN EXIT WHEN v_receipts = 4;
      WHEN 'final' THEN EXIT;
    END CASE;
    IF clock_timestamp() >= v_deadline THEN RAISE EXCEPTION 'Race completion timeout for %', :'race_label'; END IF;
    PERFORM pg_sleep(0.02);
  END LOOP;
  SELECT count(*), count(DISTINCT opportunity_number) INTO v_opportunities, v_specs FROM public.sales_opportunities;
  SELECT count(*) INTO v_versions FROM public.master_specification_versions;
  SELECT count(*) INTO v_audits FROM public.activity_log;
  IF v_opportunities <> v_specs OR v_opportunities <> v_versions OR v_opportunities <> v_audits THEN
    RAISE EXCEPTION 'Race left mismatched opportunity/spec/version/audit rows';
  END IF;
  IF current_setting('race_label', true) = 'same_key_same_payload' AND (v_receipts <> 1 OR v_opportunities <> 1) THEN
    RAISE EXCEPTION 'Same actor/key/payload did not converge to exactly one receipt and business records';
  ELSIF current_setting('race_label', true) IN ('same_key_changed_payload', 'same_key_actor_conflict') AND (v_receipts <> 2 OR v_opportunities <> 2) THEN
    RAISE EXCEPTION 'Conflicting same-key race wrote more than one new intake';
  ELSIF current_setting('race_label', true) IN ('different_keys', 'final') AND (v_receipts <> 4 OR v_opportunities <> 4) THEN
    RAISE EXCEPTION 'Different-key race did not leave exactly four receipts/opportunities';
  END IF;
  IF (SELECT count(*) FROM public.sales_opportunities) <> (SELECT count(DISTINCT opportunity_number) FROM public.sales_opportunities) THEN
    RAISE EXCEPTION 'Concurrent allocator produced duplicate opportunity numbers';
  END IF;
  IF current_setting('race_label', true) = 'same_key_same_payload' THEN
    SELECT count(*), count(DISTINCT opportunity_id), count(DISTINCT master_specification_id),
      count(DISTINCT master_specification_version_id), count(DISTINCT opportunity_number),
      count(*) FILTER (WHERE replayed)
    INTO v_results, v_distinct_opportunity_ids, v_distinct_spec_ids,
      v_distinct_version_ids, v_distinct_numbers, v_replayed
    FROM public.sales_intake_race_results WHERE race_label = current_setting('race_label', true);
    IF v_results <> 2 OR v_distinct_opportunity_ids <> 1 OR v_distinct_spec_ids <> 1
       OR v_distinct_version_ids <> 1 OR v_distinct_numbers <> 1 OR v_replayed <> 1 THEN
      RAISE EXCEPTION 'Exact replay workers did not return identical opportunity/specification/version IDs and number with one replay';
    END IF;
  END IF;
END;
$assert$;

SELECT :'race_label' AS race_label, worker_label, opportunity_id, opportunity_number,
  master_specification_id, master_specification_number,
  master_specification_version_id, master_specification_version_number, replayed
FROM public.sales_intake_race_results
WHERE race_label = :'race_label'
ORDER BY worker_label;
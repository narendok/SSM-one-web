-- Releases a coordinated local race only after observing two independent
-- worker registrations, then asserts the completed scenario. This is a
-- synthetic fixture test, not managed RLS/JWT transport evidence.
\set ON_ERROR_STOP on
DO $release$
DECLARE v_ready integer; v_deadline timestamptz := clock_timestamp() + interval '15 seconds';
BEGIN
  LOOP
    SELECT ready_workers INTO v_ready FROM public.sales_intake_race_barriers WHERE race_label = :'race_label';
    IF v_ready = 2 THEN EXIT; END IF;
    IF clock_timestamp() >= v_deadline THEN RAISE EXCEPTION 'Race readiness timeout for %', :'race_label'; END IF;
    PERFORM pg_sleep(0.02);
  END LOOP;
  UPDATE public.sales_intake_race_barriers SET released = true WHERE race_label = :'race_label';
END;
$release$;

DO $assert$
DECLARE v_deadline timestamptz := clock_timestamp() + interval '15 seconds'; v_receipts integer; v_opportunities integer; v_specs integer; v_versions integer; v_audits integer;
BEGIN
  LOOP
    SELECT count(*) INTO v_receipts FROM public.sales_opportunity_intake_receipts;
    CASE :'race_label'
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
  IF :'race_label' = 'same_key_same_payload' AND (v_receipts <> 1 OR v_opportunities <> 1) THEN
    RAISE EXCEPTION 'Same actor/key/payload did not converge to exactly one receipt and business records';
  ELSIF :'race_label' IN ('same_key_changed_payload', 'same_key_actor_conflict') AND (v_receipts <> 2 OR v_opportunities <> 2) THEN
    RAISE EXCEPTION 'Conflicting same-key race wrote more than one new intake';
  ELSIF :'race_label' IN ('different_keys', 'final') AND (v_receipts <> 4 OR v_opportunities <> 4) THEN
    RAISE EXCEPTION 'Different-key race did not leave exactly four receipts/opportunities';
  END IF;
  IF (SELECT count(*) FROM public.sales_opportunities) <> (SELECT count(DISTINCT opportunity_number) FROM public.sales_opportunities) THEN
    RAISE EXCEPTION 'Concurrent allocator produced duplicate opportunity numbers';
  END IF;
END;
$assert$;
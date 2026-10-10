-- LOCAL DISPOSABLE HOLDER ONLY. Takes the contract's exact logical advisory lock
-- after committing readiness, so worker waits are observable inside the contract.
\set ON_ERROR_STOP on

SELECT pg_advisory_lock(hashtextextended(concat_ws('|',
  '00000000-0000-4000-8000-000000000201',
  '00000000-0000-4000-8000-000000000401',
  'SOR',
  public.sales_opportunity_structured_draft_schema_hash('SOR')
), 0));

UPDATE public.structured_draft_exact_replay_race_control
SET holder_ready = true
WHERE singleton;

DO $wait$
DECLARE
  v_deadline timestamptz := clock_timestamp() + interval '15 seconds';
BEGIN
  LOOP
    EXIT WHEN (SELECT released FROM public.structured_draft_exact_replay_race_control WHERE singleton);
    IF clock_timestamp() >= v_deadline THEN
      RAISE EXCEPTION 'Exact replay holder release timeout';
    END IF;
    PERFORM pg_sleep(0.02);
  END LOOP;
END;
$wait$;

SELECT pg_advisory_unlock(hashtextextended(concat_ws('|',
  '00000000-0000-4000-8000-000000000201',
  '00000000-0000-4000-8000-000000000401',
  'SOR',
  public.sales_opportunity_structured_draft_schema_hash('SOR')
), 0));
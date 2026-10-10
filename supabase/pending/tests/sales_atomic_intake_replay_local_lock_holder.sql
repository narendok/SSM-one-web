-- LOCAL DISPOSABLE ONLY. Hold the proposal's exact transaction advisory lock
-- in an independent session after fixture state is committed. The controller
-- observes a second session blocked on this lock before revoking permission.
\set ON_ERROR_STOP on
-- Commit readiness first. The subsequent transaction holds the exact lock, so
-- the controller never relies on an uncommitted status flag as wait evidence.
UPDATE public.sales_intake_lock_wait_cases
SET holder_ready = true
WHERE case_label = :'case_label';
BEGIN;
SELECT pg_advisory_xact_lock(hashtextextended(:'request_key', 0));
SELECT set_config('app.case_label', :'case_label', false);
DO $hold$
DECLARE
  v_deadline timestamptz := clock_timestamp() + interval '15 seconds';
  v_released boolean;
BEGIN
  LOOP
    SELECT released INTO v_released
    FROM public.sales_intake_lock_wait_cases
    WHERE case_label = current_setting('app.case_label', true);
    IF v_released THEN RETURN; END IF;
    IF clock_timestamp() >= v_deadline THEN
      RAISE EXCEPTION 'Contested-lock release timeout';
    END IF;
    PERFORM pg_sleep(0.02);
  END LOOP;
END;
$hold$;
COMMIT;
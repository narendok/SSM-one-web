-- LOCAL DISPOSABLE lock-wait and transactional rollback assertions only.
\set ON_ERROR_STOP on
SELECT set_config('app.case_label', :'case_label', false);
SELECT set_config('app.phase', :'phase', false);
DO $case$
DECLARE v_ready boolean; v_released boolean;
BEGIN
  SELECT ready, released INTO v_ready, v_released FROM public.sales_intake_lock_wait_cases WHERE case_label = current_setting('app.case_label', true);
  IF NOT FOUND OR NOT v_ready OR v_released THEN RAISE EXCEPTION 'Worker blocking state was not demonstrated'; END IF;
END;
$case$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', false);
UPDATE public.sales_test_permissions SET sales_manage = false WHERE user_id = '00000000-0000-4000-8000-000000000001';
UPDATE public.sales_intake_lock_wait_cases SET released = true WHERE case_label = current_setting('app.case_label', true);

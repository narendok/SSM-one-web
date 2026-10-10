-- LOCAL DISPOSABLE PRE-INSTALL CHECK ONLY. The proposed actions must not be
-- callable before the pending contract has been installed and explicitly
-- granted inside a disposable local fixture.
\set ON_ERROR_STOP on
BEGIN;
DO $preinstall$
BEGIN
  BEGIN
    PERFORM public.create_sales_opportunity_with_initial_master_specification(
      '00000000-0000-4000-8000-000000000010'::uuid, NULL, NULL, '{}'::jsonb,
      '00000000-0000-4000-8000-000000000090'::uuid
    );
    RAISE EXCEPTION 'Expected pre-install RPC denial';
  EXCEPTION WHEN undefined_function OR insufficient_privilege THEN
    IF SQLSTATE NOT IN ('42883', '42501') THEN
      RAISE EXCEPTION 'Expected SQLSTATE 42883 or 42501, received %', SQLSTATE;
    END IF;
  END;
END;
$preinstall$;
ROLLBACK;
\set ON_ERROR_STOP on
DO $wait$
DECLARE deadline timestamptz:=clock_timestamp()+interval '15 seconds';
BEGIN LOOP
  EXIT WHEN (SELECT verifier_ready FROM public.trusted_receipt_race_control WHERE case_name=:'case_name');
  IF clock_timestamp()>=deadline THEN RAISE EXCEPTION 'Verifier did not acquire its request lock'; END IF;
  PERFORM pg_sleep(.02);
END LOOP; END $wait$;
\if :{?case_name}
\endif
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
-- Each mutation is committed before verifier release; the subsequent issue must
-- re-evaluate the changed authority rather than minting a receipt from stale facts.
UPDATE public.trusted_receipt_race_control SET mutation_ready=true WHERE case_name=:'case_name';
UPDATE public.trusted_receipt_race_control SET released=true WHERE case_name=:'case_name';
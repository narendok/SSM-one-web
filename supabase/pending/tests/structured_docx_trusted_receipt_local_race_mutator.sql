\set ON_ERROR_STOP on
SELECT :'case_name' AS case_name \gset
DO $wait$
DECLARE deadline timestamptz:=clock_timestamp()+interval '15 seconds';
BEGIN LOOP
  EXIT WHEN (SELECT verifier_ready FROM public.trusted_receipt_race_control WHERE case_name=:'case_name');
  IF clock_timestamp()>=deadline THEN RAISE EXCEPTION 'Verifier did not acquire its request lock'; END IF;
  PERFORM pg_sleep(.02);
END LOOP; END $wait$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
UPDATE public.trusted_receipt_race_control SET mutation_ready=true WHERE case_name=:'case_name';
DO $release$
DECLARE deadline timestamptz:=clock_timestamp()+interval '15 seconds';
BEGIN LOOP
  EXIT WHEN (SELECT released FROM public.trusted_receipt_race_control WHERE case_name=:'case_name');
  IF clock_timestamp()>=deadline THEN RAISE EXCEPTION 'Race coordinator release timeout'; END IF;
  PERFORM pg_sleep(.02);
END LOOP; END $release$;
UPDATE public.structured_lifecycle_docx_responsibility_assignments
SET status='REVOKED', revoked_by='00000000-0000-4000-8000-000000000001', revoked_at=now()
WHERE :'case_name'='revoke' AND id='00000000-0000-4000-8000-000000000901';
UPDATE public.structured_lifecycle_docx_template_pins
SET status='REVOKED', revoked_by='00000000-0000-4000-8000-000000000001', revoked_at=now()
WHERE :'case_name'='template' AND id='00000000-0000-4000-8000-000000000994';
UPDATE public.master_specifications
SET current_version=2
WHERE :'case_name'='source' AND id='00000000-0000-4000-8000-000000000301';
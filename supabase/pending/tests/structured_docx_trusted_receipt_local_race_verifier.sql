\set ON_ERROR_STOP on
SELECT :'case_name' AS case_name \gset
SELECT set_config('request.jwt.claim.sub', NULL, false);
SELECT pg_advisory_lock(hashtextextended(concat_ws('|','sales-structured-docx',:'request_key'),0));
UPDATE public.trusted_receipt_race_control SET verifier_ready=true WHERE case_name=:'case_name';
DO $wait$
DECLARE deadline timestamptz:=clock_timestamp()+interval '15 seconds';
BEGIN LOOP
  EXIT WHEN (SELECT mutation_ready FROM public.trusted_receipt_race_control WHERE case_name=:'case_name');
  IF clock_timestamp()>=deadline THEN RAISE EXCEPTION 'Mutator did not prepare'; END IF;
  PERFORM pg_sleep(.02);
END LOOP; END $wait$;
UPDATE public.trusted_receipt_race_control SET released=true WHERE case_name=:'case_name';
SELECT pg_advisory_unlock(hashtextextended(concat_ws('|','sales-structured-docx',:'request_key'),0));
SELECT public.issue_sales_structured_docx_trusted_receipt('00000000-0000-4000-8000-000000000001',:'request_key'::uuid,'00000000-0000-4000-8000-000000000901','project-drive','sales/opportunity/00000000-0000-4000-8000-000000000201/'||:'request_key'||'-draft.docx','race-v1','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',512,:'source_fingerprint','sales-sor-race',1,'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','local-race-verifier');
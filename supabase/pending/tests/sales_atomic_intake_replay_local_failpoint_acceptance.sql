-- LOCAL DISPOSABLE transactional failpoint acceptance only.
\set ON_ERROR_STOP on
INSERT INTO public.sales_test_permissions VALUES ('00000000-0000-4000-8000-000000000001', true);
INSERT INTO public.customers VALUES ('00000000-0000-4000-8000-000000000010', 'Disposable customer');
INSERT INTO public.customer_contacts VALUES ('00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000010', true);
INSERT INTO public.sales_enquiries VALUES ('00000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000011');
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', false);
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
CREATE TRIGGER sales_intake_fail_receipt BEFORE INSERT ON public.sales_opportunity_intake_receipts
FOR EACH ROW EXECUTE FUNCTION public.sales_intake_test_failpoint();
DO $failpoints$
DECLARE
  v_point text; v_before_opportunity integer; v_before_spec integer; v_before_version integer; v_before_audit integer; v_before_receipt integer;
  v_before_opp_number integer; v_before_spec_number integer;
BEGIN
  FOREACH v_point IN ARRAY ARRAY['master_specifications', 'master_specification_versions', 'sales_opportunity_intake_receipts'] LOOP
    SELECT count(*) INTO v_before_opportunity FROM public.sales_opportunities;
    SELECT count(*) INTO v_before_spec FROM public.master_specifications;
    SELECT count(*) INTO v_before_version FROM public.master_specification_versions;
    SELECT count(*) INTO v_before_audit FROM public.activity_log;
    SELECT count(*) INTO v_before_receipt FROM public.sales_opportunity_intake_receipts;
    SELECT next_value INTO v_before_opp_number FROM public.document_numbering_config WHERE document_type = 'opportunity';
    SELECT next_value INTO v_before_spec_number FROM public.document_numbering_config WHERE document_type = 'master_specification';
    PERFORM set_config('sales_intake.test.failpoint', v_point, true);
    BEGIN
      PERFORM public.create_sales_opportunity_with_initial_master_specification(
        '00000000-0000-4000-8000-000000000010'::uuid, '00000000-0000-4000-8000-000000000011'::uuid, '00000000-0000-4000-8000-000000000012'::uuid,
        '{"name":"Failpoint intake","application":"Vehicle tracking","productType":"Tracker","primarySalesOwnerUserId":null,"ndaRequired":false,"estimatedVolume":"20","targetTimeline":"Q4","priority":"medium","nextAction":"Review","nextActionDate":null,"masterSpecification":{"changeSummary":"Initial intake","proposedName":"Failpoint intake","customerOrInternalOwner":"Disposable customer","industryApplication":"Automotive","productFamily":"Tracker","developmentScope":"Prototype scope","workstreams":["HARDWARE"],"requirementSummary":"Track test vehicles","powerAndUnits":"12V","interfaces":"CAN","connectivityAndGnss":"LTE/GNSS","environmentAndIp":"IP67","volumes":"20","schedule":"Q4","requestedStandards":"TBC","exclusions":"None"}}'::jsonb,
        CASE v_point WHEN 'master_specifications' THEN '00000000-0000-4000-8000-000000000301'::uuid WHEN 'master_specification_versions' THEN '00000000-0000-4000-8000-000000000302'::uuid ELSE '00000000-0000-4000-8000-000000000303'::uuid END);
      RAISE EXCEPTION 'Expected local failpoint at %', v_point;
    EXCEPTION WHEN raise_exception THEN
      IF SQLERRM <> 'Local test failpoint: ' || v_point THEN RAISE; END IF;
    END;
    PERFORM set_config('sales_intake.test.failpoint', '', true);
    IF (SELECT count(*) FROM public.sales_opportunities) <> v_before_opportunity
       OR (SELECT count(*) FROM public.master_specifications) <> v_before_spec
       OR (SELECT count(*) FROM public.master_specification_versions) <> v_before_version
       OR (SELECT count(*) FROM public.activity_log) <> v_before_audit
       OR (SELECT count(*) FROM public.sales_opportunity_intake_receipts) <> v_before_receipt
       OR (SELECT next_value FROM public.document_numbering_config WHERE document_type = 'opportunity') <> v_before_opp_number
       OR (SELECT next_value FROM public.document_numbering_config WHERE document_type = 'master_specification') <> v_before_spec_number THEN
      RAISE EXCEPTION 'Failpoint % did not roll back all records and numbers', v_point;
    END IF;
    RAISE NOTICE 'FAILPOINT_ROLLBACK_PASS=%', v_point;
  END LOOP;
END;
$failpoints$;

-- LOCAL DISPOSABLE ROLLBACK FIXTURE ONLY. It adds failpoint triggers solely
-- after the pending contract is installed on the fresh private fixture.
\set ON_ERROR_STOP on

CREATE TABLE public.structured_draft_rollback_case_results (
  case_name text PRIMARY KEY CHECK (case_name IN ('create_revision', 'create_receipt', 'update_revision', 'update_receipt')),
  sqlstate text NOT NULL,
  message text NOT NULL,
  before_drafts jsonb NOT NULL,
  after_drafts jsonb NOT NULL,
  before_revisions jsonb NOT NULL,
  after_revisions jsonb NOT NULL,
  before_requests jsonb NOT NULL,
  after_requests jsonb NOT NULL
);

CREATE FUNCTION public.structured_draft_rollback_capture()
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'drafts', coalesce((SELECT jsonb_agg(to_jsonb(draft) ORDER BY draft.id) FROM public.sales_opportunity_structured_drafts AS draft), '[]'::jsonb),
    'revisions', coalesce((SELECT jsonb_agg(to_jsonb(revision) ORDER BY revision.draft_id, revision.revision_number) FROM public.sales_opportunity_structured_draft_revisions AS revision), '[]'::jsonb),
    'requests', coalesce((SELECT jsonb_agg(to_jsonb(request_receipt) ORDER BY request_receipt.request_key) FROM public.sales_opportunity_structured_draft_requests AS request_receipt), '[]'::jsonb)
  )
$$;

CREATE FUNCTION public.structured_draft_rollback_failpoint()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF current_setting('structured_draft.test_failpoint', true) = TG_ARGV[0] THEN
    RAISE EXCEPTION 'STRUCTURED_DRAFT_TEST_FAILPOINT:%', TG_ARGV[0] USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER structured_draft_rollback_fail_revision
  BEFORE INSERT ON public.sales_opportunity_structured_draft_revisions
  FOR EACH ROW EXECUTE FUNCTION public.structured_draft_rollback_failpoint('revision');

CREATE TRIGGER structured_draft_rollback_fail_receipt
  BEFORE INSERT ON public.sales_opportunity_structured_draft_requests
  FOR EACH ROW EXECUTE FUNCTION public.structured_draft_rollback_failpoint('receipt');
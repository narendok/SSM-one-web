BEGIN;
-- SOURCE-ONLY. Private highlight drafts, never published/client-readable highlights.
CREATE TABLE public.requirement_highlight_draft_versions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),review_id uuid NOT NULL REFERENCES public.requirement_feasibility_reviews(id),
 author_user_id uuid NOT NULL,source_revision_id uuid NOT NULL REFERENCES public.customer_requirement_revisions(id),
 master_version_id uuid NOT NULL REFERENCES public.master_specification_versions(id),version_number integer NOT NULL CHECK(version_number>0),
 expected_version integer NOT NULL CHECK(expected_version>=0),body text NOT NULL CHECK(length(body)<=12000),
 request_key uuid NOT NULL UNIQUE,saved_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(review_id,author_user_id,source_revision_id,master_version_id,version_number)
);
ALTER TABLE public.requirement_highlight_draft_versions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.requirement_highlight_draft_versions FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION public.save_requirement_highlight_draft(p_review_id uuid,p_source_revision_id uuid,p_master_version_id uuid,p_expected_version integer,p_body text,p_request_key uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE prior public.requirement_highlight_draft_versions%ROWTYPE; saved public.requirement_highlight_draft_versions%ROWTYPE; latest integer;
BEGIN
 IF p_request_key IS NULL OR p_expected_version IS NULL OR p_expected_version<0 OR p_body IS NULL OR length(p_body)>12000 THEN RAISE EXCEPTION 'Invalid highlight draft request'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('highlight-draft-request:'||p_request_key::text,0));
 PERFORM public.requirement_review_private_draft_context(p_review_id,p_source_revision_id,p_master_version_id);
 SELECT * INTO prior FROM public.requirement_highlight_draft_versions WHERE request_key=p_request_key;
 IF FOUND THEN
  IF prior.review_id IS DISTINCT FROM p_review_id OR prior.author_user_id IS DISTINCT FROM auth.uid()
  OR prior.source_revision_id IS DISTINCT FROM p_source_revision_id OR prior.master_version_id IS DISTINCT FROM p_master_version_id
  OR prior.expected_version IS DISTINCT FROM p_expected_version OR prior.body IS DISTINCT FROM btrim(p_body) THEN RAISE EXCEPTION 'Highlight draft request conflicts with a different payload'; END IF;
  RETURN to_jsonb(prior);
 END IF;
 SELECT coalesce(max(version_number),0) INTO latest FROM public.requirement_highlight_draft_versions
 WHERE review_id=p_review_id AND author_user_id=auth.uid() AND source_revision_id=p_source_revision_id AND master_version_id=p_master_version_id;
 IF latest<>p_expected_version THEN RAISE EXCEPTION 'Highlight draft changed; reload before saving'; END IF;
 INSERT INTO public.requirement_highlight_draft_versions(review_id,author_user_id,source_revision_id,master_version_id,version_number,expected_version,body,request_key)
 VALUES(p_review_id,auth.uid(),p_source_revision_id,p_master_version_id,latest+1,p_expected_version,btrim(p_body),p_request_key) RETURNING * INTO saved;
 INSERT INTO public.activity_log(actor_user_id,module_key,entity_type,entity_id,action,summary,after_data)
 VALUES(auth.uid(),'sales','requirement_feasibility_review',p_review_id,'highlight_draft_saved','Private highlight draft saved',jsonb_build_object('draft_id',saved.id,'version_number',saved.version_number,'source_revision_id',p_source_revision_id,'master_version_id',p_master_version_id));
 RETURN to_jsonb(saved);
END;
$$;
CREATE FUNCTION public.read_own_requirement_highlight_draft(p_review_id uuid,p_source_revision_id uuid,p_master_version_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE saved public.requirement_highlight_draft_versions%ROWTYPE;
BEGIN
 PERFORM public.requirement_review_private_draft_context(p_review_id,p_source_revision_id,p_master_version_id);
 SELECT * INTO saved FROM public.requirement_highlight_draft_versions WHERE review_id=p_review_id AND author_user_id=auth.uid()
 AND source_revision_id=p_source_revision_id AND master_version_id=p_master_version_id ORDER BY version_number DESC LIMIT 1;
 IF NOT FOUND THEN RETURN NULL; END IF;
 RETURN to_jsonb(saved);
END;
$$;
REVOKE ALL ON FUNCTION public.save_requirement_highlight_draft(uuid,uuid,uuid,integer,text,uuid) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.read_own_requirement_highlight_draft(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;

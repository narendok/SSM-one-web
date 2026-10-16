BEGIN;
-- SOURCE-ONLY. No installation or caller grants authorized.
-- Private reviewer notes only: NOT client highlights/publication, verdict or baseline approval.
CREATE TABLE public.requirement_internal_note_versions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 review_id uuid NOT NULL REFERENCES public.requirement_feasibility_reviews(id),
 author_user_id uuid NOT NULL,
 source_revision_id uuid NOT NULL REFERENCES public.customer_requirement_revisions(id),
 master_version_id uuid NOT NULL REFERENCES public.master_specification_versions(id),
 version_number integer NOT NULL CHECK(version_number>0),
 expected_version integer NOT NULL CHECK(expected_version>=0),
 body text NOT NULL CHECK(length(body)<=12000),
 request_key uuid NOT NULL UNIQUE,
 saved_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(review_id,author_user_id,version_number)
);
ALTER TABLE public.requirement_internal_note_versions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.requirement_internal_note_versions FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.save_requirement_internal_note(
 p_review_id uuid,p_source_revision_id uuid,p_master_version_id uuid,
 p_expected_version integer,p_body text,p_request_key uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE
 v_review public.requirement_feasibility_reviews%ROWTYPE;
 v_requirement public.customer_requirements%ROWTYPE;
 v_prior public.requirement_internal_note_versions%ROWTYPE;
 v_saved public.requirement_internal_note_versions%ROWTYPE;
 v_latest integer;
BEGIN
 IF auth.uid() IS NULL OR NOT public.has_permission(auth.uid(),'engineering.manage') THEN
  RAISE EXCEPTION 'Engineering management permission is required';
 END IF;
 IF p_request_key IS NULL OR p_expected_version IS NULL OR p_expected_version<0
 OR p_body IS NULL OR length(p_body)>12000 THEN RAISE EXCEPTION 'Invalid internal note request'; END IF;
 -- Same actor-request then requirement-root lock order as protected handover.
 PERFORM pg_advisory_xact_lock(hashtextextended(p_request_key::text,0));
 SELECT * INTO v_review FROM public.requirement_feasibility_reviews WHERE id=p_review_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Review unavailable'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('sales-feasibility-requirement-root:'||v_review.requirement_id::text,0));
 SELECT * INTO v_requirement FROM public.customer_requirements WHERE id=v_review.requirement_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Requirement unavailable'; END IF;
 SELECT * INTO v_review FROM public.requirement_feasibility_reviews WHERE id=p_review_id FOR UPDATE;
 IF NOT FOUND OR v_review.requirement_id IS DISTINCT FROM v_requirement.id THEN RAISE EXCEPTION 'Review source changed'; END IF;
 IF v_review.reviewer_user_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Only the assigned reviewer may save this note'; END IF;
 PERFORM 1 FROM public.employees e JOIN public.employee_departments m ON m.employee_id=e.id
 WHERE e.user_id=auth.uid() AND e.employment_status='ACTIVE' AND m.department_id=v_review.department_id FOR KEY SHARE OF e,m;
 IF NOT FOUND THEN RAISE EXCEPTION 'Active assigned department membership is required'; END IF;
 PERFORM 1 FROM public.departments WHERE id=v_review.department_id AND is_active FOR KEY SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Review department is unavailable'; END IF;
 IF p_source_revision_id IS DISTINCT FROM v_review.source_revision_id OR p_master_version_id IS DISTINCT FROM v_review.master_specification_version_id
 OR v_review.source_revision_number IS DISTINCT FROM v_requirement.current_revision THEN RAISE EXCEPTION 'Note source revision is stale'; END IF;
 PERFORM 1 FROM public.customer_requirement_revisions WHERE id=p_source_revision_id AND requirement_id=v_requirement.id
 AND revision_number=v_review.source_revision_number FOR KEY SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Pinned requirement revision unavailable'; END IF;
 PERFORM 1 FROM public.master_specification_versions v JOIN public.master_specifications s ON s.id=v.specification_id
 WHERE v.id=p_master_version_id AND v.version_number=v_review.master_specification_version_number
 AND s.opportunity_id=v_requirement.opportunity_id AND s.customer_id=v_requirement.customer_id FOR KEY SHARE OF v,s;
 IF NOT FOUND THEN RAISE EXCEPTION 'Pinned Master revision unavailable'; END IF;
 SELECT * INTO v_prior FROM public.requirement_internal_note_versions WHERE request_key=p_request_key;
 IF FOUND THEN
  IF v_prior.author_user_id IS DISTINCT FROM auth.uid() OR v_prior.review_id IS DISTINCT FROM p_review_id
  OR v_prior.source_revision_id IS DISTINCT FROM p_source_revision_id OR v_prior.master_version_id IS DISTINCT FROM p_master_version_id
  OR v_prior.expected_version IS DISTINCT FROM p_expected_version OR v_prior.body IS DISTINCT FROM btrim(p_body) THEN
   RAISE EXCEPTION 'Note request key conflicts with a different payload';
  END IF;
  RETURN to_jsonb(v_prior);
 END IF;
 SELECT coalesce(max(version_number),0) INTO v_latest FROM public.requirement_internal_note_versions
 WHERE review_id=p_review_id AND author_user_id=auth.uid();
 IF v_latest<>p_expected_version THEN RAISE EXCEPTION 'Internal note changed; reload before saving'; END IF;
 INSERT INTO public.requirement_internal_note_versions(review_id,author_user_id,source_revision_id,master_version_id,version_number,expected_version,body,request_key)
 VALUES(p_review_id,auth.uid(),p_source_revision_id,p_master_version_id,v_latest+1,p_expected_version,btrim(p_body),p_request_key) RETURNING * INTO v_saved;
 -- Audit metadata deliberately excludes private note contents.
 INSERT INTO public.activity_log(actor_user_id,module_key,entity_type,entity_id,action,summary,after_data)
 VALUES(auth.uid(),'sales','requirement_feasibility_review',p_review_id,'internal_note_saved','Internal review note saved',
 jsonb_build_object('note_id',v_saved.id,'version_number',v_saved.version_number,'source_revision_id',p_source_revision_id,'master_version_id',p_master_version_id));
 RETURN to_jsonb(v_saved);
END;
$$;
REVOKE ALL ON FUNCTION public.save_requirement_internal_note(uuid,uuid,uuid,integer,text,uuid) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;

-- SOURCE-ONLY review proposal. No managed installation or application grants.
-- Positive, own-Sales handover evidence only; no notification body or colleague notes.
BEGIN;
CREATE FUNCTION public.read_sales_feasibility_handover_receipt(
 p_request_key uuid, p_enquiry_id uuid, p_opportunity_id uuid,
 p_customer_id uuid, p_master_specification_version_id uuid
) RETURNS TABLE(request_key uuid, requirement_id uuid, source_revision_id uuid,
 source_revision_number integer, master_specification_version_id uuid,
 master_specification_version_number integer, review_pins jsonb,
 notification_ids uuid[], audit_id uuid)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $reader$
 WITH receipt AS MATERIALIZED (
  SELECT h.* FROM public.sales_feasibility_handover_requests h
  WHERE auth.uid() IS NOT NULL AND public.has_permission(auth.uid(),'sales.manage')
   AND h.requested_by=auth.uid() AND h.request_key=p_request_key
   AND h.enquiry_id=p_enquiry_id AND h.opportunity_id=p_opportunity_id
   AND h.customer_id=p_customer_id AND h.master_specification_version_id=p_master_specification_version_id
 ), evidence AS (
 SELECT h.*, graph.pins, notices.ids, audits.id AS verified_audit_id
 FROM receipt h
 JOIN public.sales_enquiries e ON e.id=h.enquiry_id AND e.customer_id=h.customer_id AND e.status<>'archived'
 JOIN public.sales_opportunities o ON o.id=h.opportunity_id AND o.customer_id=h.customer_id AND o.enquiry_id=e.id
 JOIN public.master_specification_versions mv ON mv.id=h.master_specification_version_id AND mv.version_number=h.master_specification_version_number
 JOIN public.master_specifications ms ON ms.id=mv.specification_id AND ms.current_version=mv.version_number AND ms.opportunity_id=o.id AND ms.customer_id=h.customer_id
 JOIN public.customer_requirements r ON r.id=h.requirement_id AND r.opportunity_id=o.id AND r.customer_id=h.customer_id AND r.current_revision=h.source_revision_number
 JOIN public.customer_requirement_revisions rev ON rev.id=h.source_revision_id AND rev.requirement_id=r.id AND rev.revision_number=h.source_revision_number AND rev.requirement_data=r.requirement_data
 CROSS JOIN LATERAL (
  SELECT jsonb_agg(jsonb_build_object('id',v.id,'department_id',v.department_id,'reviewer_user_id',v.reviewer_user_id,
   'source_revision_id',v.source_revision_id,'source_revision_number',v.source_revision_number,
   'master_specification_version_id',v.master_specification_version_id,'master_specification_version_number',v.master_specification_version_number,
   'applicable_workstreams',v.applicable_workstreams) ORDER BY v.department_id,v.id) pins
  FROM public.requirement_feasibility_reviews v WHERE v.requirement_id=r.id
 ) graph
 CROSS JOIN LATERAL (
  SELECT array_agg(n.id ORDER BY v.department_id,v.id) ids, count(*) total
  FROM public.requirement_feasibility_reviews v JOIN public.notifications n ON n.user_id=v.reviewer_user_id
   AND n.category='feasibility_review' AND n.target_entity_type='requirement_feasibility_review'
   AND n.target_entity_id=v.id AND n.event_key='sales-feasibility-handover:'||v.id::text
  WHERE v.requirement_id=r.id
 ) notices
 CROSS JOIN LATERAL (
  SELECT min(a.id::text)::uuid id,count(*) total FROM public.activity_log a
  WHERE a.actor_user_id=h.requested_by AND a.module_key='sales' AND a.entity_type='customer_requirement'
   AND a.entity_id=r.id AND a.action='feasibility_handover_submitted'
   AND a.after_data->>'request_key'=h.request_key::text
   AND a.after_data->>'enquiry_id'=h.enquiry_id::text
   AND a.after_data->>'opportunity_id'=h.opportunity_id::text
   AND a.after_data->>'customer_id'=h.customer_id::text
   AND a.after_data->>'source_revision_id'=h.source_revision_id::text
   AND a.after_data->>'master_specification_version_id'=h.master_specification_version_id::text
   AND a.after_data->'master_specification_version_number'=to_jsonb(h.master_specification_version_number)
   AND a.after_data->'review_ids'=(SELECT jsonb_agg(pin->'id' ORDER BY (pin->>'department_id')::uuid,(pin->>'id')::uuid) FROM jsonb_array_elements(h.review_pins) pin)
   AND a.after_data->'department_ids'=h.payload_canonical->'department_ids'
   AND a.after_data->'reviewer_user_ids'=h.payload_canonical->'reviewer_user_ids'
 ) audits
 WHERE jsonb_array_length(h.review_pins)>0 AND graph.pins=h.review_pins
  AND notices.total=jsonb_array_length(h.review_pins) AND audits.total=1
  AND e.updated_at=(h.payload_canonical->>'expected_enquiry_updated_at')::timestamptz
  AND r.created_by=h.requested_by AND rev.created_by=h.requested_by
  AND r.title=h.payload_canonical->>'title'
  AND r.customer_reference IS NOT DISTINCT FROM h.payload_canonical->>'customer_reference'
  AND r.requirement_data->'summary'=h.payload_canonical->'summary'
  AND mv.specification_data->'workstreams'=h.applicable_workstreams
  AND NOT EXISTS (
   SELECT 1 FROM public.requirement_feasibility_reviews v WHERE v.requirement_id=r.id AND
    (SELECT count(*) FROM public.notifications n WHERE n.user_id=v.reviewer_user_id
     AND n.category='feasibility_review' AND n.target_entity_type='requirement_feasibility_review'
     AND n.target_entity_id=v.id AND n.event_key='sales-feasibility-handover:'||v.id::text)<>1
  )
  AND r.requirement_data->'source' @> jsonb_build_object('enquiry_id',h.enquiry_id,'opportunity_id',h.opportunity_id,'customer_id',h.customer_id,
   'master_specification_id',ms.id,'master_specification_version_id',mv.id,'master_specification_version_number',mv.version_number,'applicable_workstreams',h.applicable_workstreams)
  AND NOT EXISTS (
   SELECT 1 FROM public.requirement_feasibility_reviews v
   WHERE v.requirement_id=r.id AND NOT EXISTS (
    SELECT 1 FROM public.departments d JOIN public.employee_departments ed ON ed.department_id=d.id
     JOIN public.employees emp ON emp.id=ed.employee_id
    WHERE d.id=v.department_id AND d.is_active AND emp.user_id=v.reviewer_user_id AND emp.employment_status='ACTIVE'
   )
  )
 )
 SELECT h.request_key,h.requirement_id,h.source_revision_id,h.source_revision_number,
  h.master_specification_version_id,h.master_specification_version_number,h.pins,h.ids,h.verified_audit_id
 FROM evidence h;
$reader$;
REVOKE ALL ON FUNCTION public.read_sales_feasibility_handover_receipt(uuid,uuid,uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;

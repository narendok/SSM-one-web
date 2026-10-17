-- REVIEW ONLY: preserve the SELECT contribution of the removed ALL policies.
-- These exact predicates/roles already granted reads; this adds no read audience.
CREATE POLICY "Sales users manage requirements" ON public.customer_requirements FOR SELECT TO authenticated USING (has_permission(auth.uid(),'sales.manage'::text) OR has_role(auth.uid(),'admin'::app_role));
CREATE POLICY "Sales users manage requirement revisions" ON public.customer_requirement_revisions FOR SELECT TO authenticated USING (has_permission(auth.uid(),'sales.manage'::text) OR has_role(auth.uid(),'admin'::app_role));
CREATE POLICY "Sales users manage feasibility reviews" ON public.requirement_feasibility_reviews FOR SELECT TO authenticated USING (has_permission(auth.uid(),'sales.manage'::text) OR has_role(auth.uid(),'admin'::app_role));

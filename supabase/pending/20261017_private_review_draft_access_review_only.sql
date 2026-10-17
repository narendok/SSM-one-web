BEGIN;
-- REVIEW ONLY: new caller access requires separate specific approval.
-- Own assigned-reviewer drafts only; never colleague discovery or publication.
DO $private_preflight$
BEGIN
 IF EXISTS (SELECT 1 FROM (VALUES
   ('public.requirement_internal_note_versions'::regclass),('public.requirement_highlight_draft_versions'::regclass)
 ) t(oid) JOIN pg_class c ON c.oid=t.oid WHERE NOT c.relrowsecurity
   OR has_table_privilege('anon',t.oid,'SELECT,INSERT,UPDATE,DELETE')
   OR has_table_privilege('authenticated',t.oid,'SELECT,INSERT,UPDATE,DELETE')
   OR has_table_privilege('service_role',t.oid,'SELECT,INSERT,UPDATE,DELETE')) THEN
   RAISE EXCEPTION 'Private draft direct table access is not closed';
 END IF;
 IF EXISTS (SELECT 1 FROM (VALUES
  ('public.save_requirement_internal_note(uuid,uuid,uuid,integer,text,uuid)'::regprocedure),
  ('public.read_own_requirement_internal_note(uuid,uuid,uuid)'::regprocedure),
  ('public.save_requirement_highlight_draft(uuid,uuid,uuid,integer,text,uuid)'::regprocedure),
  ('public.read_own_requirement_highlight_draft(uuid,uuid,uuid)'::regprocedure)
 ) f(oid) JOIN pg_proc p ON p.oid=f.oid WHERE NOT p.prosecdef
   OR p.proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp']) THEN
   RAISE EXCEPTION 'Private draft routine authority is incompatible';
 END IF;
 IF has_function_privilege('authenticated','public.requirement_review_private_draft_context(uuid,uuid,uuid)','EXECUTE')
 OR has_function_privilege('anon','public.requirement_review_private_draft_context(uuid,uuid,uuid)','EXECUTE')
 OR has_function_privilege('service_role','public.requirement_review_private_draft_context(uuid,uuid,uuid)','EXECUTE') THEN
   RAISE EXCEPTION 'Private draft context is exposed';
 END IF;
END;
$private_preflight$;
GRANT EXECUTE ON FUNCTION public.save_requirement_internal_note(uuid,uuid,uuid,integer,text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.read_own_requirement_internal_note(uuid,uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_requirement_highlight_draft(uuid,uuid,uuid,integer,text,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.read_own_requirement_highlight_draft(uuid,uuid,uuid) TO authenticated;
COMMIT;

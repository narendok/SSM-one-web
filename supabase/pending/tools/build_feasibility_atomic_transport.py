"""Prepare owner-only transport; never connects to a database or applies SQL."""
import argparse, base64, hashlib, json
from pathlib import Path

SCHEMA = "_ssm_feasibility_install_20261017"

def build(source: Path, output: Path):
    payload = source.read_bytes().replace(b"\r\n", b"\n")
    if b"\x00" in payload or not payload.rstrip().endswith(b"service_role;"):
        raise ValueError("Unexpected source terminator or NUL")
    digest = hashlib.sha256(payload).hexdigest()
    chunks = [payload[i:i+6000] for i in range(0, len(payload), 6000)]
    output.mkdir(parents=True, exist_ok=False)
    setup = f"""BEGIN;
CREATE SCHEMA {SCHEMA} AUTHORIZATION CURRENT_USER;
REVOKE ALL ON SCHEMA {SCHEMA} FROM PUBLIC, anon, authenticated, service_role;
CREATE TABLE {SCHEMA}.chunks (ordinal integer PRIMARY KEY CHECK (ordinal > 0), payload bytea NOT NULL);
REVOKE ALL ON TABLE {SCHEMA}.chunks FROM PUBLIC, anon, authenticated, service_role;
ALTER TABLE {SCHEMA}.chunks ENABLE ROW LEVEL SECURITY;
COMMIT;
"""
    (output / "00_setup.sql").write_text(setup, encoding="utf-8")
    for i, chunk in enumerate(chunks, 1):
        encoded = base64.b64encode(chunk).decode("ascii")
        (output / f"{i:02}_chunk.sql").write_text(
            f"BEGIN;\nINSERT INTO {SCHEMA}.chunks(ordinal,payload) VALUES ({i},decode('{encoded}','base64'));\nCOMMIT;\n", encoding="utf-8")
    final = f"""BEGIN;
DO $transport$
DECLARE v_payload bytea; v_count integer; v_min integer; v_max integer; v_graph_before jsonb; v_graph_after jsonb;
BEGIN
  IF (SELECT nspowner FROM pg_namespace WHERE nspname='{SCHEMA}') IS DISTINCT FROM (SELECT oid FROM pg_roles WHERE rolname=current_user) THEN
    RAISE EXCEPTION 'Transport owner mismatch';
  END IF;
  LOCK TABLE {SCHEMA}.chunks IN EXCLUSIVE MODE;
  SELECT decode(string_agg(encode(payload,'hex'),'' ORDER BY ordinal),'hex'),count(*),min(ordinal),max(ordinal)
  INTO v_payload,v_count,v_min,v_max FROM {SCHEMA}.chunks;
  IF v_count <> {len(chunks)} OR v_min <> 1 OR v_max <> {len(chunks)}
     OR octet_length(v_payload) <> {len(payload)}
     OR encode(sha256(v_payload),'hex') IS DISTINCT FROM '{digest}' THEN
    RAISE EXCEPTION 'Transport incomplete or source hash mismatch';
  END IF;
  SELECT jsonb_build_object('tables',(SELECT jsonb_agg(jsonb_build_object('name',relname,'acl',relacl,'rls',relrowsecurity) ORDER BY relname) FROM pg_class WHERE oid IN ('public.customer_requirements'::regclass,'public.customer_requirement_revisions'::regclass,'public.requirement_feasibility_reviews'::regclass)),
    'policies',(SELECT jsonb_agg(to_jsonb(p) ORDER BY polrelid,polname) FROM pg_policy p WHERE polrelid IN ('public.customer_requirements'::regclass,'public.customer_requirement_revisions'::regclass,'public.requirement_feasibility_reviews'::regclass))) INTO v_graph_before;
  EXECUTE convert_from(v_payload,'UTF8');
  SELECT jsonb_build_object('tables',(SELECT jsonb_agg(jsonb_build_object('name',relname,'acl',relacl,'rls',relrowsecurity) ORDER BY relname) FROM pg_class WHERE oid IN ('public.customer_requirements'::regclass,'public.customer_requirement_revisions'::regclass,'public.requirement_feasibility_reviews'::regclass)),
    'policies',(SELECT jsonb_agg(to_jsonb(p) ORDER BY polrelid,polname) FROM pg_policy p WHERE polrelid IN ('public.customer_requirements'::regclass,'public.customer_requirement_revisions'::regclass,'public.requirement_feasibility_reviews'::regclass))) INTO v_graph_after;
  IF v_graph_before IS DISTINCT FROM v_graph_after THEN RAISE EXCEPTION 'Existing graph access changed'; END IF;
  IF EXISTS (SELECT 1 FROM (VALUES
    ('public.assign_requirement_feasibility_review(uuid,uuid,uuid)'::regprocedure),
    ('public.record_requirement_feasibility_response(uuid,text,text,text,text,uuid)'::regprocedure),
    ('public.read_requirement_feasibility_response_receipt(uuid,uuid,uuid,uuid,uuid)'::regprocedure),
    ('public.submit_sales_feasibility_handover(uuid,uuid,uuid,uuid,text,text,text,uuid[],uuid[],timestamptz,uuid)'::regprocedure)
  ) f(oid) JOIN pg_proc p ON p.oid=f.oid WHERE NOT p.prosecdef OR p.proconfig IS DISTINCT FROM ARRAY['search_path=public, pg_temp']
    OR has_function_privilege('anon',f.oid,'EXECUTE') OR NOT has_function_privilege('authenticated',f.oid,'EXECUTE')
    OR NOT has_function_privilege('service_role',f.oid,'EXECUTE')) THEN RAISE EXCEPTION 'Protected RPC authority mismatch'; END IF;
  IF EXISTS (SELECT 1 FROM (VALUES ('public.sales_feasibility_handover_requests'::regclass),('public.requirement_feasibility_response_requests'::regclass)) t(oid)
    JOIN pg_class c ON c.oid=t.oid WHERE NOT c.relrowsecurity OR has_table_privilege('anon',t.oid,'SELECT,INSERT,UPDATE,DELETE')
    OR has_table_privilege('authenticated',t.oid,'SELECT,INSERT,UPDATE,DELETE')) THEN RAISE EXCEPTION 'Private receipt access mismatch'; END IF;
  IF (SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='requirement_feasibility_reviews'
      AND column_name IN ('source_revision_id','source_revision_number','master_specification_version_id','master_specification_version_number','applicable_workstreams')) <> 5 THEN
    RAISE EXCEPTION 'Installed pins incomplete';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.requirement_feasibility_reviews'::regclass
      AND conname='requirement_feasibility_reviews_revision_department_key' AND contype='u') THEN
    RAISE EXCEPTION 'Installed uniqueness incomplete';
  END IF;
END;
$transport$;
-- Explicitly remove only this newly-created, hash-checked transport; never CASCADE.
DROP TABLE {SCHEMA}.chunks;
DROP SCHEMA {SCHEMA};
COMMIT;
"""
    (output / "99_execute.sql").write_text(final, encoding="utf-8")
    start = final.index("  SELECT decode(string_agg")
    end = final.index("  IF v_count", start)
    direct = final[:start] + "  v_payload := decode('" + base64.b64encode(payload).decode("ascii") + "','base64');\n" + final[end:]
    direct = direct.replace(f"IF v_count <> {len(chunks)} OR v_min <> 1 OR v_max <> {len(chunks)}\n     OR octet_length(v_payload)", "IF octet_length(v_payload)")
    (output / "98_direct_editor.sql").write_text(direct, encoding="utf-8")
    manifest = {"source": str(source), "sha256_lf": digest, "bytes_lf": len(payload), "chunks": len(chunks), "schema": SCHEMA,
                "note": "Review only; one final transaction executes the unaltered whole source. Staging grants no application access."}
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")
    return manifest

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    print(json.dumps(build(args.source, args.output)))
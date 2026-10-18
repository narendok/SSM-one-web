import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
if (!process.argv[2]) throw Error('Supply a local PGlite module path; no managed connection is accepted.');
const { PGlite } = await import(pathToFileURL(resolve(process.argv[2])).href);
import fs from 'node:fs/promises';
const db=new PGlite();
const root=new URL('../../../', import.meta.url);
await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role; CREATE SCHEMA auth; CREATE TABLE auth.users(id uuid PRIMARY KEY); CREATE TABLE public.rd_members(id uuid PRIMARY KEY); CREATE TABLE public.employees(id uuid PRIMARY KEY); ALTER TABLE rd_members ENABLE ROW LEVEL SECURITY; ALTER TABLE employees ENABLE ROW LEVEL SECURITY; INSERT INTO auth.users VALUES ('00000000-0000-4000-8000-000000000001'); INSERT INTO rd_members VALUES ('00000000-0000-4000-8000-000000000002'),('00000000-0000-4000-8000-000000000003'); INSERT INTO employees VALUES ('00000000-0000-4000-8000-000000000004'),('00000000-0000-4000-8000-000000000005');`);
const proposal=await fs.readFile(new URL('supabase/pending/20261018_task_member_identity_private_review_only.sql',root),'utf8');
await db.exec(proposal);
const scalar=async(sql)=>(await db.query(sql)).rows[0];
if(Number((await scalar('SELECT count(*) n FROM _ssm_task_identity.member_employee_versions')).n)!==0)throw Error('Unexpected backfill');
const insert=(m,e)=>`INSERT INTO _ssm_task_identity.member_employee_versions(rd_member_id,employee_id,verified_by,verification_reason) VALUES ('${m}','${e}','00000000-0000-4000-8000-000000000001','Explicit fixture verification')`;
const m='00000000-0000-4000-8000-000000000002',e='00000000-0000-4000-8000-000000000004';
await db.exec(insert(m,e));
async function denied(sql,code){try{await db.exec(sql)}catch(error){if((Array.isArray(code)?code:[code]).includes(error.code))return;throw error}throw Error('Expected '+code)}
await denied(insert(m,'00000000-0000-4000-8000-000000000005'),'23505');
await denied(insert('00000000-0000-4000-8000-000000000003',e),'23505');
await denied(insert('00000000-0000-4000-8000-000000000099','00000000-0000-4000-8000-000000000005'),'23503');
await denied(`DELETE FROM rd_members WHERE id='${m}'`,['23001','23503']);
for(const role of ['anon','authenticated','service_role']){const r=await scalar(`SELECT has_schema_privilege('${role}','_ssm_task_identity','USAGE') s,has_table_privilege('${role}','_ssm_task_identity.member_employee_versions','SELECT,INSERT,UPDATE,DELETE,TRUNCATE') t`);if(r.s||r.t)throw Error('App access exposed');}
await db.exec(`UPDATE _ssm_task_identity.member_employee_versions SET revoked_by='00000000-0000-4000-8000-000000000001',revoked_at=transaction_timestamp();`);
await db.exec(insert(m,e));
if(Number((await scalar('SELECT count(*) n FROM _ssm_task_identity.member_employee_versions')).n)!==2)throw Error('Historical row lost');
for(const role of ['anon','authenticated','service_role']) {
  await db.exec(`SET ROLE ${role}`);
  try { await denied('SELECT * FROM _ssm_task_identity.member_employee_versions','42501'); }
  finally { await db.exec('RESET ROLE'); }
}
if(!(await scalar("SELECT relrowsecurity enabled FROM pg_class WHERE oid='_ssm_task_identity.member_employee_versions'::regclass")).enabled)throw Error('RLS disabled');
console.log('TASK_IDENTITY_PRIVATE_PROPOSAL_LOCAL_PASS no_backfill=true app_access_denied=true duplicate_current_links_denied=true invalid_fk_denied=true source_delete_restricted=true revoked_history_retained=true managed_execution=false');
console.log(JSON.stringify(await scalar('SELECT version()')));
await db.close();
for(const failure of ['missing-source','disabled-rls','late-fk-failure']) {
  const isolated=new PGlite();
  await isolated.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role; CREATE SCHEMA auth; CREATE TABLE auth.users(id ${failure==='late-fk-failure'?'text':'uuid'} PRIMARY KEY); CREATE TABLE rd_members(id uuid PRIMARY KEY); ALTER TABLE rd_members ENABLE ROW LEVEL SECURITY;`);
  if(failure!=='missing-source') await isolated.exec(`CREATE TABLE employees(id uuid PRIMARY KEY); ${failure==='disabled-rls'?'':'ALTER TABLE employees ENABLE ROW LEVEL SECURITY;'}`);
  let rejected=false;
  try{await isolated.exec(proposal)}catch{rejected=true;await isolated.exec('ROLLBACK');}
  if(!rejected)throw Error('Prerequisite failure accepted: '+failure);
  const result=await isolated.query("SELECT to_regnamespace('_ssm_task_identity')::text AS schema");
  if(result.rows[0].schema!==null)throw Error('Partial schema remains: '+failure);
  await isolated.close();
}
console.log('TASK_IDENTITY_INSTALL_GUARDS_LOCAL_PASS missing_source_denied=true disabled_rls_denied=true late_fk_failure_rolls_back=true no_partial_schema=true managed_execution=false');

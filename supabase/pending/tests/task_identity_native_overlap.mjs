// Native-only overlap check using the synthetic stewardship fixture created by the preceding test.
import postgres from '../../../node_modules/postgres/src/index.js';
const port=Number(process.env.SSM_TASK_FIXTURE_PORT);if(!Number.isInteger(port)||port<1024||!process.env.SSM_TASK_FIXTURE_PASSWORD)throw Error('Disposable loopback fixture required');
const options={host:'127.0.0.1',port,database:'postgres',username:'ssm_fixture',password:process.env.SSM_TASK_FIXTURE_PASSWORD,max:1,connect_timeout:10};
const a=postgres(options),b=postgres(options),control=postgres(options);const id=n=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
let revokeRelease;let release;const gate=new Promise(r=>release=r);let ready;const started=new Promise(r=>ready=r);let first,second;
try{
 for(const client of [a,b]){await client`SELECT set_config('request.jwt.claim.sub',${id(1)},false)`;await client`SET statement_timeout='10s'`;}
 const current=(await control`SELECT id FROM _ssm_task_identity.member_employee_versions WHERE rd_member_id=${id(5)} AND revoked_at IS NULL`)[0].id;
 const bpid=(await b`SELECT pg_backend_pid() pid`)[0].pid;
 first=a.begin(async tx=>{const result=await tx`SELECT _ssm_task_identity.record_mapping(${id(5)},${id(4)},${current},${id(200)},'Concurrent replay fixture') id`;ready();await gate;return result[0].id;});
 await started;
 second=b`SELECT _ssm_task_identity.record_mapping(${id(5)},${id(4)},${current},${id(200)},'Concurrent replay fixture') id`.execute();
 let waited=false;
 for(let i=0;i<60;i++){const locks=await control`SELECT EXISTS(SELECT 1 FROM pg_locks WHERE pid=${bpid} AND locktype='advisory' AND NOT granted) waiting`;if(locks[0].waiting){waited=true;break;}await new Promise(r=>setTimeout(r,50));}
 release();const [one,two]=await Promise.all([first,second]);
 if(!waited)throw Error('Did not independently observe blocked second advisory lock');
 if(one!==two[0].id)throw Error('Concurrent replay returned different identity versions');
 const receipts=await control`SELECT count(*)::int n FROM _ssm_task_identity.mapping_requests WHERE actor_id=${id(1)} AND request_key=${id(200)}`;
 if(receipts[0].n!==1)throw Error('Concurrent replay receipt duplicated');
 let revokeReady;const revokeStarted=new Promise(r=>revokeReady=r);const revokeGate=new Promise(r=>revokeRelease=r);
 first=a.begin(async tx=>{await tx`SELECT _ssm_task_identity.record_mapping(${id(5)},${id(4)},${current},${id(201)},'Queued revocation fixture')`;revokeReady();await revokeGate;});
 await revokeStarted;
 second=b`SELECT _ssm_task_identity.record_mapping(${id(5)},${id(4)},${current},${id(201)},'Queued revocation fixture') id`.execute().then(rows=>({rows}),error=>({error}));
 let revokeWaited=false;
 for(let i=0;i<60;i++){const locks=await control`SELECT EXISTS(SELECT 1 FROM pg_locks WHERE pid=${bpid} AND locktype='advisory' AND NOT granted) waiting`;if(locks[0].waiting){revokeWaited=true;break;}await new Promise(r=>setTimeout(r,50));}
 if(!revokeWaited)throw Error('Role revocation fixture did not block');
 await control`DELETE FROM public.fixture_admins WHERE user_id=${id(1)}`;
 revokeRelease();const [,revoked]=await Promise.all([first,second]);
 if(!revoked.error||!/steward authority/.test(revoked.error.message))throw Error('Queued replay retained revoked role authority');
 console.log('TASK_IDENTITY_NATIVE_ROLE_REVOCATION_PASS queued_lock_observed=true role_removed_while_waiting=true replay_denied_after_lock=true managed_execution=false general_membership_race_acceptance=false');
 console.log('TASK_IDENTITY_NATIVE_OVERLAP_PASS two_connections=true blocked_advisory_lock_observed=true same_request_single_receipt=true same_result=true managed_execution=false membership_revocation_race_acceptance=false');
}finally{release?.();revokeRelease?.();await Promise.allSettled([first,second].filter(Boolean));await Promise.all([a.end({timeout:5}),b.end({timeout:5}),control.end({timeout:5})]);}

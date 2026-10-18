// Adapter for the same isolated SQL test interface. Native connections are loopback-only.
import postgres from '../../../node_modules/postgres/src/index.js';
export class PGlite {
 constructor(){
  const port=Number(process.env.SSM_TASK_FIXTURE_PORT);
  if(!Number.isInteger(port)||port<1024||!process.env.SSM_TASK_FIXTURE_PASSWORD)throw Error('Disposable native fixture configuration required');
  this.sql=postgres({host:'127.0.0.1',port,database:'postgres',username:'ssm_fixture',password:process.env.SSM_TASK_FIXTURE_PASSWORD,max:1,connect_timeout:10});
 }
 async exec(sql){return this.sql.unsafe(sql).simple();}
 async query(sql,params=[]){return {rows:await this.sql.unsafe(sql,params)};}
 async close(){await this.sql.end({timeout:5});}
}

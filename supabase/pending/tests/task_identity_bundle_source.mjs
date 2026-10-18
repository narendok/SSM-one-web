// Deterministic review-only bundle. Never connects to a database.
import fs from 'node:fs/promises';
import {createHash} from 'node:crypto';
export const files=['20261018_task_member_identity_private_review_only.sql','20261018_task_identity_steward_transaction_review_only.sql','20261018_task_identity_readback_revoke_review_only.sql'];
export function transactionBody(sql){
 const normalized=sql.replaceAll('\r\n','\n');
 if((normalized.match(/^BEGIN;$/gm)||[]).length!==1||(normalized.match(/^COMMIT;$/gm)||[]).length!==1)throw Error('Unexpected transaction boundaries');
 return normalized.replace(/^BEGIN;\n/m,'').replace(/^COMMIT;\s*$/m,'').trim();
}
export async function buildBundle(){
 const bodies=[];
 for(const file of files){const source=(await fs.readFile(new URL('../'+file,import.meta.url),'utf8')).replaceAll('\r\n','\n');bodies.push('-- Source: '+file+'; LF-normalized SHA256 '+createHash('sha256').update(source).digest('hex')+'\n'+transactionBody(source));}
 const postflight=await fs.readFile(new URL('./task_identity_bundle_postflight.sql',import.meta.url),'utf8');
 return '-- REVIEW ONLY / NOT INSTALLED. Owner-private, no application grants or backfill.\n-- Generated from reviewed sources with one atomic transaction; do not install pieces separately.\nBEGIN;\n'+bodies.join('\n\n')+'\n\n'+postflight.replaceAll('\r\n','\n').trim()+'\nCOMMIT;\n';
}
if(process.argv.includes('--write'))await fs.writeFile(new URL('../20261018_task_identity_private_bundle_review_only.sql',import.meta.url),await buildBundle());

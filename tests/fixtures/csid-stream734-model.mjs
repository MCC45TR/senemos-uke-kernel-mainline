// SPDX-License-Identifier: GPL-2.0-only
// Preserve the donor's exact shared callback and compose the real gen3 caller.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const [source,gen3,oracle,out]=process.argv.slice(2);
function body(s,name) {
 const hit=new RegExp('^static [^\\n]+ '+name+'\\([^;]*?\\)\\n\\{','m').exec(s);assert(hit,name);
 let p=hit.index+hit[0].length,n=1;
 for(;p<s.length&&n;p++){if(s[p]==='{')n++;if(s[p]==='}')n--;}
 assert.equal(n,0);return s.slice(hit.index,p)+'\n';
}
const common=body(fs.readFileSync(source,'utf8'),'csid_set_stream');
const donor=body(fs.readFileSync(path.join(oracle,'cfm-camss-csid.c'),'utf8'),'csid_set_stream');
const g=body(fs.readFileSync(gen3,'utf8'),'csid_configure_stream');
fs.mkdirSync(out,{recursive:true});
fs.writeFileSync(path.join(out,'actual-stream.h'),'/* SPDX-License-Identifier: GPL-2.0 */\n/* Linux Foundation, Linaro and Qualcomm; original bodies. */\n'+g+common);
fs.writeFileSync(path.join(out,'donor-stream.h'),donor);
if(!common.includes('if (csid->phy.need_vc_update)'))assert.equal(common,donor);

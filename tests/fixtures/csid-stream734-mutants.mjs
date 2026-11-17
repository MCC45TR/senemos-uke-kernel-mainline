// SPDX-License-Identifier: GPL-2.0-only
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const [source,out]=process.argv.slice(2),s=fs.readFileSync(path.join(source,'actual-stream.h'),'utf8');
const call='csid->res->hw_ops->configure_stream(csid, enable);';
for(const [name,before,after]of [
 ['cached-gate',call,'if (csid->phy.need_vc_update) '+call],
 ['start-only',call,'if (enable) '+call],
 ['duplicate-dispatch',call,call+'\n\t'+call],
 ['discard-control-error','return ret;','return 0;'],
 ['bypass-link','if (!csid->testgen.enabled &&','if (false &&']
]){
 assert.equal(s.split(before).length,2,name);fs.mkdirSync(path.join(out,name),{recursive:true});
 fs.writeFileSync(path.join(out,name,'actual-stream.h'),s.replace(before,after));
}

// SPDX-License-Identifier: GPL-2.0-only
// Preflight every precise anchor before expensive native checks.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const [source,out]=process.argv.slice(2),s=fs.readFileSync(path.join(source,'actual-csid.h'),'utf8');
for(const [name,before,after]of [
 ['wrong-top-buffer','top |= BIT(13);','top |= BIT(14);'],
 ['missing-rup-mask','writel(RUP_DONE_IRQ_STATUS,\n\t\t       csid->base + CSID_CSI2_RDIN_IRQ_MASK(i));','writel(0,\n\t\t       csid->base + CSID_CSI2_RDIN_IRQ_MASK(i));'],
 ['overwrite-buffer-mask','done |= BIT(BUF_DONE_IRQ_STATUS_RDI_OFFSET + i);','done = BIT(BUF_DONE_IRQ_STATUS_RDI_OFFSET + i);'],
 ['missing-top-rdi','top |= BIT(8 + i);','top |= 0;'],
 ['legacy-dispatch','if (csid->camss->res->version == CAMSS_7675) {','if (1) {']
]){
 assert.equal(s.split(before).length,2,name);
 fs.mkdirSync(path.join(out,name),{recursive:true});
 fs.writeFileSync(path.join(out,name,'actual-csid.h'),s.replace(before,after));
 fs.copyFileSync(path.join(source,'actual-oracle.h'),path.join(out,name,'actual-oracle.h'));
}

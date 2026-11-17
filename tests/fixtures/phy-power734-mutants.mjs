// SPDX-License-Identifier: GPL-2.0-only
// Source/text preflight on the PC; compile and execute these only in COPR.
import fs from 'node:fs';import assert from 'node:assert/strict';
const [source,out]=process.argv.slice(2);assert(source&&out);
for(const [name,file,before,after]of [
 ['wide-voltage','actual-power.h','csiphy->res->voltage[i].max_uV);','INT_MAX);'],
 ['early-release','actual-power.h','ret = regulator_disable(power->supplies[i].consumer);','ret = regulator_set_voltage(power->supplies[i].consumer, 0, INT_MAX);'],
 ['discard-fault','actual-power.h','if (power->fault || power->active || power->voted || power->enabled ||\n\t    power->pm_held || power->clocks || power->irq)','if (false)'],
 ['sync-deadlock','actual-status.h','if (!READ_ONCE(cam_cc_native.ready))','if (!READ_ONCE(cam_cc_native.synchronized))'],
 ['legacy-dispatch','actual-dispatch.h','csiphy->camss->res->version == CAMSS_7675','1']
]){
 fs.mkdirSync(out+'/'+name,{recursive:true});
 for(const f of fs.readdirSync(source))fs.copyFileSync(source+'/'+f,out+'/'+name+'/'+f);
 const p=out+'/'+name+'/'+file,s=fs.readFileSync(p,'utf8');
 assert.equal(s.split(before).length,2,name);
 fs.writeFileSync(p,s.replace(before,after));
}

// SPDX-License-Identifier: GPL-2.0-only
// Import production power callbacks and resource fields; model only framework APIs.
import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';
const [kernel,owner,out]=process.argv.slice(2);assert(kernel&&owner&&out);
const d=kernel+'/drivers/media/platform/qcom/camss/';
function fn(s,signature){const p=s.indexOf(signature);assert(p>=0,signature);assert.equal(s.indexOf(signature,p+1),-1);const b=s.indexOf('{',p);let depth=0;for(let i=b;i<s.length;i++){if(s[i]==='{')depth++;if(s[i]==='}'&&!--depth)return s.slice(p,i+1)+'\n';}throw Error('unclosed function');}
fs.mkdirSync(out,{recursive:true});
const power=fs.readFileSync(d+'camss-csiphy.c','utf8');
fs.writeFileSync(out+'/actual-dispatch.h',fn(power,'static int csiphy_set_power('));
let h=fs.readFileSync(owner+'/src/camera/phy-power734/camss-csiphy-sm7675-power.h','utf8');
h=h.replace(/^#include <linux\/[^\n]+\n/gm,'');
fs.writeFileSync(out+'/actual-power.h',h);
const provider=fs.readFileSync(kernel+'/drivers/clk/qcom/camcc-sm7675.c','utf8');
let status=provider.includes('int qcom_sm7675_camcc_status(void)')?fn(provider,'int qcom_sm7675_camcc_status(void)'):'';
if(!status)status='int qcom_sm7675_camcc_status(void) { return 0; }\n';
fs.writeFileSync(out+'/actual-status.h',status.replace('int qcom_sm7675_camcc_status(void)','static int actual_qcom_sm7675_camcc_status(void)'));
const data=fs.readFileSync(d+'camss-sm7675-data.h','utf8');
const v=data.match(/\.voltage = \{ \{ (\d+), (\d+) \}, \{ (\d+), (\d+) \} \}/);
const supplies=[...data.matchAll(/\.supply = "(vdd-csiphy-[^"]+)", \.init_load_uA = (\d+)/g)];assert.equal(supplies.length,2);
const voltage=v?v.slice(1).map(Number):[0,0,0,0];
fs.writeFileSync(out+'/actual-policy.h',`static const struct camss_subdev_resources policy={\n.csiphy={.voltage={{${voltage[0]},${voltage[1]}},{${voltage[2]},${voltage[3]}}},.hw_ops=&hw_ops},\n.regulators={{.supply="${supplies[0][1]}",.init_load_uA=${supplies[0][2]}},{.supply="${supplies[1][1]}",.init_load_uA=${supplies[1][2]}}}};\n`);
if(v){
 assert(power.indexOf('csiphy_sm7675_owner_check(camss)')<power.indexOf('ret = csiphy->res->hw_ops->init(csiphy)'));
 assert(power.includes('return csiphy_sm7675_power_init(csiphy, res);'));
 const core=fs.readFileSync(d+'camss.c','utf8');
 assert.equal(core.split('"qcom,sm7675-camss"').length,2);
 assert(core.includes('.suppress_bind_attrs = true,'));
 assert(core.includes('platform_register_drivers(camss_drivers, ARRAY_SIZE(camss_drivers))'));
 const desc=core.slice(core.indexOf('static struct platform_driver qcom_camss_driver'),core.indexOf('/* Permanent Uke ownership'));
 assert(!desc.includes('suppress_bind_attrs'));
}

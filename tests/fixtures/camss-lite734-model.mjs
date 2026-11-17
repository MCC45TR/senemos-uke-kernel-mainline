// SPDX-License-Identifier: GPL-2.0-only
// Import production callbacks and independent, pinned GPL OEM register tables.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const [source,oracleDir,out]=process.argv.slice(2);
assert(source&&oracleDir&&out);
const s=fs.readFileSync(source,'utf8');
const first='#define IS_VFE_690(vfe)',last='static void vfe_reg_update(';
assert.equal(s.split(first).length,2);assert.equal(s.split(last).length,2);
fs.mkdirSync(out,{recursive:true});
fs.writeFileSync(path.join(out,'actual-vfe-functions.h'),
 '// SPDX-License-Identifier: GPL-2.0\n// Copyright (c) 2024 Qualcomm Technologies, Inc.\n'+s.slice(s.indexOf(first),s.indexOf(last)));
const o=fs.readFileSync(path.join(oracleDir,'micode-cam_vfe_lite88x.h'),'utf8');
assert.equal(o,fs.readFileSync(path.join(oracleDir,'oneplus-cam_vfe_lite88x.h'),'utf8'));
const top=fs.readFileSync(path.join(oracleDir,'micode-cam_vfe_lite86x.h'),'utf8');
assert(o.includes('GPL-2.0-only')&&top.includes('GPL-2.0-only'));
assert(top.includes('.bus_hw_info                   = &vfe_lite88x_bus_hw_info'));
const bus=fs.readFileSync(path.join(oracleDir,'micode-cam_vfe_bus_ver3.c'),'utf8');
assert(bus.includes('GPL-2.0-only'));
assert(bus.includes('/* Frame drop config is only applicable to full IFE */\n\t\tif (!bus_priv->common_data.is_lite) {'));
const value=(text,key)=>{
 const hits=[...text.matchAll(new RegExp('^[ \\t]*[.]'+key+'[ \\t]*=[ \\t]*(0x[0-9A-Fa-f]+),','gm'))];
 assert.equal(hits.length,1,key);return Number(hits[0][1]);
};
const common=o.slice(o.indexOf('static struct cam_vfe_bus_ver3_hw_info vfe_lite88x_bus_hw_info'),o.indexOf('.bus_client_reg'));
const base=value(top,'hw_version'),control=value(common,'test_bus_ctrl'),cgc=value(common,'cgc_ovd');
assert.equal(base,0x1000);assert.equal(control-base,0x394);
const keys=['cfg','image_addr','frame_incr','image_cfg_0','image_cfg_2','packer_cfg','irq_subsample_period','irq_subsample_pattern','mmu_prefetch_cfg','mmu_prefetch_max_offset'];
let header='/* SPDX-License-Identifier: GPL-2.0-only */\n/* Qualcomm Innovation Center; exact independent OEM fields, no hardware. */\n';
header+=`#define OEM_VFE_ORIGIN ${base}U\n#define OEM_TEST_BUS ${control}U\n#define OEM_CGC ${cgc}U\nstatic const struct oracle_row oem_rdi[] = {\n`;
for(let rdi=0;rdi<4;rdi++){
 const tag=`/* BUS Client ${rdi} RDI${rdi} */`;
 assert.equal(o.split(tag).length,2);
 const start=o.indexOf(tag),end=o.indexOf('.comp_group',start);
 assert(end>start);const row=o.slice(start,end);
 assert(!row.includes('.framedrop_'));
 const values=keys.map(k=>value(row,k));
 assert(values.every(v=>v>=base&&v-base<0x1800));
 header+='{'+values.map(v=>`${v}U`).join(',')+'},\n';
}
header+='};\n';
fs.writeFileSync(path.join(out,'actual-oem-oracle.h'),header);

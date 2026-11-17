// SPDX-License-Identifier: GPL-2.0-only
// Production callbacks and independent OEM register fields, without hardware.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const [source,oracleDir,out]=process.argv.slice(2),s=fs.readFileSync(source,'utf8');
const begin=s.indexOf('#define CSID_IO_PATH_CFG0'),end=s.indexOf('static void __csid_configure_rx(');
assert(begin>=0&&end>begin);fs.mkdirSync(out,{recursive:true});
let actual='/* SPDX-License-Identifier: GPL-2.0 */\n/* Qualcomm Technologies, Inc. 2024; exact production callbacks. */\n'+s.slice(begin,end);
for(const name of ['csid_subdev_reg_update','csid_isr','csid_reset_irqs_7675','csid_reset']) {
 const pattern=new RegExp('^static [^\\n]+ '+name+'\\([^;]*?\\)\\n\\{','m'),hit=pattern.exec(s);
 if(!hit){assert.equal(name,'csid_reset_irqs_7675');continue;}
 let i=hit.index+hit[0].length,depth=1;
 for(;i<s.length&&depth;i++){if(s[i]==='{')depth++;if(s[i]==='}')depth--;}
 assert.equal(depth,0);actual+=s.slice(hit.index,i)+'\n';
}
fs.writeFileSync(path.join(out,'actual-csid.h'),actual);
const block=(text,name)=>{
 const tag=name+' = {';assert.equal(text.split(tag).length,2,name);
 const p=text.indexOf(tag),q=text.indexOf('\n};',p);assert(q>p);return text.slice(p,q);
};
const field=(text,key)=>{
 const hits=[...text.matchAll(new RegExp('^[ \\t]*[.]'+key+'[ \\t]*=[ \\t]*(?:\\{\\s*)?(0x[0-9A-Fa-f]+|[0-9]+)[ \\t]*[,}]','gm'))];
 assert.equal(hits.length,1,key);return Number(hits[0][1]);
};
let oracle='/* SPDX-License-Identifier: GPL-2.0-only */\n/* Qualcomm Innovation Center; fields imported from independent GPL tables. */\nstatic const struct oracle_irq oracle_irqs[2] = {\n';
for(const [suffix,rows,vfeFile] of [['880',3,'micode-cam_vfe880.h'],['_lite880',4,'micode-cam_vfe_lite88x.h']]) {
 const file='cam_ife_csid'+suffix+'.h';
 const o=fs.readFileSync(path.join(oracleDir,'micode-'+file),'utf8'),same=fs.readFileSync(path.join(oracleDir,'oneplus-'+file),'utf8');
 assert(o.includes('GPL-2.0-only')&&same.includes('GPL-2.0-only'));
 const prefix='cam_ife_csid_'+(suffix==='880'?'880':'lite_880');
 const cmn=block(o,prefix+'_cmn_reg_info'),other=block(same,prefix+'_cmn_reg_info');
 const keys=['top_irq_status_addr','top_irq_mask_addr','top_irq_clear_addr','buf_done_irq_status_addr','buf_done_irq_mask_addr','buf_done_irq_clear_addr','irq_cmd_addr','top_reset_irq_mask','top_buf_done_irq_mask'];
 const common=keys.map(k=>{const v=field(cmn,k);assert.equal(v,field(other,k));return v;});
 const vfe=fs.readFileSync(path.join(oracleDir,vfeFile),'utf8');assert(vfe.includes('GPL-2.0-only'));
 const masks=vfe.match(/\.comp_done_mask\s*=\s*\{([\s\S]*?)\}/);assert(masks);
 const bits=[...masks[1].matchAll(/BIT\(([0-9]+)\)/g)].map(m=>2**Number(m[1]));assert(bits.length>=rows);
 const channels=[];
 for(let i=0;i<rows;i++) {
  const row=block(o,prefix+'_rdi_'+i+'_reg_info'),peer=block(same,prefix+'_rdi_'+i+'_reg_info');
  const rk=['irq_status_addr','irq_mask_addr','irq_clear_addr','rup_irq_mask','top_irq_mask','rup_aup_mask'];
  const values=rk.map(k=>{const v=field(row,k);assert.equal(v,field(peer,k));return v;});
  const tag=new RegExp('/\\* BUS Client [0-9]+ RDI'+i+' \\*/'),pos=tag.exec(vfe);assert(pos);
  const group=/\.comp_group\s*=\s*CAM_VFE_BUS_VER3_COMP_GRP_([0-9]+)/.exec(vfe.slice(pos.index));assert(group);
  const done=bits[Number(group[1])];assert(done);values.push(done);channels.push('{'+values.map(v=>v+'U').join(',')+'}');
 }
 oracle+='{'+common.map(v=>v+'U').join(',')+','+rows+'U,{'+channels.join(',')+'}},\n';
}
oracle+='};\n';fs.writeFileSync(path.join(out,'actual-oracle.h'),oracle);

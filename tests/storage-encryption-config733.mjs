// SPDX-License-Identifier: MIT
// Admit a closed resolved Kconfig delta; never executes crypto or opens storage.
import fs from 'node:fs';
const [beforePath,afterPath,fragmentPath,deltaPath]=process.argv.slice(2);
function parse(path) {
 const result=new Map();
 for(const line of fs.readFileSync(path,'utf8').split('\n')) {
  let m=line.match(/^(CONFIG_[A-Z0-9_]+)=(.+)$/);
  if(m) {if(result.has(m[1]))throw Error('Duplicate config symbol');result.set(m[1],m[2]);continue;}
  m=line.match(/^# (CONFIG_[A-Z0-9_]+) is not set$/);
  if(m) {if(result.has(m[1]))throw Error('Duplicate disabled symbol');result.set(m[1],'n');}
 }
 return result;
}
const before=parse(beforePath),after=parse(afterPath),fragment=parse(fragmentPath);
if(before.size<1000||after.size<before.size)throw Error('Incomplete resolved configuration');
for(const [symbol,value]of fragment)if(after.get(symbol)!==value)throw Error('Missing requested crypto capability: '+symbol);
// Exact dependencies selected by this pinned upstream Kconfig. No wildcard
// exception for an unrelated crypto, storage, thermal or security change.
const allowed=new Map([...fragment,
 ['CONFIG_CRYPTO_ESSIV','m'],['CONFIG_CRYPTO_LIB_MD5','m']]);
const changes=[];
for(const key of new Set([...before.keys(),...after.keys()])) {
 const old=before.get(key)??'n',next=after.get(key)??'n';
 if(old===next)continue;
 if(!allowed.has(key)||allowed.get(key)!==next)throw Error('Unreviewed Kconfig change: '+key+' '+old+' -> '+next);
 changes.push([key,old,next]);
}
if(changes.length<6)throw Error('Expected missing capabilities were not enabled');
for(const [symbol,value]of [
 ['CONFIG_BLK_DEV_DM','m'],['CONFIG_BLK_INLINE_ENCRYPTION','y'],
 ['CONFIG_SCSI_UFS_CRYPTO','y'],['CONFIG_QCOM_INLINE_CRYPTO_ENGINE','m'],
 ['CONFIG_QCOMTEE','m'],['CONFIG_EXT4_FS','y'],['CONFIG_F2FS_FS','y'],
 ['CONFIG_MODULE_SIG_FORCE','y'],['CONFIG_SECURITY_SELINUX','y']
])if(before.get(symbol)!==value||after.get(symbol)!==value)throw Error('Retained prerequisite changed: '+symbol);
fs.writeFileSync(deltaPath,changes.sort().map(row=>row.join('\t')).join('\n')+'\n');
console.log('Actual encryption Kconfig: '+changes.length+' closed changes; ICE/TEE, filesystems, signatures, thermal and other options retained.');

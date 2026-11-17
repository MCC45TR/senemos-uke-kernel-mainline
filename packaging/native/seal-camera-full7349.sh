#!/usr/bin/bash
# Update only the two late-layer ledger entries, retaining complete inverses.
set -Eeuo pipefail
[[ $# == 1 ]]
kernel=$(realpath "$1")
node - "$kernel" <<'JS'
const fs=require('fs'),crypto=require('crypto'),assert=require('assert/strict');
const root=process.argv[2],out=root+'/camera-full7349-result';
fs.mkdirSync(out);
const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const changes=[
 ['camera-owner734-result/source.sha256','drivers/clk/qcom/camcc-sm7675.c','phy-power734-result'],
 ['super-root734-result/source.sha256','arch/arm64/kernel/uke-abl.c','front-eeprom734-result']
];
for(const [ledger,file,result]of changes){
 const before=fs.readFileSync(root+'/'+ledger,'utf8'),old=sha(root+'/'+result+'/inverse/'+file),now=sha(root+'/'+file);
 assert.notEqual(old,now);let count=0;
 const after=before.split('\n').map(line=>{
  if(line.endsWith('  '+file)){assert.equal(line,old+'  '+file);count++;return now+'  '+file;}return line;
 }).join('\n');assert.equal(count,1);
 assert.equal(after.replace(now+'  '+file,old+'  '+file),before);
 const name=ledger.split('/')[0];fs.writeFileSync(out+'/'+name+'-before.sha256',before);
 fs.writeFileSync(out+'/'+name+'-current.sha256',after);fs.writeFileSync(root+'/'+ledger,after);
}
const files=new Map();
for(const name of ['camss-lite','phy-power','csid-irq','csid-stream','front-eeprom']){
 const p=root+'/'+name+'734-result/source.sha256',s=fs.readFileSync(p,'utf8');
 for(const line of s.trim().split('\n')){const m=/^([a-f0-9]{64})  ([A-Za-z0-9_./-]+)$/.exec(line);assert(m);assert(!files.has(m[2]));assert.equal(sha(root+'/'+m[2]),m[1]);files.set(m[2],m[1]);}
}
fs.writeFileSync(out+'/source.sha256',[...files].map(([p,h])=>h+'  '+p).join('\n')+'\n');
JS
(cd "$kernel";sha256sum -c --strict --quiet camera-owner734-result/{source,retained}.sha256 super-root734-result/source.sha256 camera-full7349-result/source.sha256)

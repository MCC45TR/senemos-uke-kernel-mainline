#!/usr/bin/bash
# Refresh only qualified entries after checking both complete overlay inverses.
set -Eeuo pipefail
[[ $# == 1 ]]
kernel=$(realpath "$1")
result=$kernel/camera-native7348-result
[[ ! -e $result && ! -L $result ]]
for layer in odd parent;do
 diff -ru "$kernel/camera-${layer}734-result/before" "$kernel/camera-${layer}734-result/inverse"
 (cd "$kernel";sha256sum -c --strict --quiet "camera-${layer}734-result/source.sha256")
done
mkdir "$result"
node - "$kernel" "$result" <<'JS'
const fs=require('fs'),crypto=require('crypto'),[root,out]=process.argv.slice(2);
function parse(s){const rows=s.trimEnd().split('\n').map(x=>{const m=x.match(/^([a-f0-9]{64})  (drivers\/clk\/qcom\/[A-Za-z0-9_./-]+)$/);if(!m)throw Error('ledger record');return[m[2],m[1]];});const m=new Map(rows);if(m.size!==rows.length)throw Error('duplicate ledger entry');return m;}
function read(p){return fs.readFileSync(root+'/'+p,'utf8');}
function digest(p){return crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');}
const old=new Map(),now=new Map();
for(const name of ['odd','parent'])for(const [p,h]of parse(read('camera-'+name+'734-result/source.sha256'))){
 if(now.has(p))throw Error('overlapping layers');now.set(p,h);
 const before=root+'/camera-'+name+'734-result/inverse/'+p;
 old.set(p,digest(before));if(digest(root+'/'+p)!==h)throw Error('production postimage');
}
if(now.size!==5)throw Error('five qualified files required');
const ledgers=[['camera-owner734-result/source.sha256','owner',4],['camera-rom-report734-result/source.sha256','report',1]];
for(const [p,label,count]of ledgers){
 const before=read(p),rows=parse(before);let changed=0;
 for(const [file,hash]of rows)if(now.has(file)){
  if(hash!==old.get(file))throw Error('unexpected inherited hash '+file);
  rows.set(file,now.get(file));changed++;
 }
 if(changed!==count)throw Error('inherited ledger coverage');
 const serialize=m=>[...m].map(([p,h])=>h+'  '+p).join('\n')+'\n';
 const after=serialize(rows),inverse=new Map(rows);
 for(const file of inverse.keys())if(now.has(file))inverse.set(file,old.get(file));
 if(serialize(inverse)!==before)throw Error('whole ledger inverse');
 fs.writeFileSync(out+'/'+label+'-before.sha256',before);
 fs.writeFileSync(out+'/'+label+'-current.sha256',after);
 fs.writeFileSync(root+'/'+p,after);
}
fs.writeFileSync(out+'/source.sha256',[...now].map(([p,h])=>h+'  '+p).join('\n')+'\n');
JS
(cd "$kernel";sha256sum -c --strict --quiet camera-owner734-result/{source,retained}.sha256 camera-rom-report734-result/source.sha256 "$result/source.sha256")

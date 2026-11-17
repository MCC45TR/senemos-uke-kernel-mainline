#!/usr/bin/bash
# Preserve both complete historical ledgers through the one-file phase inverse.
set -Eeuo pipefail
[[ $# == 1 ]]
kernel=$(realpath "$1")
node - "$kernel" <<'JS'
const fs=require('fs'),crypto=require('crypto'),a=require('assert/strict');const root=process.argv[2],out=root+'/camera-full73410-result';fs.mkdirSync(out);
const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex'),file='arch/arm64/kernel/uke-abl.c';
const before=sha(root+'/front-stage734-result/fixed/before/'+file),after=sha(root+'/'+file);a.notEqual(before,after);
for(const name of ['super-root734-result','camera-full7349-result']){
 const path=root+'/'+name+'/source.sha256',old=fs.readFileSync(path,'utf8');a.equal(old.split(before+'  '+file).length,2);const now=old.replace(before+'  '+file,after+'  '+file);a.equal(now.replace(after+'  '+file,before+'  '+file),old);fs.writeFileSync(out+'/'+name+'-before.sha256',old);fs.writeFileSync(out+'/'+name+'-current.sha256',now);fs.writeFileSync(path,now);
}
const files=new Map();for(const name of ['camera-full7349-result','front-stage734-result'])for(const line of fs.readFileSync(root+'/'+name+'/source.sha256','utf8').trim().split('\n')){const m=/^([a-f0-9]{64})  ([A-Za-z0-9_./-]+)$/.exec(line);a(m);a.equal(sha(root+'/'+m[2]),m[1]);if(files.has(m[2]))a.equal(files.get(m[2]),m[1]);files.set(m[2],m[1]);}a.equal(files.size,14);fs.writeFileSync(out+'/source.sha256',[...files].map(([p,h])=>h+'  '+p).join('\n')+'\n');
JS
(cd "$kernel";sha256sum -c --strict --quiet super-root734-result/source.sha256 camera-full7349-result/source.sha256 camera-full73410-result/source.sha256)

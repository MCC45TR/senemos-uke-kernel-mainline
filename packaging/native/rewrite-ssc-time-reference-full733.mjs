// SPDX-License-Identifier: GPL-2.0-only
import fs from 'node:fs';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const [input,output,contract,tupleJSON]=process.argv.slice(2),m=JSON.parse(fs.readFileSync(contract)),t=JSON.parse(tupleJSON),before=fs.readFileSync(input,'utf8');
assert.equal(crypto.createHash('sha256').update(before).digest('hex'),m.parent_spec_sha256);
assert.equal(t.release,26);assert.equal(t.source_check_release,110);assert.equal(t.version,'7.3.3');
let after=before;const edits=[];
const once=(old,next)=>{assert.equal(after.split(old).length,2,'Ambiguous full25 recipe anchor');after=after.replace(old,()=>next);edits.push([old,next]);};
once('%global senemos_build_release 25\n','%global senemos_build_release 26\n');
once('Source190: uke-native-hardware-delivery.tar.xz\n','Source190: uke-native-hardware-delivery.tar.xz\nSource191: uke-ssc-time-reference-delivery.tar.xz\n');
once('Provides: uke-kernel(ssc-stream-buffer-fresh-v1) = 1\n','Provides: uke-kernel(ssc-stream-buffer-fresh-v1) = 1\nProvides: uke-kernel(ssc-time-reference-diagnostic-v1) = 1\n');
once('\n%build\n','\ntar -xJf %{SOURCE191}\n(cd ssc-time-reference-full; jq -r \'.source_assets[]|.sha256+"  "+.path\' manifests/ssc-time-reference-delivery-20261113.json | sha256sum -c --strict --quiet -)\n(cd ssc-time-reference-full; jq -r \'.source_assets[]|.sha256+"  "+.path\' manifests/ssc-time-reference-20261113.json | sha256sum -c --strict --quiet -)\n\n%build\n');
for(const phase of ['source','linked','sealed']){
 const old='bash native-hardware/packaging/native/prepare-native-hardware-full733.sh "$PWD" %{_uke_out} '+phase+'\n';
 once(old,old+'bash ssc-time-reference-full/packaging/native/prepare-ssc-time-reference-full733.sh "$PWD" %{_uke_out} '+phase+'\n');
}
for(const phase of ['check','install']){
 const old='bash native-hardware/packaging/native/prepare-native-hardware-full733.sh "$PWD" %{_uke_out} '+phase+' \'%{buildroot}\'\n';
 once(old,old+'bash ssc-time-reference-full/packaging/native/prepare-ssc-time-reference-full733.sh "$PWD" %{_uke_out} '+phase+' \'%{buildroot}\'\n');
}
once('%changelog\n','%changelog\n* Fri Nov 13 2026 Uke contributors - '+t.evr+'\n- Add a root-only on-demand SSC counter reference for measured clock research.\n- Retain all full25 hardware, configuration, checks and runtime package names.\n- Keep acquisition-time, gravity-frame and physical admission closed.\n\n');
let inverse=after;for(const[old,next]of [...edits].reverse()){assert.equal(inverse.split(next).length,2);inverse=inverse.replace(next,()=>old);}assert.equal(inverse,before,'Unrelated full25 recipe changed');
for(const section of ['prep','build','install','check','changelog'])assert.equal((after.match(new RegExp('^%'+section+'$','mg'))||[]).length,1);
if(m.result?.spec_sha256)assert.equal(crypto.createHash('sha256').update(after).digest('hex'),m.result.spec_sha256);
fs.writeFileSync(output,after);
console.log('Full26: complete full25 recipe inverse passes; all statements/checks retained with ordered diagnostic phases.');

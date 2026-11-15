#!/usr/bin/bash
# Rewrite only the admitted full22 recipe scopes, with a complete inverse.
set -Eeuo pipefail
[[ $# == 4 && ! -e $2 ]]
tuple=$(bash "$(dirname -- "$0")/../../scripts/kernel-release.sh" json "$4")
node - "$1" "$2" "$3" "$tuple" <<'NODE'
const fs=require('fs'),crypto=require('crypto'),[input,output,manifest,json]=process.argv.slice(2),m=JSON.parse(fs.readFileSync(manifest)),t=JSON.parse(json),before=fs.readFileSync(input,'utf8');
if(crypto.createHash('sha256').update(before).digest('hex')!==m.parent_spec_sha256||t.version!=='7.3.3'||t.release!==m.parent_full_release+1||t.source_check_release!==m.proof.source_check_release)throw Error('Parent/tuple mismatch');
const old='%global senemos_build_release '+m.parent_full_release+'\n',next='%global senemos_build_release '+t.release+'\n';
if(before.split(old).length!==2)throw Error('Release count');let after=before.replace(old,()=>next);const changes=[];
function replace(a,b,n=1){if(after.split(a).length!==n+1)throw Error('Recipe anchor: '+a);after=after.replaceAll(a,()=>b);changes.push([a,b,n]);}
replace('Provides: uke-kernel(charge-demand-protection-v1) = 1\n','Provides: uke-kernel(charge-demand-protection-v1) = 1\nProvides: uke-kernel(charge-protection-passive-v1) = 1\nProvides: uke-kernel(charge-protection-observe-v2) = 1\n');
const source='bash native-profile/packaging/native/prepare-charge-demand-full733.sh "$PWD" %{_uke_out} source\n';
replace(source,source+'bash native-profile/packaging/native/prepare-charge-observe-full733.sh "$PWD" %{_uke_out} source\n');
replace('charge_demand_parent=$(bash native-profile/packaging/native/charge-demand-legacy-view733.sh "$PWD")\n','charge_observe_parent=$(bash native-profile/packaging/native/charge-observe-legacy-view733.sh "$PWD")\ncharge_demand_parent=$(bash native-profile/packaging/native/charge-demand-legacy-view733.sh "$charge_observe_parent")\n',2);
for(const phase of ['linked','install']){
 const tail=phase+(phase==='install'?" '%{buildroot}'":'');
 for(const helper of ['prepare-battery-event-full733.sh','prepare-charge-demand-full733.sh']){
  const line='bash native-profile/packaging/native/'+helper+' "$PWD" %{_uke_out} '+tail+'\n';
  replace(line,'bash native-profile/packaging/native/'+helper+' "$charge_observe_parent" %{_uke_out} '+tail+'\n');
 }
 const anchor='bash native-profile/packaging/native/prepare-charge-demand-full733.sh "$charge_observe_parent" %{_uke_out} '+tail+'\n';
 replace(anchor,anchor+'bash native-profile/packaging/native/prepare-charge-observe-full733.sh "$PWD" %{_uke_out} '+tail+'\n');
}
replace('%changelog\n','%changelog\n* Wed Nov 11 2026 Uke contributors - '+t.evr+'\n- Restore passive legacy protection reads and version explicit native observations.\n- Preserve native demand capability,standard getters and the cumulative hardware baseline.\n\n');
let inverse=after;for(const[a,b,n]of changes.toReversed()){if(inverse.split(b).length!==n+1)throw Error('Inverse count');inverse=inverse.replaceAll(b,()=>a);}inverse=inverse.replace(next,()=>old);if(inverse!==before)throw Error('Unrelated full22 recipe changed');
for(const section of ['check','install']){
 const block=after.split('\n%'+section+'\n')[1].split(/\n%[a-z]/)[0];
 for(const declaration of ['charge_observe_parent=$(bash native-profile/packaging/native/charge-observe-legacy-view733.sh "$PWD")','charge_demand_parent=$(bash native-profile/packaging/native/charge-demand-legacy-view733.sh "$charge_observe_parent")'])if(block.split(declaration).length!==2)throw Error('Independent scope missing');
}
fs.writeFileSync(output,after);console.log('Protection observation recipe: complete full22 inverse,explicit historical source views,both RPM scopes and unchanged production config.');
NODE

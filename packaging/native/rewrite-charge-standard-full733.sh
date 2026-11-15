#!/usr/bin/bash
set -Eeuo pipefail
[[ $# == 4 ]]
tuple=$(bash "$(dirname -- "$0")/../../scripts/kernel-release.sh" json "$4")
[[ ! -e $2 ]]
node - "$1" "$2" "$3" "$tuple" <<'NODE'
const fs=require('fs'),crypto=require('crypto'),[input,output,manifest,json]=process.argv.slice(2),m=JSON.parse(fs.readFileSync(manifest)),t=JSON.parse(json),before=fs.readFileSync(input,'utf8');
if(crypto.createHash('sha256').update(before).digest('hex')!==m.parent_spec_sha256||t.version!=='7.3.3'||t.release!==m.parent_full_release+1||t.source_check_release!==m.proof.source_check_release)throw Error('Parent/tuple mismatch');
const old='%global senemos_build_release '+m.parent_full_release+'\n',next='%global senemos_build_release '+t.release+'\n';if(before.split(old).length!==2)throw Error('Release count');let after=before.replace(old,next);const changes=[];
function replace(a,b,n=1){if(after.split(a).length!==n+1)throw Error('Recipe anchor:'+a);after=after.replaceAll(a,b);changes.push([a,b,n]);}
replace('Provides: uke-kernel(battery-status-event-v1) = 1\n','Provides: uke-kernel(battery-status-event-v1) = 1\nProvides: uke-kernel(charge-standard-observed-thresholds-v1) = 1\n');
const source='bash native-profile/packaging/native/prepare-battery-event-full733.sh "$PWD" %{_uke_out} source\n';replace(source,source+'bash native-profile/packaging/native/prepare-charge-standard-full733.sh "$PWD" %{_uke_out} source\n');
replace('battery_event_parent=$(bash native-profile/packaging/native/battery-event-legacy-view733.sh "$PWD")\n','charge_standard_parent=$(bash native-profile/packaging/native/charge-standard-legacy-view733.sh "$PWD")\n'+'battery_event_parent=$(bash native-profile/packaging/native/battery-event-legacy-view733.sh "$charge_standard_parent")\n',2);
for(const phase of ['linked','install']){const tail=phase+(phase==='install'?" '%{buildroot}'":'');const line='bash native-profile/packaging/native/prepare-battery-event-full733.sh "$PWD" %{_uke_out} '+tail+'\n';replace(line,line+'bash native-profile/packaging/native/prepare-charge-standard-full733.sh "$PWD" %{_uke_out} '+tail+'\n');}
replace('%changelog\n','%changelog\n* Wed Nov 11 2026 Uke contributors - '+t.evr+'\n- Expose observed charge thresholds through standard power_supply getters.\n- Preserve writer admission,all cumulative hardware features and recovery.\n\n');
let inverse=after;for(const[a,b,n]of changes.toReversed()){if(inverse.split(b).length!==n+1)throw Error('Inverse count');inverse=inverse.replaceAll(b,a);}inverse=inverse.replace(next,old);if(inverse!==before)throw Error('Unrelated full20 recipe/gate changed');
for(const section of ['check','install']){const block=after.split('\n%'+section+'\n')[1].split(/\n%[a-z]/)[0];for(const declaration of ['charge_standard_parent=$(bash native-profile/packaging/native/charge-standard-legacy-view733.sh "$PWD")','battery_event_parent=$(bash native-profile/packaging/native/battery-event-legacy-view733.sh "$charge_standard_parent")'])if(block.split(declaration).length!==2)throw Error('Missing independent RPM scope');}
fs.writeFileSync(output,after);console.log('Cumulative standard charge recipe: complete full20 inverse,both local parent scopes,three additive phases and unchanged production config.');
NODE

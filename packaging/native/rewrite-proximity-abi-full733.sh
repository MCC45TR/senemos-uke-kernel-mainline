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
replace('Provides: uke-kernel(ssc-heading-iio-v1) = 1\n','Provides: uke-kernel(ssc-heading-iio-v1) = 1\nProvides: uke-kernel(ssc-proximity-input-v1) = 1\n');
const source='bash native-profile/packaging/native/prepare-heading-full733.sh "$PWD" %{_uke_out} source\n';replace(source,source+'bash native-profile/packaging/native/prepare-proximity-abi-full733.sh "$PWD" %{_uke_out} source\n');
const declaration='proximity_parent=$(bash native-profile/packaging/native/proximity-abi-legacy-view733.sh "$PWD")\n';replace('heading_parent=$(bash native-profile/packaging/native/heading-legacy-view733.sh "$PWD")\n',declaration+'heading_parent=$(bash native-profile/packaging/native/heading-legacy-view733.sh "$proximity_parent")\n',2);
for(const phase of ['linked','install']){const tail=phase+(phase==='install'?" '%{buildroot}'":''),line='bash native-profile/packaging/native/prepare-heading-full733.sh "$PWD" %{_uke_out} '+tail+'\n';replace(line,line.replace('"$PWD"','"$proximity_parent"')+'bash native-profile/packaging/native/prepare-proximity-abi-full733.sh "$PWD" %{_uke_out} '+tail+'\n');}
replace('%changelog\n','%changelog\n* Tue Nov 10 2026 Uke contributors - '+t.evr+'\n- Identify the native proximity input ABI before IIO discovery.\n- Preserve raw sensor values,firmware ownership,audio,config and recovery.\n\n');
let inverse=after;for(const[a,b,n]of changes.toReversed()){if(inverse.split(b).length!==n+1)throw Error('Inverse count');inverse=inverse.replaceAll(b,a);}inverse=inverse.replace(next,old);if(inverse!==before)throw Error('Unrelated full17 recipe or gate changed');
for(const name of ['check-stable733.sh','check-avr-transaction733.sh','check-speaker-inclusion.sh'])for(const line of before.split('\n').filter(x=>x.includes(name+' "$PWD"')&&x.includes('linked')))if(!after.split('\n').includes(line))throw Error('Actual linked gate redirected');
for(const phase of ['%check\n','%install\n']){const block=after.split(phase)[1]?.split(/\n%[a-z]/)[0];if(!block||!block.includes(declaration)||!block.includes('prepare-proximity-abi-full733.sh "$PWD"'))throw Error('RPM shell-local scope missing');}
fs.writeFileSync(output,after);console.log('Cumulative proximity ABI recipe: complete full17 inverse,three additive phases and separate RPM shell scopes; actual objects retained.');
NODE

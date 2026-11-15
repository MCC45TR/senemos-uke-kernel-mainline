#!/usr/bin/bash
# Exact full16 recipe extension; actual production objects are never replaced.
set -Eeuo pipefail
[[ $# == 4 ]]
tuple=$(bash "$(dirname -- "$0")/../../scripts/kernel-release.sh" json "$4")
[[ ! -e $2 ]]
node - "$1" "$2" "$3" "$tuple" <<'JS'
const fs=require('fs'),crypto=require('crypto'),[input,output,manifest,json]=process.argv.slice(2),m=JSON.parse(fs.readFileSync(manifest)),t=JSON.parse(json),before=fs.readFileSync(input,'utf8');
if(crypto.createHash('sha256').update(before).digest('hex')!==m.parent_spec_sha256||t.version!=='7.3.3'||t.release!==m.parent_full_release+1||t.source_check_release!==m.proof.source_check_release)throw Error('Parent/tuple mismatch');
const old='%global senemos_build_release '+m.parent_full_release+'\n',next='%global senemos_build_release '+t.release+'\n';if(before.split(old).length!==2)throw Error('Release count');let after=before.replace(old,next);const changes=[];
function replace(a,b,n=1){if(after.split(a).length!==n+1)throw Error('Recipe anchor:'+a);after=after.replaceAll(a,b);changes.push([a,b,n]);}
replace('Provides: uke-kernel(ssc-iio-v1) = 1\n','Provides: uke-kernel(ssc-iio-v1) = 1\nProvides: uke-kernel(ssc-heading-iio-v1) = 1\n');
const prep='bash native-profile/prepare.sh "$PWD"\n';replace(prep,'(cd native-profile;sha256sum -c --strict --quiet SHA256SUMS)\nbash native-profile/tests/ssc-heading-math.sh\nbash native-profile/packaging/native/preflight-ssc-heading733.sh "$PWD"\n'+prep);
const a='bash native-profile/packaging/native/prepare-quaternion-buffer-full733.sh "$PWD" %{_uke_out} source\n';replace(a,a+'bash native-profile/packaging/native/prepare-heading-full733.sh "$PWD" %{_uke_out} source\n');
const declaration='heading_parent=$(bash native-profile/packaging/native/heading-legacy-view733.sh "$PWD")\n';replace('buffer_parent=$(bash native-profile/packaging/native/quaternion-buffer-legacy-view733.sh "$PWD")\n',declaration+'buffer_parent=$(bash native-profile/packaging/native/quaternion-buffer-legacy-view733.sh "$heading_parent")\n',2);
for(const phase of ['linked','install']){const tail=phase+(phase==='install'?" '%{buildroot}'":''),a='bash native-profile/packaging/native/prepare-quaternion-buffer-full733.sh "$PWD" %{_uke_out} '+tail+'\n';replace(a,a.replace('"$PWD"','"$heading_parent"')+'bash native-profile/packaging/native/prepare-heading-full733.sh "$PWD" %{_uke_out} '+tail+'\n');}
const entry='* Tue Nov 10 2026 Uke contributors - '+t.evr+'\n- Expose admitted ROTV magnetic heading through the standard IIO channel.\n- Share firmware demand and preserve raw quaternion ABI,audio,config and recovery.\n\n';replace('%changelog\n','%changelog\n'+entry);
let inverse=after;for(const[a,b,n]of changes.toReversed()){if(inverse.split(b).length!==n+1)throw Error('Inverse count');inverse=inverse.replaceAll(b,a);}inverse=inverse.replace(next,old);if(inverse!==before)throw Error('Unrelated parent recipe or gate changed');
for(const name of ['check-stable733.sh','check-avr-transaction733.sh','check-speaker-inclusion.sh'])for(const line of before.split('\n').filter(x=>x.includes(name+' "$PWD"')&&x.includes('linked')))if(!after.split('\n').includes(line))throw Error('Actual gate redirected');
fs.writeFileSync(output,after);console.log('Cumulative heading recipe: complete full16 inverse,early actual-source checks,three additive phases and authenticated parent views; actual output retained.');
JS

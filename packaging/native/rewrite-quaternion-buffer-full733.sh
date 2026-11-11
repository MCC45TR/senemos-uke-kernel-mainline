#!/usr/bin/bash
# Data-only, additive full15 recipe transformation with a complete inverse.
set -Eeuo pipefail
[[ $# == 4 ]]
tuple=$(bash "$(dirname -- "$0")/../../scripts/kernel-release.sh" json "$4")
[[ ! -e $2 ]]
node - "$1" "$2" "$3" "$tuple" <<'NODE'
const fs=require('fs'),crypto=require('crypto'),[input,output,manifest,json]=process.argv.slice(2),m=JSON.parse(fs.readFileSync(manifest)),t=JSON.parse(json),before=fs.readFileSync(input,'utf8');
if(crypto.createHash('sha256').update(before).digest('hex')!==m.parent_spec_sha256||t.release!==m.parent_full_release+1||t.source_check_release!==80||t.version!=='7.3.3')throw Error('Parent/tuple mismatch');
const old='%global senemos_build_release '+m.parent_full_release+'\n',next='%global senemos_build_release '+t.release+'\n';if(before.split(old).length!==2)throw Error('Release count');let after=before.replace(old,next);const changes=[];
function replace(a,b,count=1){if(after.split(a).length!==count+1)throw Error('Recipe anchor:'+a);after=after.replaceAll(a,b);changes.push([a,b,count]);}
const source='bash native-profile/packaging/native/prepare-quaternion-full733.sh "$PWD" %{_uke_out} source\n';replace(source,source+'bash native-profile/packaging/native/prepare-quaternion-buffer-full733.sh "$PWD" %{_uke_out} source\n');
const declaration='buffer_parent=$(bash native-profile/packaging/native/quaternion-buffer-legacy-view733.sh "$PWD")\n';
replace('quaternion_parent=$(bash native-profile/packaging/native/quaternion-legacy-view733.sh "$PWD")\n',declaration+'quaternion_parent=$(bash native-profile/packaging/native/quaternion-legacy-view733.sh "$buffer_parent")\n',2);
for(const phase of ['linked','install']){const tail=phase+(phase==='install'?" '%{buildroot}'":''),a='bash native-profile/packaging/native/prepare-quaternion-full733.sh "$PWD" %{_uke_out} '+tail+'\n',b=a.replace('"$PWD"','"$buffer_parent"')+'bash native-profile/packaging/native/prepare-quaternion-buffer-full733.sh "$PWD" %{_uke_out} '+tail+'\n';replace(a,b);}
const entry='* Tue Nov 10 2026 Uke contributors - '+t.evr+'\n- Size quaternion scan storage using the real IIO repeat-four alignment.\n- Preserve prior hardware, scalar/vector layouts, protected audio and A/B recovery.\n\n';replace('%changelog\n','%changelog\n'+entry);
let inverse=after;for(const[a,b,count]of changes.toReversed()){if(inverse.split(b).length!==count+1)throw Error('Inverse count');inverse=inverse.replaceAll(b,a);}inverse=inverse.replace(next,old);if(inverse!==before)throw Error('Unrelated recipe or gate changed');
for(const name of ['check-stable733.sh','check-avr-transaction733.sh','check-speaker-inclusion.sh'])for(const line of before.split('\n').filter(l=>l.includes(name+' "$PWD"')&&l.includes('linked')))if(!after.split('\n').includes(line))throw Error('Actual linked gate redirected');
fs.writeFileSync(output,after);console.log('Cumulative quaternion buffer recipe: complete full15 inverse, actual new output and authenticated parent source views; no retained gate removed.');
NODE

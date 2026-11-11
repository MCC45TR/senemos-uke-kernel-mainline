#!/usr/bin/bash
# Extend the exact admitted full14 recipe; every old byte has an inverse.
set -Eeuo pipefail
[[ $# == 4 ]]
tuple=$(bash "$(dirname -- "$0")/../../scripts/kernel-release.sh" json "$4")
[[ ! -e $2 ]]
node - "$1" "$2" "$3" "$tuple" <<'NODE'
const fs=require('fs'),crypto=require('crypto'),[input,output,manifest,json]=process.argv.slice(2),m=JSON.parse(fs.readFileSync(manifest)),t=JSON.parse(json),before=fs.readFileSync(input,'utf8');
if(crypto.createHash('sha256').update(before).digest('hex')!==m.parent_spec_sha256||t.version!=='7.3.3'||t.release!==m.parent_full_release+1||t.source_check_release!==m.proof.source_check_release)throw Error('Parent/derived tuple mismatch');
const old='%global senemos_build_release '+m.parent_full_release+'\n',next='%global senemos_build_release '+t.release+'\n';
if(before.split(old).length!==2)throw Error('Parent release count');let after=before.replace(old,next);const added=[];
for(const phase of ['source','linked','install']){
 const tail=phase+(phase==='install'?" '%{buildroot}'":''),anchor='bash native-profile/packaging/native/prepare-gravity-full733.sh "$PWD" %{_uke_out} '+tail+'\n',line='bash native-profile/packaging/native/prepare-quaternion-full733.sh "$PWD" %{_uke_out} '+tail+'\n';
 if(after.split(anchor).length!==2)throw Error('Parent phase count:'+phase);after=after.replace(anchor,anchor+line);added.push(line);
}
const declaration='quaternion_parent=$(bash native-profile/packaging/native/quaternion-legacy-view733.sh "$PWD")\n',oldInit='gravity_parent=$(bash native-profile/packaging/native/gravity-legacy-view733.sh "$PWD")\n',newInit='gravity_parent=$(bash native-profile/packaging/native/gravity-legacy-view733.sh "$quaternion_parent")\n';
if(after.split(oldInit).length!==2)throw Error('Gravity declaration');after=after.replace(oldInit,declaration+newInit);
const replaced=[];
for(const phase of ['linked','install']){
 const tail=phase+(phase==='install'?" '%{buildroot}'":''),a='bash native-profile/packaging/native/prepare-gravity-full733.sh "$PWD" %{_uke_out} '+tail+'\n',b=a.replace('"$PWD"','"$quaternion_parent"');
 if(after.split(a).length!==2)throw Error('Gravity actual phase:'+phase);after=after.replace(a,(phase==='install'?declaration:'')+b);replaced.push([a,b]);
}
const entry='* Tue Nov 10 2026 Uke contributors - '+t.evr+'\n- Publish three firmware quaternion streams through standard atomic IIO reads.\n- Preserve all prior hardware, protected audio, config and A/B recovery.\n\n';if(after.split('%changelog\n').length!==2)throw Error('Changelog');after=after.replace('%changelog\n','%changelog\n'+entry);
let inverse=after.replace(next,old).replace(entry,'');for(const line of added){if(inverse.split(line).length!==2)throw Error('Quaternion phase inverse');inverse=inverse.replace(line,'');}
if(inverse.split(declaration).length!==3)throw Error('RPM parent declaration inverse');inverse=inverse.replaceAll(declaration,'').replace(newInit,oldInit);for(const[a,b]of replaced)inverse=inverse.replace(b,a);if(inverse!==before)throw Error('Parent recipe/gate changed');
for(const name of ['check-avr-transaction733.sh','check-stable733.sh','check-speaker-inclusion.sh']){const a=before.split('\n').find(l=>l.includes('bash native-profile/packaging/native/'+name+' "$PWD"')&&l.includes('linked'));if(!a||!after.split('\n').includes(a))throw Error('Actual source gate redirected');}
fs.writeFileSync(output,after);console.log('Cumulative quaternion recipe: complete full14 inverse, three additive phases and two scoped source projections; actual Image/modules/objects retained.');
NODE

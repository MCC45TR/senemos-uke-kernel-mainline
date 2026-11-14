#!/usr/bin/bash
# Data-only, invertible extension of the exact admitted production recipe.
set -Eeuo pipefail
[[ $# == 4 ]]
input=$1
output=$2
manifest=$3
tuple=$(bash "$(dirname -- "$0")/../../scripts/kernel-release.sh" json "$4")
[[ ! -e $output ]]
node - "$input" "$output" "$manifest" "$tuple" <<'NODE'
const fs=require('fs'),crypto=require('crypto'),[input,output,manifest,tuple]=process.argv.slice(2);
const m=JSON.parse(fs.readFileSync(manifest)),t=JSON.parse(tuple),before=fs.readFileSync(input,'utf8');
if(crypto.createHash('sha256').update(before).digest('hex')!==m.parent_spec_sha256||
   t.version!=='7.3.3'||t.release!==m.parent_full_release+1||
   t.source_check_release!==m.proof.source_check_release)throw Error('Production recipe/tuple mismatch');
const old='%global senemos_build_release '+m.parent_full_release,
      current='%global senemos_build_release '+t.release;
if(before.split(old+'\n').length!==2)throw Error('Parent release count');
let after=before.replace(old+'\n',current+'\n');
const buildLine='bash boot-recipe/src/boot/build-payload.sh "$PWD" %{_uke_out} %{uke_boot_userspace}/base \'%{krel}\' "$jobs"\n';
if(after.split(buildLine).length!==2)throw Error('Parent full-build boundary');
const begin=after.indexOf(buildLine)+buildLine.length,end=after.indexOf('\n%install\n',begin);
if(end<begin)throw Error('Parent install boundary');
const priorLinked=after.slice(begin,end);
const parentChecks=new Set([
 'packaging/native/check-dual-light-delivery733.sh',
 'packaging/native/check-dual-light-binding733.sh',
 'packaging/native/check-memory-compression733.sh',
 'packaging/native/check-hall-initial733.sh',
 'packaging/native/check-migration-cohort731.sh',
 'packaging/native/check-cumulative-camera731.sh',
 'packaging/native/check-camera-next731.sh',
 'packaging/native/check-proximity-input733.sh',
 'packaging/native/dual-light-legacy-view733.sh',
]),seen=new Set();
const oldCalls=priorLinked.split('\n').map(line=>{
 const match=line.match(/bash native-profile\/([^ ]+) "\$PWD"/);
 if(!match||!parentChecks.has(match[1]))return line;
 if(seen.has(match[1])||line.split('"$PWD"').length!==2)throw Error('Duplicate SSC parent call');
 seen.add(match[1]);return line.replace('"$PWD"','"$gravity_parent"');
}).join('\n');
if(seen.size!==parentChecks.size)throw Error('Incomplete SSC parent-call boundary');
const linkedCount=seen.size;
const abiBefore='cmp native-profile/src/sensors/sysfs-driver-uke-ssc Documentation/ABI/testing/sysfs-driver-uke-ssc';
const abiAfter='cmp native-profile/src/sensors/sysfs-driver-uke-ssc "$gravity_parent/Documentation/ABI/testing/sysfs-driver-uke-ssc"';
if(priorLinked.split(abiBefore).length!==2)throw Error('Parent ABI comparison count');
const parentLine='gravity_parent=$(bash native-profile/packaging/native/gravity-legacy-view733.sh "$PWD")\n';
const checkStart='%check\n';
if(oldCalls.split(checkStart).length!==2)throw Error('Parent RPM check-shell boundary');
const projected=oldCalls.replace(checkStart,checkStart+parentLine).replace(abiBefore,abiAfter);
after=after.slice(0,begin)+projected+after.slice(end);
const added=[];
for(const phase of ['source','linked','install']){
 const tail=phase+(phase==='install'?" '%{buildroot}'":'');
 const previous=phase==='install'?'install -m644 native-profile/source-composition.json %{_uke_out}/module-signing.x509 "$identity/"\n':
 'bash native-profile/packaging/native/prepare-pcm-surround-full733.sh "$PWD" %{_uke_out} '+tail+'\n';
 const next='bash native-profile/packaging/native/prepare-gravity-full733.sh "$PWD" %{_uke_out} '+tail+'\n';
 if(after.split(previous).length!==2)throw Error('Missing parent phase:'+phase);
 after=after.replace(previous,previous+next);added.push(next);
}
const entry='* Tue Nov 10 2026 Uke contributors - '+t.evr+'\n'+
 '- Add one native SSC gravity and linear acceleration stream with standard IIO axes.\n'+
 '- Retain protected audio, existing sensor channels, production config and A/B delivery.\n\n';
if(after.split('%changelog\n').length!==2)throw Error('Changelog count');
after=after.replace('%changelog\n','%changelog\n'+entry);
// Git patch checks and make kernelrelease must use the actual source root.
// A parent projection's unrelated branches are intentionally symbolic links.
for(const name of ['check-avr-transaction733.sh','check-stable733.sh','check-speaker-inclusion.sh']){
 const line=before.split('\n').find(l=>l.includes('bash native-profile/packaging/native/'+name+' "$PWD"')&&l.includes('linked'));
 if(!line||!after.split('\n').includes(line))throw Error('Unrelated actual-source check redirected:'+name);
}
let inverse=after.replace(current+'\n',old+'\n').replace(entry,'');
for(const line of added){if(inverse.split(line).length!==2)throw Error('Gravity phase count');inverse=inverse.replace(line,'');}
if(inverse.split(parentLine).length!==2)throw Error('Parent view declaration count');
inverse=inverse.replace(parentLine,'').replace(abiAfter,abiBefore).replaceAll('"$gravity_parent"','"$PWD"');
if(inverse!==before)throw Error('Existing production recipe or gate changed');
fs.writeFileSync(output,after);
console.log('Cumulative gravity recipe: complete parent inverse, three additive phases, authenticated parent text projection for '+linkedCount+' old calls and ABI comparison; actual linked objects retained.');
NODE

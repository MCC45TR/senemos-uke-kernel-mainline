#!/usr/bin/bash
# Data-only full23 recipe rewrite; preserve every old source/native/RPM gate.
set -Eeuo pipefail
[[ $# == 4 && ! -e $2 ]]
tuple=$(bash "$(dirname -- "$0")/../../scripts/kernel-release.sh" json "$4")
node - "$1" "$2" "$3" "$tuple" <<'NODE'
const fs=require('fs'),crypto=require('crypto'),[input,output,manifest,json]=process.argv.slice(2),m=JSON.parse(fs.readFileSync(manifest)),t=JSON.parse(json),before=fs.readFileSync(input,'utf8');
if(crypto.createHash('sha256').update(before).digest('hex')!==m.parent_spec_sha256||t.version!=='7.3.3'||t.release!==m.parent_full_release+1||t.source_check_release!==m.proof.source_check_release)throw Error('Parent/tuple mismatch');
const old='%global senemos_build_release '+m.parent_full_release+'\n',next='%global senemos_build_release '+t.release+'\n';
if(before.split(old).length!==2)throw Error('Release count');let after=before.replace(old,()=>next);const changes=[];
function replace(a,b){if(after.split(a).length!==2)throw Error('Recipe anchor:'+a);after=after.replace(a,()=>b);changes.push([a,b]);}
replace('Provides: uke-kernel(charge-protection-observe-v2) = 1\n','Provides: uke-kernel(charge-protection-observe-v2) = 1\nProvides: uke-kernel(storage-encryption-config-v1) = 1\n');
replace('BuildRequires: libasan libubsan\n','BuildRequires: libasan libubsan\nBuildRequires: nodejs\n');
const boot='bash boot-recipe/src/boot/build-payload.sh "$PWD" %{_uke_out} %{uke_boot_userspace}/base \'%{krel}\' "$jobs"\n';
replace(boot,boot+'bash native-profile/packaging/native/prepare-storage-config-full733.sh "$PWD" %{_uke_out} linked\n');
replace('%check\n','%check\nbash native-profile/packaging/native/prepare-storage-config-full733.sh "$PWD" %{_uke_out} check \'%{buildroot}\'\n');
const install='bash native-profile/packaging/native/prepare-charge-observe-full733.sh "$PWD" %{_uke_out} install \'%{buildroot}\'\n';
replace(install,install+'bash native-profile/packaging/native/prepare-storage-config-full733.sh "$PWD" %{_uke_out} install \'%{buildroot}\'\n');
replace('%changelog\n','%changelog\n* Wed Nov 11 2026 Uke contributors - '+t.evr+'\n- Enable the qualified native filesystem and block encryption capability layer.\n- Retain all other kernel settings,reference checks and protected223 features.\n- Keep encrypted I/O,TEE key operations and encrypted boot unqualified.\n\n');
let inverse=after;for(const[a,b]of changes.toReversed()){if(inverse.split(b).length!==2)throw Error('Inverse count');inverse=inverse.replace(b,()=>a);}inverse=inverse.replace(next,()=>old);if(inverse!==before)throw Error('Unrelated full23 recipe changed');
if(!after.split('%build\n')[1].split('%check\n')[0].includes('prepare-storage-config-full733.sh "$PWD" %{_uke_out} linked'))throw Error('Linked proof must precede RPM install');
fs.writeFileSync(output,after);console.log('Storage full recipe:complete full23 inverse,linked admission before install,existing six outputs and all old gates retained.');
NODE

#!/usr/bin/bash
# Exact additive full24 recipe extension; retain every original statement.
set -Eeuo pipefail
[[ $# == 4 && ! -e $2 ]]
tuple=$(bash "$(dirname -- "$0")/../../scripts/kernel-release.sh" json "$4")
node - "$1" "$2" "$3" "$tuple" <<'JS'
const fs=require('fs'),crypto=require('crypto'),[i,o,c,json]=process.argv.slice(2),m=JSON.parse(fs.readFileSync(c)),t=JSON.parse(json),before=fs.readFileSync(i,'utf8'),sha=x=>crypto.createHash('sha256').update(x).digest('hex');
if(sha(before)!==m.parent_spec_sha256||t.version!=='7.3.3'||t.release!==m.parent_full_release+1||t.source_check_release!==108)throw Error('Parent/tuple drift');
let after=before;const changes=[];function replace(old,next,count=1){if(after.split(old).length!==count+1)throw Error('Recipe anchor: '+old);after=after.replaceAll(old,()=>next);changes.push([old,next,count]);}
replace('%global senemos_build_release 24\n','%global senemos_build_release '+t.release+'\n');
replace('Source8: singleboot-LICENSE\n','Source8: singleboot-LICENSE\nSource190: uke-native-hardware-delivery.tar.xz\n');
replace('Provides: uke-kernel(ssc-proximity-input-v1) = 1\n','Provides: uke-kernel(ssc-proximity-input-v1) = 1\nProvides: uke-kernel(camcc-crmc-resources-v1) = 1\nProvides: uke-kernel(ssc-stream-buffer-fresh-v1) = 1\n');
replace('\n%build\n','\ntar -xJf %{SOURCE190}\n(cd native-hardware; jq -r \'.source_assets[]|.sha256+"  "+.path\' manifests/native-hardware-delivery-20261113.json | sha256sum -c --strict --quiet -)\nbash native-hardware/tests/native-hardware-source-view.sh\n\n%build\n');
const boot='bash boot-recipe/src/boot/build-payload.sh "$PWD" %{_uke_out} %{uke_boot_userspace}/base \'%{krel}\' "$jobs"\n';
replace(boot,'bash native-hardware/packaging/native/prepare-native-hardware-full733.sh "$PWD" %{_uke_out} source\n'+boot+'bash native-hardware/packaging/native/prepare-native-hardware-full733.sh "$PWD" %{_uke_out} linked\n');
replace('\n%check\n','\n%check\nbash native-hardware/packaging/native/prepare-native-hardware-full733.sh "$PWD" %{_uke_out} check \'%{buildroot}\'\nuke_native_parent=$(bash native-hardware/packaging/native/native-hardware-legacy-view733.sh "$PWD")\n');
replace('\n%install\n','\nbash native-hardware/packaging/native/prepare-native-hardware-full733.sh "$PWD" %{_uke_out} sealed\n\n%install\nuke_native_parent=$(bash native-hardware/packaging/native/native-hardware-legacy-view733.sh "$PWD")\n');
replace('\n%files\n','\nbash native-hardware/packaging/native/prepare-native-hardware-full733.sh "$PWD" %{_uke_out} install \'%{buildroot}\'\n\n%files\n');
replace('proximity_parent=$(bash native-profile/packaging/native/proximity-abi-legacy-view733.sh "$PWD")','proximity_parent=$(bash native-profile/packaging/native/proximity-abi-legacy-view733.sh "$uke_native_parent")',2);
for(const phase of ['linked','install'])replace('bash native-profile/packaging/native/prepare-proximity-abi-full733.sh "$PWD" %{_uke_out} '+phase,'bash native-profile/packaging/native/prepare-proximity-abi-full733.sh "$uke_native_parent" %{_uke_out} '+phase);
replace('cmp native-profile/src/camera/camcc-sm7675.c drivers/clk/qcom/camcc-sm7675.c','cmp native-profile/src/camera/camcc-sm7675.c "$uke_native_parent/drivers/clk/qcom/camcc-sm7675.c"');
replace('%changelog\n','%changelog\n* Fri Nov 13 2026 Uke contributors - '+t.evr+'\n- Adopt complete native CAMCC resource ownership and preserve firmware refusal.\n- Wait for real SSC streaming reports instead of replaying cached samples.\n- Retain full24 checks through authenticated source views and seal actual ELFs.\n- Keep physical camera, gravity frame and device acceptance separate.\n\n');
let inverse=after;for(const [old,next,count]of changes.toReversed()){if(inverse.split(next).length!==count+1)throw Error('Inverse anchor');inverse=inverse.replaceAll(next,()=>old);}if(inverse!==before)throw Error('Original full24 recipe changed');
for(const name of ['prep','build','install','check','changelog'])if((after.match(new RegExp('^%'+name+'$','mg'))??[]).length!==1)throw Error('Duplicate section '+name);
if(after.indexOf('prepare-proximity-abi-full733.sh "$PWD" %{_uke_out} source')>after.indexOf('prepare-native-hardware-full733.sh "$PWD" %{_uke_out} source'))throw Error('Late SSC source order');
fs.writeFileSync(o,after);console.log('Full native hardware recipe: exact complete full24 inverse, ordered late source changes, targeted source-view arguments and all original checks/package names retained');
JS

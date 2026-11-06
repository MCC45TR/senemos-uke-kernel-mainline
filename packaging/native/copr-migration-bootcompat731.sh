#!/usr/bin/env bash
# COPR only. Extend complete12207; preserve every driver/config/DT/firmware gate.
set -Eeuo pipefail
trap 'printf "Boot compatibility source guard failed at line%s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?Source result directory}")
revision=${2:?Unique unstable revision}
mode=${3:?check or full}
proof=${4:?Check release or admitted build}
[[ $revision == 12208 && ($mode == check || $mode == full) && $proof =~ ^[1-9][0-9]*$ ]]
commit=$(git -C "$owner" rev-parse HEAD)
stage=$(mktemp -d);trap 'find "$stage" -depth -delete' EXIT
[[ $(curl -q -fLsS --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11268117 | jq -er .state) == succeeded ]]
if [[ $mode == full ]];then
 [[ $# == 5 && $5 =~ ^[a-f0-9]{64}$ ]]
 curl -q -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$proof" > "$stage/proof.json"
 jq -e '.state=="succeeded" and .source_package.name=="uke-kernel-migration-check"' "$stage/proof.json" >/dev/null
 url=$(curl -q -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build-chroot/$proof/fedora-rawhide-aarch64" | jq -er .result_url)
 evr=$(jq -er .source_package.version "$stage/proof.json")
 curl -q -fLsS --max-time 90 "${url}uke-kernel-migration-check-$evr.fc46.aarch64.rpm" -o "$stage/proof.rpm"
 printf '%s  %s\n' "$5" "$stage/proof.rpm" | sha256sum -c --strict -
 [[ $(rpm2cpio "$stage/proof.rpm" | cpio -i --to-stdout --quiet '*source-commit') == "$commit" ]]
 bash "$owner/packaging/native/refuse-published-release.sh" senemos-uke-linux-kernel-mainline-unstable "7.3.1-$revision"
else
 [[ $# == 4 ]]
 bash "$owner/packaging/native/refuse-published-release.sh" uke-kernel-migration-check "7.3.1-$proof"
fi
[[ ! -e $output || (-d $output && -z $(find "$output" -mindepth 1 -maxdepth 1 -print -quit)) ]]
mkdir -p "$output" "$stage/unpacked"
curl -q -fLsS --retry 2 --max-time 600 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11268117/senemos-uke-linux-kernel-mainline-unstable-7.3.1-12207.src.rpm -o "$stage/parent.src.rpm"
printf '%s  %s\n' 2d8a02cfdb2ea8e5ea554a9d4f62dac21536a6ea4e4859004cd5106bed4dfdee "$stage/parent.src.rpm" | sha256sum -c --strict -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.1-12207 ]]
rpm2cpio "$stage/parent.src.rpm" > "$stage/parent.cpio"
cpio -t --quiet < "$stage/parent.cpio" | awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}'
(cd "$output";cpio -idm --quiet --no-absolute-filenames < "$stage/parent.cpio")
native=senemos-native-profile-7.3.1.tar.xz
boot_archive=senemos-uke-boot-recipe.tar.xz
spec=$output/senemos-uke-linux-kernel-mainline-unstable.spec
(cd "$output";find . -maxdepth 1 -type f ! -name "${spec##*/}" ! -name "$native" ! -name "$boot_archive" ! -name boot-payload.json -print0 | sort -z | xargs -0 sha256sum) > "$stage/retained"
for archive in "$native" "$boot_archive";do tar -xJf "$output/$archive" -C "$stage/unpacked";done
profile=$stage/unpacked/native-profile
boot=$stage/unpacked/boot-recipe
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
jq -e '.source_commit=="5fbe231e12679776e5bb069ff6af5b5e9a9db570" and .kernel_release=="7.3.1-12207-unstable" and .speaker_graph_open_failure_scope_layer==1 and .camcc_quarantine_s2idle_layer==1 and .boot_header_zero_version_layer==1 and .speaker_gain_ceiling==223 and .speaker_protection_graph_admitted and (.speaker_physical_protection_qualified|not)' "$profile/source-composition.json" >/dev/null
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$stage/configs"
assets=(src/boot/boot-image.cpp tests/migration-boot-header.sh tests/bootloader-compat-contract.sh manifests/bootloader-compat-20261106.json docs/BOOTLOADER-COMPATIBILITY.md)
for tree in "$profile" "$boot";do
 printf '%s  %s\n' d8391eacf845448f3134892f1be431ba1e3f51c58aa522370728ff4965f3dcfa "$tree/src/boot/boot-image.cpp" | sha256sum -c --strict -
 for asset in "${assets[@]}";do
  if [[ -f $tree/$asset ]];then install -Dm644 "$tree/$asset" "$tree/history-before-boot-compat/$asset";fi
  install -Dm644 "$owner/$asset" "$tree/$asset"
 done
 # Preserve the entire authenticated parent recipe, including peer additions.
 recipe=$tree/src/boot/build-payload.sh
 install -Dm644 "$recipe" "$tree/history-before-boot-compat/src/boot/build-payload.sh"
 [[ $(grep -Fc '"$out/boot-image" create ' "$recipe") == 2 ]]
 [[ $(grep -Fxc '"$out/boot-image" inspect "$out/linux.img" > "$out/boot-header.json"' "$recipe") == 1 ]]
 sed '
 s|^"[$]out/boot-image" create |"$out/boot-image" create-bootloader-compat |
 /^"[$]out\/boot-image" inspect "[$]out\/linux[.]img" > "[$]out\/boot-header[.]json"$/a\
 jq -e ".os_version_encoded==570425768 and (.avb_footer_present|not)" "$out/boot-header.json" >/dev/null\
 "$out/boot-image" inspect "$out/userdata.img" | jq -e ".os_version_encoded==570425768 and (.avb_footer_present|not)" >/dev/null
 ' "$recipe" > "$stage/recipe.sh"
 install -m644 "$stage/recipe.sh" "$recipe"
 sha256sum "$tree/history-before-boot-compat/src/boot/build-payload.sh" "$recipe"
 [[ $(grep -Fc '"$out/boot-image" create-bootloader-compat ' "$tree/src/boot/build-payload.sh") == 2 ]]
 ! grep -F '"$out/boot-image" create ' "$tree/src/boot/build-payload.sh"
 [[ $(grep -Fo uke7.3.1-12207u "$tree/src/audio/uke-audio-card.c" | wc -l) == 2 ]]
 sed "s/uke7[.]3[.]1-12207u/uke7.3.1-${revision}u/g" "$tree/src/audio/uke-audio-card.c" > "$stage/card.c"
 install -m644 "$stage/card.c" "$tree/src/audio/uke-audio-card.c"
done
cp "$profile/source-composition.json" "$profile/source-composition-before-boot-compat.json"
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg source "$commit" --arg revision "$revision" '.+{source_commit:$source,rpm_revision:$revision,kernel_release:("7.3.1-"+$revision+"-unstable"),diagnostic_audio_driver:("uke7_3_1-"+$revision+"u"),bootcompat_parent_build:11268117,bootcompat_parent_source:"5fbe231e12679776e5bb069ff6af5b5e9a9db570",boot_header_disabled_verification_fallback_layer:1,shipping_boot_header_mode:"explicit-bootloader-compat",shipping_boot_header_os_version_encoded:570425768,canonical_zero_header_support_retained:true,bootloader_compatibility_physical_accepted:false,device_installation:false,physical_acceptance:false}' "$profile/source-composition-before-boot-compat.json" > "$profile/source-composition.json"
install -m644 "$profile/prepare.sh" "$boot/packaging/native/cumulative-prepare.sh"
sha256sum -c --strict --quiet "$stage/configs"
for tree in "$profile" "$boot";do
 if [[ $tree == "$profile" ]];then
  (cd "$tree";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
 else
  (cd "$tree";find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$stage/assets.sha256"
  jq -Rn '[inputs|capture("^(?<sha256>[a-f0-9]{64})  [.]?/?(?<path>.*)$")]|map({path,sha256})' < "$stage/assets.sha256" > "$stage/assets.json"
  jq --slurpfile assets "$stage/assets.json" '.source_assets=$assets[0]' "$boot/lock.json" > "$stage/lock.json"
  install -m644 "$stage/lock.json" "$boot/lock.json"
 fi
done
install -m644 "$boot/lock.json" "$output/boot-payload.json"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
for tree in native-profile boot-recipe;do
 archive=$native;[[ $tree != boot-recipe ]] || archive=$boot_archive
 tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$archive" -C "$stage/unpacked" "$tree"
done
awk -v revision="$revision" '
 /^%global senemos_build_release 12207$/ {$0="%global senemos_build_release "revision;changed++}
 /^%changelog$/ {print;print "* Fri Nov 06 2026 Uke contributors - 7.3.1-"revision;print "- Select explicit bootloader compatibility metadata for alternating slots.";print "- Retain canonical zero-header support, protected223 and complete12207 hardware.";print "";next}
 {print} END {if(changed!=1)exit 1}
' "$spec" > "$stage/full.spec"
install -m644 "$stage/full.spec" "$spec"
if [[ $mode == check ]];then
 printf '%s  %s\n' 5493807ca28533b0bd0caa497754d99b4d366a852047a1dfb367c46b483830cd "$owner/packaging/native/copr-migration-cohort731.sh" | sha256sum -c --strict -
 awk '/^if \[\[ \$mode == check \]\]; then$/ {copy=1;next} copy && /^fi$/ {exit} copy {print}' "$owner/packaging/native/copr-migration-cohort731.sh" | sed 's| drivers/iio/common/uke-ssc/uke-ssc.o drivers/input/misc/qcom-smp2p-switch.o| sound/soc/qcom/qdsp6/q6apm.o drivers/clk/qcom/camcc-sm7675.o drivers/iio/common/uke-ssc/uke-ssc.o drivers/input/misc/qcom-smp2p-switch.o|' > "$stage/check-packaging.sh"
 test -s "$stage/check-packaging.sh"
 source "$stage/check-packaging.sh"
 sed -i 's/Complete12204/Complete12207/g' "$output/uke-kernel-migration-check.spec"
fi
(cd "$output";sha256sum -c --strict --quiet "$stage/retained")
printf 'Complete12207 retained; explicit slot-compatible boot metadata prepared for planned%s/%s.\n' "$revision" "$mode"

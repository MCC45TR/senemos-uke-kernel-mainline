#!/usr/bin/env bash
# COPR only. Signed upstream7.3.3 with complete17, protected audio and VRR.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' manifests/stable733-cumulative-20261107.json | sha256sum -c --strict --quiet -)
output=$(realpath -m "${1:?Source result directory}")
revision=${2:?Unique unstable revision}
mode=${3:?check or full}
proof=${4:?Check release or admitted build}
[[ $revision == 1 && ($mode == check || $mode == full) && $proof =~ ^[1-9][0-9]*$ ]]
commit=$(git -C "$owner" rev-parse HEAD)
stage=$(mktemp -d);trap 'find "$stage" -depth -delete' EXIT
if [[ $mode == full ]];then
 [[ $# == 5 && $5 =~ ^[a-f0-9]{64}$ ]]
 curl -q -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$proof" > "$stage/proof.json"
 jq -e '.state=="succeeded" and .source_package.name=="uke-kernel-migration-check" and .source_package.version=="7.3.3-2"' "$stage/proof.json" >/dev/null
 url=$(curl -q -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build-chroot/$proof/fedora-rawhide-aarch64" | jq -er .result_url)
 curl -q -fLsS --max-time 90 "${url}uke-kernel-migration-check-7.3.3-2.fc46.aarch64.rpm" -o "$stage/proof.rpm"
 printf '%s  %s\n' "$5" "$stage/proof.rpm" | sha256sum -c --strict -
 [[ $(rpm2cpio "$stage/proof.rpm" | cpio -i --to-stdout --quiet '*source-commit') == "$commit" ]]
 bash "$owner/packaging/native/refuse-published-release.sh" senemos-uke-linux-kernel-mainline-unstable "7.3.3-$revision"
else
 [[ $# == 4 && $proof == 2 ]]
 bash "$owner/packaging/native/refuse-published-release.sh" uke-kernel-migration-check "7.3.3-$proof"
fi
[[ ! -e $output || (-d $output && -z $(find "$output" -mindepth 1 -maxdepth 1 -print -quit)) ]]
mkdir -p "$output" "$stage/unpacked"
[[ $(curl -q -fLsS --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11282652 | jq -er .state) == succeeded ]]
curl -q -fLsS --retry 2 --max-time 600 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11282652/senemos-uke-linux-kernel-mainline-unstable-7.3.1-12217.src.rpm -o "$stage/parent.src.rpm"
printf '%s  %s\n' 1ed01a889b5b4ccf19eb0a0984851858213a3d3a83310446b57fe820296b21f6 "$stage/parent.src.rpm" | sha256sum -c --strict -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.1-12217 ]]
rpm2cpio "$stage/parent.src.rpm" > "$stage/parent.cpio"
cpio -t --quiet < "$stage/parent.cpio" | awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}'
(cd "$output";cpio -idm --quiet --no-absolute-filenames < "$stage/parent.cpio")
native=senemos-native-profile-7.3.1.tar.xz
boot_archive=senemos-uke-boot-recipe.tar.xz
spec=$output/senemos-uke-linux-kernel-mainline-unstable.spec
(cd "$output";find . -maxdepth 1 -type f ! -name "${spec##*/}" ! -name "$native" ! -name "$boot_archive" ! -name boot-payload.json ! -name linux-7.3.1.tar.xz ! -name linux-7.3.1.tar.sign ! -name senemos-uke-adaptation-7.3.1.tar.xz -print0 | sort -z | xargs -0 sha256sum) > "$stage/retained"
for archive in "$native" "$boot_archive" senemos-uke-adaptation-7.3.1.tar.xz;do tar -xJf "$output/$archive" -C "$stage/unpacked";done
profile=$stage/unpacked/native-profile
boot=$stage/unpacked/boot-recipe
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
jq -e '.source_commit=="a6238e4593b67e3dce5a8fa9ccbc74ea4f221dc9" and .kernel_release=="7.3.1-12217-unstable" and .protected_stop_native_admitted and .protected_stop_qualification_build==11282644 and .speaker_gain_ceiling==223 and (.speaker_physical_protection_qualified|not)' "$profile/source-composition.json" >/dev/null
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$stage/configs"
assets=(packaging/native/check-idle-stop731.sh docs/STABLE-733-CUMULATIVE.md manifests/linux-7.3.3.json manifests/stable733-cumulative-20261107.json src/audio/0019-uke-idle-legacy-fixture.patch src/display/0075-o82-vrr-floor-api.patch src/display/apply-vrr-api731.sh tests/o82-vrr-api.c tests/o82-vrr-api.sh packaging/native/check-vrr-api731.sh docs/VRR-FLOOR-ABI.md manifests/audio-vrr-20261107.json src/audio/0017-uke-protected-idle-worker.patch src/audio/0018-uke-idle-stop-source-seals.patch src/audio/apply-idle-stop731.sh tests/audio-idle-stop.c tests/audio-idle-stop.sh packaging/native/check-idle-stop731.sh docs/PROTECTED-IDLE-WORKER.md manifests/idle-stop-worker-20261107.json manifests/kernel-migration-full12217-20261107.json)
assets+=(tests/unstable-boot-family731-contract.sh packaging/native/check-stable733.sh src/boot/stable733-native-version-guards.patch src/boot/stable733-boot-version-guards.patch)
for tree in "$profile" "$boot";do
 (cd "$tree";jq -r '.retained_helper_hashes|to_entries[]|.value.before+"  "+.key' "$owner/manifests/stable733-cumulative-20261107.json" | sha256sum -c --strict -)
 for asset in "${assets[@]}";do install -Dm644 "$owner/$asset" "$tree/$asset";done
 (cd "$tree";jq -r '.retained_helper_hashes|to_entries[]|.value.after+"  "+.key' manifests/stable733-cumulative-20261107.json | sha256sum -c --strict -)
 kind=native_profile;guard_patch=stable733-native-version-guards.patch
 if [[ $tree == "$boot" ]];then kind=boot_recipe;guard_patch=stable733-boot-version-guards.patch;fi
 (cd "$tree";jq -r --arg kind "$kind" '.version_helper_hashes[$kind]|to_entries[]|.value.before+"  "+.key' manifests/stable733-cumulative-20261107.json | sha256sum -c --strict -)
 git -C "$tree" apply --check --whitespace=error "$owner/src/boot/$guard_patch"
 git -C "$tree" apply --whitespace=error "$owner/src/boot/$guard_patch"
 (cd "$tree";jq -r --arg kind "$kind" '.version_helper_hashes[$kind]|to_entries[]|.value.after+"  "+.key' manifests/stable733-cumulative-20261107.json | sha256sum -c --strict -)
 [[ $(grep -Fo uke7.3.1-12217u "$tree/src/audio/uke-audio-card.c" | wc -l) == 2 ]]
 sed "s/uke7[.]3[.]1-12217u/uke7.3.3-${revision}u/g" "$tree/src/audio/uke-audio-card.c" > "$stage/card.c"
 install -m644 "$stage/card.c" "$tree/src/audio/uke-audio-card.c"
 # Source archives include both exact17 and authenticated18 checker paths.
 (cd "$tree";jq -r '.checker_hashes|to_entries[]|.value.before+"  "+.key' manifests/idle-stop-worker-20261107.json | sha256sum -c --strict -)
 git -C "$tree" apply --check --whitespace=error "$owner/src/audio/0018-uke-idle-stop-source-seals.patch"
 git -C "$tree" apply --whitespace=error "$owner/src/audio/0018-uke-idle-stop-source-seals.patch"
 (cd "$tree";jq -r '.checker_hashes|to_entries[]|.value.after+"  "+.key' manifests/idle-stop-worker-20261107.json | sha256sum -c --strict -)
 # Only retained synthetic peers gain the new callback; no assertion changes.
 (cd "$tree";jq -r '.retained_fixture_hashes|to_entries[]|.value.before+"  "+.key' manifests/audio-vrr-20261107.json | sha256sum -c --strict -)
 git -C "$tree" apply --check --whitespace=error "$owner/src/audio/0019-uke-idle-legacy-fixture.patch"
 git -C "$tree" apply --whitespace=error "$owner/src/audio/0019-uke-idle-legacy-fixture.patch"
 (cd "$tree";jq -r '.retained_fixture_hashes|to_entries[]|.value.after+"  "+.key' manifests/audio-vrr-20261107.json | sha256sum -c --strict -)
done
cp "$profile/source-composition.json" "$profile/source-composition-before-idle-stop.json"
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg source "$commit" --arg revision "$revision" --arg mode "$mode" --arg proof "$proof" '.+{source_commit:$source,rpm_revision:$revision,kernel_release:("7.3.3-"+$revision+"-unstable"),diagnostic_audio_driver:("uke7_3_3-"+$revision+"u"),upstream_version:"7.3.3",upstream_commit:"d50d994bffa3c7c6db2d8bc4c5f0c55e3f46b0cd",upstream_sha256:"79c66dde66cd96877fcde8f7d36aec946b1f423d2b97b5a7b1751b75c764f3d1",upstream_stable_cumulative_layer:1,upstream_stable_parent_version:"7.3.1",upstream_stable_parent_build:11282652,upstream_stable_native_admitted:($mode=="full"),upstream_stable_qualification_build:(if $mode=="full" then ($proof|tonumber) else null end),protected_idle_worker_layer:1,protected_idle_parent_build:11282652,protected_idle_parent_source:"a6238e4593b67e3dce5a8fa9ccbc74ea4f221dc9",protected_idle_atomic_guard_classification:true,protected_idle_real_faults_retained:true,protected_idle_native_admitted:($mode=="full"),protected_idle_qualification_build:(if $mode=="full" then ($proof|tonumber) else null end),vrr_saved_floor_api_layer:1,vrr_saved_floor_api_get_only:true,vrr_kernel_default_and_display_admission_unchanged:true,vrr_saved_floor_native_admitted:($mode=="full"),vrr_saved_floor_qualification_build:(if $mode=="full" then ($proof|tonumber) else null end),device_installation:false,physical_acceptance:false}' "$profile/source-composition-before-idle-stop.json" > "$profile/source-composition.json"
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
# Independently authenticate the actual replacement source and original patch queue.
archive=$output/linux-7.3.3.tar.xz
curl -q -fLsS --retry 2 --max-time 600 https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.3.3.tar.xz -o "$archive"
printf '%s  %s\n' 79c66dde66cd96877fcde8f7d36aec946b1f423d2b97b5a7b1751b75c764f3d1 "$archive" | sha256sum -c --strict -
curl -q -fLsS --max-time 45 https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.3.3.tar.sign -o "$output/linux-7.3.3.tar.sign"
keyring=$stage/keyring;mkdir -m700 "$keyring"
gpg --homedir "$keyring" --batch --import "$output/linux-stable.asc"
xz -cd "$archive" | gpg --homedir "$keyring" --batch --status-fd 1 --verify "$output/linux-7.3.3.tar.sign" - > "$stage/verification.status"
gpgconf --homedir "$keyring" --kill gpg-agent
awk '$1=="[GNUPG:]"&&$2=="VALIDSIG"&&$NF=="647F28654894E3BD457199BE38DBBDC86092693E" {good++} END{if(good!=1)exit 1}' "$stage/verification.status"
signer=$(awk '$1=="[GNUPG:]"&&$2=="VALIDSIG" {print $3}' "$stage/verification.status")
tar -xOJf "$archive" linux-7.3.3/Makefile | awk '$1=="VERSION"{v=$3}$1=="PATCHLEVEL"{p=$3}$1=="SUBLEVEL"{s=$3}END{if(v"."p"."s!="7.3.3")exit 1}'
adaptation=$stage/unpacked/senemos-adaptation
cp "$adaptation/source-lock.json" "$stage/adaptation-parent.json"
jq --arg signer "$signer" '.version="7.3.3"|.upstream_commit="d50d994bffa3c7c6db2d8bc4c5f0c55e3f46b0cd"|.source_url="https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.3.3.tar.xz"|.signature_url="https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.3.3.tar.sign"|.source_sha256="79c66dde66cd96877fcde8f7d36aec946b1f423d2b97b5a7b1751b75c764f3d1"|.source_date_epoch=1793989159|.signer=$signer' "$stage/adaptation-parent.json" > "$adaptation/source-lock.json"
jq -S 'del(.version,.upstream_commit,.source_url,.signature_url,.source_sha256,.source_date_epoch,.signer)' "$stage/adaptation-parent.json" > "$stage/old-patch-lock"
jq -S 'del(.version,.upstream_commit,.source_url,.signature_url,.source_sha256,.source_date_epoch,.signer)' "$adaptation/source-lock.json" | cmp - "$stage/old-patch-lock"
for suffix in tar.xz tar.sign;do rm "$output/linux-7.3.1.$suffix";done
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
for tree in native-profile boot-recipe;do
 archive=$native;[[ $tree != boot-recipe ]] || archive=$boot_archive
 tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$archive" -C "$stage/unpacked" "$tree"
done
mv "$output/$native" "$output/senemos-native-profile-7.3.3.tar.xz"
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/senemos-uke-adaptation-7.3.3.tar.xz" -C "$stage/unpacked" senemos-adaptation
rm "$output/senemos-uke-adaptation-7.3.1.tar.xz"
awk -v revision="$revision" '
 /^Version: 7[.]3[.]1$/ {$0="Version: 7.3.3";versioned++}
 /^Summary: Mainline Linux 7[.]3[.]1 / {sub("7.3.1","7.3.3")}
 /^%if "%\{version\}" == "7[.]3[.]1"$/ {sub(/7[.]3[.]1/,"7.3.3")}
 /^export SOURCE_DATE_EPOCH=1793362198$/ {$0="export SOURCE_DATE_EPOCH=1793989159"}
 /^%global senemos_build_release 12217$/ {$0="%global senemos_build_release "revision;changed++}
 /^bash native-profile\/src\/audio\/apply-protected-stop731.sh / {print;print "bash native-profile/src/audio/apply-idle-stop731.sh \"$PWD\" \"$PWD/native-profile\"";print "bash native-profile/src/display/apply-vrr-api731.sh \"$PWD\" \"$PWD/native-profile\"";prepared++;next}
 /^%check$/ {print;print "bash native-profile/packaging/native/check-stable733.sh \"$PWD\" %{_uke_out} linked";checked++;next}
 /^%changelog$/ {print;print "* Sat Nov 07 2026 Uke contributors - 7.3.3-1";print "- Classify healthy idle atomically while retaining output fault containment.";print "- Expose read-only O82 VRR floor ABI and both parameter type fields.";print "- Preserve complete12217, calibrated protection and automatic A/B staging.";print "";history++;next}
 {print} END {if(versioned!=1||changed!=1||history!=1||prepared!=1||checked!=1)exit 1}
 ' "$spec" > "$stage/idle-stop.spec"
install -m644 "$stage/idle-stop.spec" "$spec"
if [[ $mode == check ]];then
 printf '%s  %s\n' 5493807ca28533b0bd0caa497754d99b4d366a852047a1dfb367c46b483830cd "$owner/packaging/native/copr-migration-cohort731.sh" | sha256sum -c --strict -
 awk '/^if \[\[ \$mode == check \]\]; then$/ {copy=1;next} copy && /^fi$/ {exit} copy {print}' "$owner/packaging/native/copr-migration-cohort731.sh" | sed 's| drivers/iio/common/uke-ssc/uke-ssc.o drivers/input/misc/qcom-smp2p-switch.o| drivers/base/core.o drivers/base/dd.o drivers/gpu/drm/msm/msm_gem_shrinker.o drivers/usb/core/driver.o drivers/usb/core/message.o sound/core/control.o drivers/soc/qcom/apr.o sound/soc/qcom/qdsp6/audioreach.o sound/soc/qcom/qdsp6/q6apm.o sound/soc/codecs/fs19xx.o drivers/clk/qcom/camcc-sm7675.o drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.o sound/soc/qcom/qdsp6/uke-fs19xx-oob-check.o sound/soc/qcom/qdsp6/uke-fs19xx-oob-backend.o sound/soc/qcom/qdsp6/snd-q6apm.o drivers/soc/qcom/uke-audio-config-memory.o drivers/misc/fastrpc.o drivers/iommu/arm/arm-smmu/arm-smmu-qcom.o drivers/iio/common/uke-ssc/uke-ssc.o drivers/input/misc/qcom-smp2p-switch.o|' > "$stage/check-packaging.sh"
 test -s "$stage/check-packaging.sh"
 source "$stage/check-packaging.sh"
 awk '
  $0=="bash native-profile/packaging/native/check-migration-cohort731.sh \"$PWD\" %{_uke_out} objects" {print "bash native-profile/packaging/native/check-oob-objects731.sh \"$PWD\" %{_uke_out}";print "bash native-profile/packaging/native/check-stable733.sh \"$PWD\" %{_uke_out} objects";added++}
  {print} END {if(added!=1)exit 1}
 ' "$output/uke-kernel-migration-check.spec" > "$stage/check.spec"
 install -m644 "$stage/check.spec" "$output/uke-kernel-migration-check.spec"
fi
(cd "$output";sha256sum -c --strict --quiet "$stage/retained")
printf 'Signed7.3.3 prepared with complete17 hardware/audio/VRR controls for%s; no target operation.\n' "$mode"

#!/usr/bin/env bash
# COPR only. Extend exact full12216 with muted output/VI drain ordering before full12217.
set -Eeuo pipefail
trap 'printf "Muted STOP source guard failed at line%s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
(cd "$owner"; jq -r '.source_assets[]|.sha256+"  "+.path' manifests/protected-stop-drain-20261107.json | sha256sum -c --strict --quiet -)
output=$(realpath -m "${1:?Source result directory}")
revision=${2:?Unique unstable revision}
mode=${3:?check or full}
proof=${4:?Check release or admitted build}
[[ $revision == 12217 && ($mode == check || $mode == full) && $proof =~ ^[1-9][0-9]*$ ]]
commit=$(git -C "$owner" rev-parse HEAD)
stage=$(mktemp -d);trap 'find "$stage" -depth -delete' EXIT
[[ $(curl -q -fLsS --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11272573 | jq -er .state) == succeeded ]]
if [[ $mode == full ]];then
 [[ $# == 5 && $5 =~ ^[a-f0-9]{64}$ ]]
 curl -q -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$proof" > "$stage/proof.json"
 jq -e '.state=="succeeded" and .source_package.name=="uke-kernel-migration-check" and .source_package.version=="7.3.1-36"' "$stage/proof.json" >/dev/null
 url=$(curl -q -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build-chroot/$proof/fedora-rawhide-aarch64" | jq -er .result_url)
 curl -q -fLsS --max-time 90 "${url}uke-kernel-migration-check-7.3.1-36.fc46.aarch64.rpm" -o "$stage/proof.rpm"
 printf '%s  %s\n' "$5" "$stage/proof.rpm" | sha256sum -c --strict -
 [[ $(rpm2cpio "$stage/proof.rpm" | cpio -i --to-stdout --quiet '*source-commit') == "$commit" ]]
 rpm2cpio "$stage/proof.rpm" | cpio -i --to-stdout --quiet '*source-composition.json' | jq -e '.protected_stop_drain_layer==1 and .protected_gpr_client_byte_native_admitted and .protected_initial_ready_native_admitted and .protected_config_smmu_native_admitted and .protected_oob_native_backend_admitted and .protected_oob_final_dt_native_admitted and (.protected_stop_native_admitted|not) and (.physical_acceptance|not)' >/dev/null
 bash "$owner/packaging/native/refuse-published-release.sh" senemos-uke-linux-kernel-mainline-unstable "7.3.1-$revision"
else
 [[ $# == 4 && $proof == 36 ]]
 bash "$owner/packaging/native/refuse-published-release.sh" uke-kernel-migration-check "7.3.1-$proof"
fi
[[ ! -e $output || (-d $output && -z $(find "$output" -mindepth 1 -maxdepth 1 -print -quit)) ]]
mkdir -p "$output" "$stage/unpacked"
curl -q -fLsS --retry 2 --max-time 600 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11272573/senemos-uke-linux-kernel-mainline-unstable-7.3.1-12216.src.rpm -o "$stage/parent.src.rpm"
printf '%s  %s\n' 021491be63b8068e4c6edae4591817c51a2a5d72ce0ba0b9a118dbe3cf927cee "$stage/parent.src.rpm" | sha256sum -c --strict -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.1-12216 ]]
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
jq -e '.source_commit=="4d9ccc1b9c9d343e63f99e00e77550491aeb6698" and .kernel_release=="7.3.1-12216-unstable" and .protected_gpr_client_byte_native_admitted and .protected_gpr_client_byte_qualification_build==11272542 and .protected_initial_ready_native_admitted and .protected_initial_ready_qualification_build==11272542 and .protected_gpr_client_data_native_admitted and .protected_gpr_client_data_qualification_build==11271965 and .protected_config_smmu_native_admitted and .protected_config_smmu_qualification_build==11271445 and .protected_oob_final_dt_native_admitted and .protected_oob_final_dt_qualification_build==11271114 and .protected_oob_native_backend_admitted and .protected_oob_native_qualification_build==11270738 and .protected_oob_supplier_readiness_before_probe and .cdsp_dma_admission_check==11270377 and .speaker_gain_ceiling==223 and .speaker_protection_graph_admitted and (.speaker_physical_protection_qualified|not)' "$profile/source-composition.json" >/dev/null
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$stage/configs"
assets=(src/audio/0015-uke-protected-stop-drain.patch src/audio/0016-uke-protected-stop-source-seals.patch src/audio/uke-fs19xx-muted-stop.h src/audio/apply-protected-stop731.sh tests/audio-protected-stop.c tests/audio-protected-stop.sh tests/audio-protected-stop-seal.sh packaging/native/check-protected-stop731.sh docs/PROTECTED-STOP-DRAIN.md manifests/protected-stop-drain-20261107.json manifests/kernel-migration-full12216-20261107.json)
for tree in "$profile" "$boot";do
 for asset in "${assets[@]}";do install -Dm644 "$owner/$asset" "$tree/$asset";done
 [[ $(grep -Fo uke7.3.1-12216u "$tree/src/audio/uke-audio-card.c" | wc -l) == 2 ]]
 sed "s/uke7[.]3[.]1-12216u/uke7.3.1-${revision}u/g" "$tree/src/audio/uke-audio-card.c" > "$stage/card.c"
 install -m644 "$stage/card.c" "$tree/src/audio/uke-audio-card.c"
done
# Preserve exact16 checkers; extend strict source identities without dropping their gates.
for tree in "$profile" "$boot";do
 install -Dm644 "$tree/packaging/native/check-oob-runtime731.sh" "$tree/history-before-protected-stop/packaging/native/check-oob-runtime731.sh"
 printf '%s  %s\n' 566bcdac08d51165a6e0080d22f6ee491f350bb0ec0cc50df1f78fcf20fb7993 "$tree/packaging/native/check-oob-runtime731.sh" | sha256sum -c --strict -
 install -Dm644 "$tree/packaging/native/check-client-byte-ready731.sh" "$tree/history-before-protected-stop/packaging/native/check-client-byte-ready731.sh"
 printf '%s  %s\n' 0101afe68e6092203b6b4f1cbd9c09a0f239114766087ebe530e8e3635bdc0f6 "$tree/packaging/native/check-client-byte-ready731.sh" | sha256sum -c --strict -
 install -Dm644 "$tree/packaging/native/check-speaker-inclusion.sh" "$tree/history-before-protected-stop/packaging/native/check-speaker-inclusion.sh"
 printf '%s  %s\n' 514a460eb7d0af84096a1ed1062b7a120bef76d22c421ad6278e8c6495e21887 "$tree/packaging/native/check-speaker-inclusion.sh" | sha256sum -c --strict -
 patch -d "$tree" --dry-run --batch --fuzz=0 -p1 -i "$owner/src/audio/0016-uke-protected-stop-source-seals.patch"
 patch -d "$tree" --batch --fuzz=0 -p1 -i "$owner/src/audio/0016-uke-protected-stop-source-seals.patch"
 printf '%s  %s\n' 08da7b78c062d95135c21c12614561bd67494434c848be7671fd5f38119a887b "$tree/packaging/native/check-oob-runtime731.sh" | sha256sum -c --strict -
 printf '%s  %s\n' b64c55bb7571f271dbde91689a11721546918d5735a4f5ddcf232328a9340773 "$tree/packaging/native/check-client-byte-ready731.sh" | sha256sum -c --strict -
 printf '%s  %s\n' 7d543876ba0a3a9524d4216f8c76765c873c83758536d025a664e2a35492f03d "$tree/packaging/native/check-speaker-inclusion.sh" | sha256sum -c --strict -
done
cp "$profile/source-composition.json" "$profile/source-composition-before-protected-stop.json"
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg source "$commit" --arg revision "$revision" --arg mode "$mode" --arg proof "$proof" '.+{source_commit:$source,rpm_revision:$revision,kernel_release:("7.3.1-"+$revision+"-unstable"),diagnostic_audio_driver:("uke7_3_1-"+$revision+"u"),protected_stop_drain_layer:1,protected_stop_parent_build:11272573,protected_stop_parent_source:"4d9ccc1b9c9d343e63f99e00e77550491aeb6698",protected_stop_mute_before_dsp:true,protected_stop_vi_until_reply:true,protected_stop_poweroff_after_reply:true,protected_stop_failure_erases:true,protected_stop_existing_fault_deadline:true,protected_stop_no_gain_calibration_change:true,protected_stop_native_admitted:($mode=="full"),protected_stop_qualification_build:(if $mode=="full" then ($proof|tonumber) else null end),device_installation:false,physical_acceptance:false}' "$profile/source-composition-before-protected-stop.json" > "$profile/source-composition.json"
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
 /^%global senemos_build_release 12216$/ {$0="%global senemos_build_release "revision;changed++}
 /^%build$/ {print "bash native-profile/src/audio/apply-protected-stop731.sh \"$PWD\" \"$PWD/native-profile\"";prepared++}
 /^%check$/ {print;print "bash native-profile/packaging/native/check-protected-stop731.sh \"$PWD\" %{_uke_out} linked";checked++;next}
 /^%changelog$/ {print;print "* Sat Nov 07 2026 Uke contributors - 7.3.1-12217";print "- Mute output while retaining VI transport until protected DSP STOP completes.";print "- Preserve full12216 features, calibration/gain, failure erasure and automatic staging.";print "";history++;next}
 {print} END {if(changed!=1||history!=1||prepared!=1||checked!=1)exit 1}
' "$spec" > "$stage/protected-stop.spec"
install -m644 "$stage/protected-stop.spec" "$spec"
if [[ $mode == check ]];then
 printf '%s  %s\n' 5493807ca28533b0bd0caa497754d99b4d366a852047a1dfb367c46b483830cd "$owner/packaging/native/copr-migration-cohort731.sh" | sha256sum -c --strict -
 awk '/^if \[\[ \$mode == check \]\]; then$/ {copy=1;next} copy && /^fi$/ {exit} copy {print}' "$owner/packaging/native/copr-migration-cohort731.sh" | sed 's| drivers/iio/common/uke-ssc/uke-ssc.o drivers/input/misc/qcom-smp2p-switch.o| drivers/soc/qcom/apr.o sound/soc/qcom/qdsp6/audioreach.o sound/soc/qcom/qdsp6/q6apm.o sound/soc/codecs/fs19xx.o drivers/clk/qcom/camcc-sm7675.o sound/soc/qcom/qdsp6/uke-fs19xx-oob-check.o sound/soc/qcom/qdsp6/uke-fs19xx-oob-backend.o sound/soc/qcom/qdsp6/snd-q6apm.o drivers/soc/qcom/uke-audio-config-memory.o drivers/misc/fastrpc.o drivers/iommu/arm/arm-smmu/arm-smmu-qcom.o drivers/iio/common/uke-ssc/uke-ssc.o drivers/input/misc/qcom-smp2p-switch.o|' > "$stage/check-packaging.sh"
 test -s "$stage/check-packaging.sh"
 source "$stage/check-packaging.sh"
 awk '
  $0=="bash native-profile/packaging/native/check-migration-cohort731.sh \"$PWD\" %{_uke_out} objects" {print "bash native-profile/packaging/native/check-oob-objects731.sh \"$PWD\" %{_uke_out}";print "bash native-profile/packaging/native/check-protected-stop731.sh \"$PWD\" %{_uke_out} objects";added++}
  {print} END {if(added!=1)exit 1}
 ' "$output/uke-kernel-migration-check.spec" > "$stage/check.spec"
 install -m644 "$stage/check.spec" "$output/uke-kernel-migration-check.spec"
fi
(cd "$output";sha256sum -c --strict --quiet "$stage/retained")
printf 'Complete12216 retained; muted protected STOP admission prepared for%s; no target operation or stable promotion.\n' "$mode"

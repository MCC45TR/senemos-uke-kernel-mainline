#!/usr/bin/env bash
# COPR only. Preserve the running unstable7200 source and add protected audio.
set -Eeuo pipefail
export LC_ALL=C
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
release=${UKE_SPEAKER_BUILD_RELEASE:-7400}
[[ $release =~ ^[1-9][0-9]{3,4}$ && $release -ge 7400 ]]
# Keep the actual running boot-admission bisect and all cumulative non-audio
# inputs. This candidate does not promote or activate a normal-family kernel.
for qualified in 11259638; do
 [[ $(curl -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$qualified" | jq -er .state) == succeeded ]]
done
curl -fLsS --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11259638 |
 jq -e '.state as $state | (["running","succeeded","starting","importing","waiting"]|index($state))!=null and
 .source_package.name=="senemos-uke-linux-kernel-mainline-unstable" and .source_package.version=="7.3.1-7200" and
 .source_package.url=="https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11259638/senemos-uke-linux-kernel-mainline-unstable-7.3.1-7200.src.rpm"' >/dev/null
bash "$owner/packaging/native/refuse-published-release.sh" senemos-uke-linux-kernel-mainline-unstable "7.3.1-$release"
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
mkdir -p "$output" "$stage/unpacked"
curl -fLsS --retry 2 --proto '=https' --proto-redir '=https' --max-time 600 \
 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11259638/senemos-uke-linux-kernel-mainline-unstable-7.3.1-7200.src.rpm -o "$stage/parent.src.rpm"
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.1-7200 ]]
[[ $(rpm -qp --qf '%{SHA256HEADER}' "$stage/parent.src.rpm") == 7a3b23ee15f61f5a22595cf16b15bac0d03f44802c68de5829c444ac28f13e76 ]]
[[ $(rpm -qp --qf '%{PAYLOADSHA256}' "$stage/parent.src.rpm") == de00c0a33bfb051b7981ea2cb6f4e8019a3e57240c4178fa061caba05c6e4690 ]]
rpmkeys --checksig --nosignature --verbose "$stage/parent.src.rpm"
parent_sha=$(sha256sum "$stage/parent.src.rpm");parent_sha=${parent_sha%% *}
rpm2cpio "$stage/parent.src.rpm" > "$stage/parent.cpio"
cpio -t --quiet < "$stage/parent.cpio" | awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}'
(cd "$output";cpio -idm --quiet --no-absolute-filenames < "$stage/parent.cpio")
spec=$output/senemos-uke-linux-kernel-mainline-unstable.spec
native=senemos-native-profile-7.3.1.tar.xz
boot_archive=senemos-uke-boot-recipe.tar.xz
find "$output" -maxdepth 1 -type f ! -name "${spec##*/}" ! -name "$native" ! -name "$boot_archive" ! -name boot-payload.json \
 -print0 | sort -z | xargs -0 sha256sum > "$stage/unchanged-sources.sha256"
for archive in "$native" "$boot_archive"; do
 tar -tJf "$output/$archive" | awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}'
 tar -xJf "$output/$archive" -C "$stage/unpacked"
done
profile=$stage/unpacked/native-profile
boot=$stage/unpacked/boot-recipe
[[ $(cat "$profile/audio-profile") == microphones ]]
(cd "$profile";sha256sum --check --strict --quiet SHA256SUMS)
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --quiet -)
jq -e '.kernel_release=="7.3.1-7200-unstable" and .source_mode=="withdrawn6000-with-isolated-boot-admission-bisection" and
 .native_ssc_iio_abi==1 and .binder_ipc_builtin and .binderfs_builtin and
 .rtc_backend=="qseecom-uefisecapp-RTCInfo" and .rtc_offset_write_readback and .ssc_temperature_unit=="millicelsius" and
 .nfc_atomic_memory_read and .ir_explicit_word_bits==16 and
 .wcd939x_telemetry_readonly==1 and .wcd939x_electrical_settings_unchanged' "$profile/source-composition.json" >/dev/null
parent_commit=$(cat "$profile/source-commit")
[[ $(jq -er .source_commit "$profile/source-composition.json") == "$parent_commit" ]]
cp "$profile/source-composition.json" "$profile/source-composition-before-audio.json"
# Existing audio bytes must match the reviewed retained parent before overlaying.
(cd "$profile";sha256sum -c --strict "$owner/packaging/native/audio-retained-parents.sha256")
for tree in "$profile" "$boot"; do
 (cd "$tree";find . -type f ! -name SHA256SUMS ! -name source-commit ! -name source-composition.json ! -name lock.json \
  ! -name prepare.sh ! -path './src/audio/sm7675-uke-speaker-audio.dtsi' -print0 | sort -z | xargs -0 sha256sum) > "$stage/before.sha256"
 # Retain every other input, including all non-audio source and boot hooks.
 while read -r path; do
  if [[ -f $tree/$path ]]; then
   # Remove only this explicitly reviewed overwritten path from the unchanged set.
   awk -v path="./$path" 'substr($0,67)!=path' "$stage/before.sha256" > "$stage/filtered.sha256"
   mv "$stage/filtered.sha256" "$stage/before.sha256"
  fi
  install -Dm644 "$owner/$path" "$tree/$path"
 done < "$owner/packaging/native/audio-protected-assets.list"
 printf '\n#if defined(UKE_AUDIO_SPEAKERS) && UKE_AUDIO_SPEAKERS\n' >> "$tree/src/audio/sm7675-uke-speaker-audio.dtsi"
 cat "$owner/src/audio/sm7675-uke-protected-speaker.dtsi" >> "$tree/src/audio/sm7675-uke-speaker-audio.dtsi"
 printf '\n#endif\n' >> "$tree/src/audio/sm7675-uke-speaker-audio.dtsi"
 (cd "$tree";sha256sum -c --quiet "$stage/before.sha256")
done
# The original native preparation and all cumulative source hooks execute first.
[[ $(grep -Fxc 'bash "$profile/src/audio/prepare-native-speaker.sh" "$kernel" "$output"' "$profile/prepare.sh") == 0 ]]
printf '\nbash "$profile/src/audio/prepare-native-speaker.sh" "$kernel" "$output"\n' >> "$profile/prepare.sh"
commit=$(git -C "$owner" rev-parse HEAD)
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
printf '%s\n' "$commit" > "$profile/source-commit"
{
 cat "$owner/packaging/native/audio-protected-assets.list"
 printf '%s\n' prepare.sh src/audio/sm7675-uke-speaker-audio.dtsi
} | jq -Rn '[inputs]' > "$stage/audio-overlays.json"
jq --slurpfile overlays "$stage/audio-overlays.json" --arg commit "$commit" --arg release "$release" --arg parent "$parent_sha" --arg parent_commit "$parent_commit" '. + {
 source_commit:$commit,source_mode:"retained-unstable7200-with-private-fs19xx-provisioning-and-speaker-pcm-formats",
 kernel_release:("7.3.1-"+$release+"-unstable"),rpm_revision:$release,kernel_family:"unstable",
 automatic_kernel_activation:false,stable_promotion:false,parent_copr_build:11259638,parent_binary_qualification_required:11259638,
 qualified_source_input_checks:[11259638],parent_source_commit:$parent_commit,
 parent_srpm_sha256:$parent,parent_header_sha256:"7a3b23ee15f61f5a22595cf16b15bac0d03f44802c68de5829c444ac28f13e76",
 parent_payload_sha256:"de00c0a33bfb051b7981ea2cb6f4e8019a3e57240c4178fa061caba05c6e4690",
 parent_composition:"source-composition-before-audio.json",overlays:$overlays[0],
 changed_kernel_files:(((.changed_kernel_files // []) + [
 "include/sound/uke-fs19xx-guard.h","include/uapi/sound/snd_ar_tokens.h",
 "sound/soc/codecs/fs19xx.c","sound/soc/qcom/qdsp6/Makefile",
 "sound/soc/qcom/qdsp6/audioreach.c","sound/soc/qcom/qdsp6/audioreach.h",
 "sound/soc/qcom/qdsp6/audioreach-control-links.h","sound/soc/qcom/qdsp6/topology.c",
 "sound/soc/qcom/qdsp6/q6apm.c","sound/soc/qcom/qdsp6/q6apm.h",
 "sound/soc/qcom/qdsp6/q6apm-dai.c","sound/soc/qcom/qdsp6/q6apm-lpass-dais.c",
 "sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c","sound/soc/qcom/qdsp6/uke-fs19xx-runtime.h",
 "sound/soc/qcom/qdsp6/uke-fs19xx-protocol.h","sound/soc/qcom/qdsp6/uke-fs19xx-safety.h"])|unique),
 speaker_protected_runtime_abi:1,speaker_provisioning_control_access:"write-only",speaker_gain_ceiling:223,
 speaker_formats:["S16_LE","S24_LE","S32_LE"],speaker_rate_hz:48000,speaker_channels:4,
 speaker_tdm_slots:4,speaker_tdm_slot_width:32,speaker_runtime_reader_required:true,speaker_runtime_reader_minimum:"0.3",speaker_calibration_payload_included:false,
 speaker_generic_data_payload_included:false,speaker_physical_protection_qualified:false,
 speaker_adsp_module_execution_verified:false,speaker_higher_gain_admitted:false,
 amplifier_gain_changed:false,electrical_limits_unchanged:true,audio_hardware_settings_unchanged:false,physical_acceptance:false
}' "$profile/source-composition-before-audio.json" > "$profile/source-composition.json"
# Only the exact audio overlays and DT admission change the boot source lock.
{
 cat "$owner/packaging/native/audio-protected-assets.list"
 printf '%s\n' src/audio/sm7675-uke-speaker-audio.dtsi
} > "$stage/boot-overlays"
while read -r path; do
 digest=$(sha256sum "$boot/$path");digest=${digest%% *}
 jq --arg path "$path" --arg digest "$digest" '.source_assets |= (map(select(.path!=$path)) + [{path:$path,sha256:$digest}])' \
  "$boot/lock.json" > "$stage/lock.json"
 mv "$stage/lock.json" "$boot/lock.json"
done < "$stage/boot-overlays"
(cd "$profile";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --quiet -)
for tree in native-profile boot-recipe; do
 archive=$native;[[ $tree != boot-recipe ]] || archive=$boot_archive
 tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$archive" -C "$stage/unpacked" "$tree"
done
install -m644 "$boot/lock.json" "$output/boot-payload.json"
[[ $(grep -Fxc '%global senemos_build_release 7200' "$spec") == 1 ]]
! grep -Eq '^%pre([[:space:]]|$)' "$spec"
awk -v release="$release" '
 /^%global senemos_build_release 7200$/ {$0="%global senemos_build_release " release}
 /^%package core$/ {print;print "Provides: uke-kernel(fs19xx-protected-v1) = 1";print "Requires: uke-speaker-runtime >= 0.3";next}
 /^%package boot$/ {print;print "Requires: uke-speaker-runtime >= 0.3";next}
 /^%check$/ {print;print "bash native-profile/tests/audio-protected-package-contract.sh %{buildroot} %{_uke_out} native-generated '\''%{krel}'\''";next}
 /^%changelog$/ {
  print;
  print "* Wed Nov 04 2026 Uke contributors - 7.3.1-" release;
  print "- Add matched protected speaker DT, graph, calibration provisioning and PCM formats.";
  print "- Retain the unstable ABI and explicit boot selection; require runtime and keep gain 223.";
  print "";next
 }
 {print}
' "$spec" > "$stage/next.spec"
mv "$stage/next.spec" "$spec"
sha256sum -c --quiet "$stage/unchanged-sources.sha256"
[[ $(rpmspec --target aarch64 --define 'dist %{nil}' -q --srpm --qf '%{VERSION}-%{RELEASE}' "$spec") == 7.3.1-$release ]]
bash "$profile/tests/unstable-boot-family731-contract.sh" "$spec"
printf 'Protected speaker candidate %s-unstable prepared from running7200; no activation or private payload\n' "$release"

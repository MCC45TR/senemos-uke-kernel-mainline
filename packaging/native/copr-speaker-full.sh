#!/usr/bin/env bash
# COPR only. Preserve the current normal-channel cumulative source and add audio.
set -Eeuo pipefail
export LC_ALL=C
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
release=${UKE_SPEAKER_BUILD_RELEASE:-2500}
[[ $release =~ ^[1-9][0-9]{3,4}$ && $release -ge 2500 ]]
# The parent includes the installed1600 RTC, cumulative1710 sensors/NFC/IR and
# normal-channel L3 admission, bound-ADSP SSC, large reports and DPU REGDMA.
# Full integration can build in parallel; installation still requires1910 success.
for qualified in 11252138 11252237; do
 [[ $(curl -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$qualified" | jq -er .state) == succeeded ]]
done
curl -fLsS --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11252282 |
 jq -e '.state as $state | (["running","succeeded","starting","importing","waiting"]|index($state))!=null and
 .source_package.name=="senemos-uke-linux-kernel-mainline" and .source_package.version=="7.3.1-1910" and
 .source_package.url=="https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11252282/senemos-uke-linux-kernel-mainline-7.3.1-1910.src.rpm"' >/dev/null
bash "$owner/packaging/native/refuse-published-release.sh" senemos-uke-linux-kernel-mainline "7.3.1-$release"
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
mkdir -p "$output" "$stage/unpacked"
curl -fLsS --retry 2 --proto '=https' --proto-redir '=https' --max-time 600 \
 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11252282/senemos-uke-linux-kernel-mainline-7.3.1-1910.src.rpm -o "$stage/parent.src.rpm"
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/parent.src.rpm") == senemos-uke-linux-kernel-mainline-7.3.1-1910 ]]
[[ $(rpm -qp --qf '%{SHA256HEADER}' "$stage/parent.src.rpm") == ed9d98ecd320d9b52b27b6bb019baa7cc754e6c129effef70a6e1f6e44994fbd ]]
[[ $(rpm -qp --qf '%{PAYLOADSHA256}' "$stage/parent.src.rpm") == 3af38154208e1e36ebb5acbd5a86bcaee63ccb7845fdb5a8d95ff8f4cc9129ae ]]
rpmkeys --checksig --nosignature --verbose "$stage/parent.src.rpm"
parent_sha=$(sha256sum "$stage/parent.src.rpm");parent_sha=${parent_sha%% *}
rpm2cpio "$stage/parent.src.rpm" > "$stage/parent.cpio"
cpio -t --quiet < "$stage/parent.cpio" | awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}'
(cd "$output";cpio -idm --quiet --no-absolute-filenames < "$stage/parent.cpio")
spec=$output/senemos-uke-linux-kernel-mainline.spec
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
jq -e '.kernel_release=="7.3.1-1910" and .native_ssc_iio_abi==1 and .binder_ipc_builtin and .binderfs_builtin and
 .rtc_backend=="qseecom-uefisecapp-RTCInfo" and .rtc_offset_write_readback and .ssc_temperature_unit=="millicelsius" and
 .nfc_atomic_memory_read and .ir_explicit_word_bits==16 and .qualified_ssc_large_report_check==11252237 and
 .ssc_report_type==1 and .ssc_indication_ids==[33,34]' "$profile/source-composition.json" >/dev/null
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
 source_commit:$commit,source_mode:"retained1910-with-private-fs19xx-provisioning-and-speaker-pcm-formats",
 kernel_release:("7.3.1-"+$release),rpm_revision:$release,parent_copr_build:11252282,parent_binary_qualification_required:11252282,
 qualified_source_input_checks:[11252138,11252237],parent_source_commit:$parent_commit,
 parent_srpm_sha256:$parent,parent_header_sha256:"ed9d98ecd320d9b52b27b6bb019baa7cc754e6c129effef70a6e1f6e44994fbd",
 parent_payload_sha256:"3af38154208e1e36ebb5acbd5a86bcaee63ccb7845fdb5a8d95ff8f4cc9129ae",
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
 speaker_protected_runtime_abi:1,speaker_gain_ceiling:223,
 speaker_formats:["S16_LE","S24_LE","S32_LE"],speaker_rate_hz:48000,speaker_channels:4,
 speaker_tdm_slots:4,speaker_tdm_slot_width:32,speaker_runtime_reader_required:true,speaker_calibration_payload_included:false,
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
[[ $(grep -Fxc '%global senemos_build_release 1910' "$spec") == 1 ]]
! grep -Eq '^%pre([[:space:]]|$)' "$spec"
awk -v release="$release" '
 /^%global senemos_build_release 1910$/ {$0="%global senemos_build_release " release}
 /^%package core$/ {print;print "Provides: uke-kernel(fs19xx-protected-v1) = 1";print "Requires: uke-speaker-runtime >= 0.2";next}
 /^%package boot$/ {print;print "Requires(pre): uke-speaker-runtime >= 0.2";next}
 /^%check$/ {print;print "bash native-profile/tests/audio-protected-package-contract.sh %{buildroot} %{_uke_out} native-generated '\''%{krel}'\''";next}
 /^%changelog$/ {
  print "%pre boot";
  print "if ! /usr/bin/uke-speaker-runtime --check; then";
  print " echo '\''Protected speaker prerequisites failed; the previous boot route is retained.'\'' >&2";
  print " exit 1";
  print "fi";
  print "";
  print;
  print "* Wed Nov 04 2026 Uke contributors - 7.3.1-" release;
  print "- Add matched protected speaker DT, graph, calibration provisioning and PCM formats.";
  print "- Require verified read-only calibration before boot-package installation; retain gain 223.";
  print "";next
 }
 {print}
' "$spec" > "$stage/next.spec"
mv "$stage/next.spec" "$spec"
sha256sum -c --quiet "$stage/unchanged-sources.sha256"
[[ $(rpmspec --target aarch64 --define 'dist %{nil}' -q --srpm --qf '%{VERSION}-%{RELEASE}' "$spec") == 7.3.1-$release ]]
printf 'Full protected speaker candidate %s prepared from cumulative1910; no private calibration in source or RPMs\n' "$release"

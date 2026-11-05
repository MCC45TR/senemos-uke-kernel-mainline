#!/usr/bin/env bash
# COPR source/link admission only. A pass does not establish physical protection.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
phase=${2:?prepared or linked}
[[ $phase == prepared || $phase == linked ]]
[[ $phase != linked || $# == 3 ]]
profile=$kernel/native-profile
required=$profile/manifests/speaker-required-inputs-20261105.json
composition=$profile/source-composition.json
if ! jq -e --slurpfile required "$required" '
 .speaker_controls_layer_commit==$required[0].controls_source and
 .speaker_legacy_fixture_layer_commit==$required[0].fixture_source and
 .speaker_state_observer_layer_commit==$required[0].observer_source and
 .speaker_running_state_requires_guard==true and
 .speaker_protected_runtime_abi==$required[0].runtime_abi and
 .speaker_protection_graph_admitted==false and .speaker_gain_ceiling==223 and
 .speaker_physical_protection_qualified==false' "$composition" >/dev/null; then
 echo 'Speaker inclusion: required observer contribution is missing or changed' >&2
 exit 1
fi
(cd "$profile"; sha256sum -c --strict --quiet SHA256SUMS)
if ! (cd "$profile"; jq -r '.files[]|.sha256+"  "+.path' "$required" | sha256sum -c --strict --quiet -); then
 echo 'Speaker inclusion: declared contribution does not match its source bytes' >&2
 exit 1
fi
if ! cmp -s "$profile/src/audio/uke-fs19xx-runtime.c" "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c"; then
 echo 'Speaker inclusion: prepared runtime does not match the qualified source' >&2
 exit 1
fi
[[ $(grep -Fxc 'CFLAGS_uke-fs19xx-runtime.o += -DUKE_FS19XX_CONTROLS_ONLY' "$kernel/sound/soc/qcom/qdsp6/Makefile") == 1 ]]
grep -Eq '^#define[[:space:]]+FS19XX_VOL_DEFAULT[[:space:]]+0xdf([[:space:]]|$)' "$kernel/sound/soc/codecs/fs19xx.c"
grep -Eq '^#define[[:space:]]+FS19XX_VOL_MAX[[:space:]]+FS19XX_VOL_DEFAULT([[:space:]]|$)' "$kernel/sound/soc/codecs/fs19xx.c"
case $phase in
 prepared)
  for compiler in gcc clang; do
   CC=$compiler bash "$profile/tests/audio-speaker-state-read-contract.sh" "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c"
  done
  ;;
 linked)
  output=$(realpath "$3")
  object=$output/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o
  module=$output/sound/soc/qcom/qdsp6/snd-q6apm.ko
  [[ -s $object && -s $module ]]
  release=$(jq -er .kernel_release "$composition")
  [[ $release =~ ^7\.3\.1-[1-9][0-9]*-unstable$ ]]
  [[ $(modinfo -F vermagic "$module") == "$release "* ]]
  bash "$profile/tests/audio-speaker-observer-code.sh" "$object" "$module"
  ! strings "$module" | grep -F 'xiaomi,fs19xx-protected'
  strings "$module" | grep -Fx 'FS19xx Runtime Provisioning'
  strings "$module" | grep -Fx 'FS19xx Protection State'
  ;;
esac
printf 'Speaker inclusion %s passed: qualified observer, ABI1, gain223, graph inactive; no physical safety claim.\n' "$phase"

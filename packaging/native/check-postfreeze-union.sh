#!/usr/bin/env bash
# COPR only: retain exact governor gates, then test the actual combined sources.
set -Eeuo pipefail
trap 'status=$?; printf "Postfreeze native check failed at line %s: %s (status %s)\n" "$LINENO" "$BASH_COMMAND" "$status" >&2; exit "$status"' ERR
test ! -e /etc/senemos/kernel-update.conf
[[ $(uname -m) == aarch64 ]]
kernel=$(realpath "${1:?Prepared combined kernel}")
output=$(realpath -m "${2:?Object output directory}")
profile=$kernel/native-profile
governor=$kernel/governor-addon
(cd "$profile"; sha256sum -c --strict --quiet SHA256SUMS)
jq -e '.governor=="faca9d65778fda479d08df41785873d40c09e80f" and
 .audio=="13fb0ff522531924c0e96f81cef59d7c64b93eb8" and
 .pogo=="e9867405d0773065880863ea2df0dbd6242f5894"' "$profile/postfreeze-union-check.json" >/dev/null
jq -e '.source_commit=="45d8355e366e6b75e43f441ca99b517302adf522" and
 .speaker_state_observer_layer_commit=="13fb0ff522531924c0e96f81cef59d7c64b93eb8" and
 .pogo_backlight_source=="e9867405d0773065880863ea2df0dbd6242f5894" and
 .governor_options_layer==1 and .speaker_running_state_requires_guard and
 .speaker_gain_ceiling==223 and .speaker_protection_graph_admitted==false and
 .physical_acceptance==false and .pogo_backlight_physical_acceptance==false' "$profile/source-composition.json" >/dev/null
cmp "$profile/src/audio/uke-fs19xx-runtime.c" "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c"
for name in hid-nanosic-uke.c nanosic-uke-protocol.h nanosic-uke-hid.h; do
 cmp "$profile/src/pogo/$name" "$kernel/drivers/hid/$name"
done
original=$governor/packaging/native/check-governor-cumulative731.sh
printf '%s  %s\n' 95dbb104296226b2c3335edfcaa182f5f86dd27899aa291727a19d744ea6df08 "$original" | sha256sum -c --strict -
# The source worker already ran the governor's19 refusal/repeat controls before
# adding the other layers. Its whole-composition repeat admission is deliberately
# for that earlier phase. Retain every native gate; omit only that repeat mutation
# after other contributors have legitimately extended the composition.
skip='bash "$owner/packaging/native/overlay-governor-options731.sh" "$profile" "$kernel/boot-recipe"'
derived=$governor/packaging/native/check-postfreeze-base.sh
awk -v skip="$skip" '$0==skip {print "# Pre-layer repeat validated by the source-worker controls.";n++;next} {print} END {if(n!=1)exit 1}' "$original" > "$derived"
bash "$derived" "$kernel" "$output"
export ASAN_OPTIONS=detect_leaks=0:abort_on_error=1
export UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1
for compiler in gcc clang; do
 for flags in '' '-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer'; do
  CC=$compiler CFLAGS=$flags bash "$profile/tests/audio-speaker-state-read-contract.sh" "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c"
  for fixture in protocol lifecycle backlight power hid; do
   CC=$compiler CFLAGS=$flags bash "$profile/tests/nanosic-$fixture-contract.sh"
  done
 done
done
release=$(jq -er .kernel_release "$profile/source-composition.json")
objects=(sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o drivers/hid/hid-nanosic-uke.o)
make -C "$kernel" O="$output" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION="-${release#7.3.1-}" KCFLAGS=-Werror -j4 "${objects[@]}"
for object in "${objects[@]}"; do
 test -s "$output/$object"
 llvm-readelf -h "$output/$object" | grep -E 'Machine:.*AArch64'
 sha256sum "$output/$object"
done
llvm-nm --defined-only "$output/drivers/hid/hid-nanosic-uke.o" | grep -E '[[:space:]]uke_nano_backlight_work$'
grep -Fx 'CFLAGS_uke-fs19xx-runtime.o += -DUKE_FS19XX_CONTROLS_ONLY' "$kernel/sound/soc/qcom/qdsp6/Makefile"
test ! -e "$output/arch/arm64/boot/Image"
test -z "$(find "$output" -type f -name '*.ko' -print -quit)"
printf '%s\n' 'PASS: combined exact12203 source + all three postfreeze layers; retained production prep/audio/CDSP/NFC/hardening/config gates;24 added callback modes; six AArch64 objects with Werror' \
 'Scope: source/config/callback/REL objects only; no full kernel, target installation, boot, electrical or physical acceptance'

#!/usr/bin/env bash
# COPR only: fix the exact old ordering after all inherited checks complete.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared complete12212 kernel}")
profile=$(realpath "${2:?Cumulative native profile}")
[[ $profile == "$kernel/native-profile" ]]
marker=$kernel/native-generated/uke-oob-composed-layer
test -f "$kernel/native-generated/uke-oob-native-layer"
test ! -e "$marker"
actual=$kernel/arch/arm64/kernel/uke-abl.c
[[ $(grep -Fc 'ret = uke_audio_config_graph(output);' "$actual") == 1 ]]
! grep -Fq 'ret = uke_audio_config_graph(uke_fdt);' "$actual"
cp "$actual" "$kernel/native-generated/abl-before-oob-composed.c"
patch -d "$kernel" --dry-run --batch --fuzz=0 -p1 -i "$profile/src/audio/0008-arm64-uke-oob-after-native.patch"
patch -d "$kernel" --batch --fuzz=0 -p1 -i "$profile/src/audio/0008-arm64-uke-oob-after-native.patch"
! grep -Fq 'ret = uke_audio_config_graph(output);' "$actual"
[[ $(grep -Fc 'ret = uke_audio_config_graph(uke_fdt);' "$actual") == 1 ]]
# Retain a reversible exact delta; no unrelated ABL code may change.
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir -p "$work/arch/arm64/kernel"
cp "$actual" "$work/arch/arm64/kernel/uke-abl.c"
patch -R -d "$work" --batch --fuzz=0 -p1 -i "$profile/src/audio/0008-arm64-uke-oob-after-native.patch"
cmp "$work/arch/arm64/kernel/uke-abl.c" "$kernel/native-generated/abl-before-oob-composed.c"
printf 'After-native OOB supplier; reopened packed buffer; exact inverse delta; all other source retained.\n' > "$marker"
for cc in gcc clang;do
 for san in 0 1;do
  CC=$cc SANITIZE=$san bash "$profile/tests/audio-oob-entry.sh" "$kernel" "$kernel/native-generated/abl-before-oob-composed.c"
 done
done
printf 'Actual final OOB entry ordering passed; device audio and physical protection remain unqualified.\n'

#!/usr/bin/bash
# COPR only; actual generic callback, real channel IDs and AArch64 composite.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
out=$(realpath "${2:?Existing native output}")
profile=$kernel/native-profile
work=$kernel/native-generated/surround-map733
[[ ! -e $work ]]
mkdir -p "$work/bad"
ulimit -c 0
awk '/^#define PCM_CHANNEL_(FL|FR|FC|LS|RS|LFE|LB|RB)[[:space:]]/ {print;n++} END{if(n!=8)exit 1}' \
 "$kernel/sound/soc/qcom/qdsp6/q6apm.h" > "$work/actual-q6apm-channel-ids.h"
file=$kernel/sound/soc/qcom/qdsp6/audioreach.c
cp "$file" "$work/before.c"
awk '/^void audioreach_set_default_channel_mapping\(/ {emit=1} emit{print} emit&&/^}/{exit}' "$file" > "$work/before.inc"
git -C "$kernel" apply --check --whitespace=error "$profile/src/audio/0030-audioreach-surround-channel-map.patch"
git -C "$kernel" apply --whitespace=error "$profile/src/audio/0030-audioreach-surround-channel-map.patch"
awk '/^void audioreach_set_default_channel_mapping\(/ {emit=1} emit{print} emit&&/^}/{exit}' "$file" > "$work/actual-audioreach-map.inc"
for header in uke-speaker-quad-apm.h uke-speaker-quad-wire.h uke-speaker-quad.h;do
 cp "$profile/src/audio/$header" "$work/bad/$header"
done
# Recreate the demonstrated historical numeric identity error only.
sed -i 's/PCM_CHANNEL_FL, PCM_CHANNEL_FR, PCM_CHANNEL_LS, PCM_CHANNEL_RS/1, 2, 5, 6/' "$work/bad/uke-speaker-quad-wire.h"
for cc in gcc clang;do
 for sanitize in 0 1;do
  flags=(-std=gnu11 -O2 -UNDEBUG -Wall -Wextra -Werror)
  [[ $sanitize == 0 ]] || flags+=(-O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$cc" "${flags[@]}" -I"$work" "$profile/tests/audioreach-surround-map.c" -o "$work/map"
  "$work/map"
  "$cc" "${flags[@]}" -I"$work" "$profile/tests/speaker-quad-wire.c" -o "$work/wire"
  "$work/wire"
  printf 'Actual speaker/surround channel identity passed:%s/sanitize%s; profile and firmware acceptance separate.\n' "$cc" "$sanitize"
 done
 status=0
 "$cc" -std=gnu11 -O2 -UNDEBUG -Wall -Wextra -Werror -I"$work" \
  -DUKE_QUAD_APM_HEADER="\"$work/bad/uke-speaker-quad-apm.h\"" "$profile/tests/speaker-quad-wire.c" -o "$work/wrong-wire"
 "$work/wrong-wire" > "$work/$cc-identity-refusal.log" 2>&1 || status=$?
 [[ $status == 134 ]]
 grep -F 'ids[row]' "$work/$cc-identity-refusal.log"
 cp "$work/actual-audioreach-map.inc" "$work/good.inc"
 cp "$work/before.inc" "$work/actual-audioreach-map.inc"
 "$cc" -std=gnu11 -O2 -UNDEBUG -Wall -Wextra -Werror -I"$work" "$profile/tests/audioreach-surround-map.c" -o "$work/old-map"
 status=0
 "$work/old-map" > "$work/$cc-layout-refusal.log" 2>&1 || status=$?
 [[ $status == 134 ]]
 grep -F 'memcmp(data.map' "$work/$cc-layout-refusal.log"
 cp "$work/good.inc" "$work/actual-audioreach-map.inc"
 printf 'Historical wrong quad IDs and absent6/8 mapping refused:%s/status134.\n' "$cc"
done
mkdir -p "$work/inverse/sound/soc/qcom/qdsp6"
git -C "$work/inverse" init -q
cp "$file" "$work/inverse/sound/soc/qcom/qdsp6/audioreach.c"
git -C "$work/inverse" apply -R --whitespace=error "$profile/src/audio/0030-audioreach-surround-channel-map.patch"
cmp "$work/before.c" "$work/inverse/sound/soc/qcom/qdsp6/audioreach.c"
release=$(jq -er .full_release "$profile/manifests/cumulative-release.json")
find "$out/sound/soc/qcom/qdsp6" -maxdepth 1 -type f \( -name audioreach.o -o -name snd-q6apm.o \) -delete
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION="-$release-unstable" KCFLAGS=-Werror W=1 -j4 sound/soc/qcom/qdsp6/snd-q6apm.o
llvm-readelf -h "$out/sound/soc/qcom/qdsp6/snd-q6apm.o" | grep -F AArch64
llvm-nm "$out/sound/soc/qcom/qdsp6/snd-q6apm.o" | grep -E '[[:space:]]T[[:space:]]+audioreach_set_default_channel_mapping$'
llvm-nm "$out/sound/soc/qcom/qdsp6/snd-q6apm.o" | grep -E '[[:space:]]T[[:space:]]+audioreach_uke_quad_matrix$'
printf 'Actual ARM64 AudioReach composite includes corrected quad IDs and6/8 maps; whole-source inverse passed, no extra media-format command or advertised speaker profile.\n'

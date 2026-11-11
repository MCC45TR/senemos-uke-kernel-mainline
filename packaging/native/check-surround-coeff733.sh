#!/usr/bin/bash
# COPR only; exact encoder/transport and freshly compiled parent composite.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
out=$(realpath "${2:?Existing native output}")
profile=$kernel/native-profile
work=$kernel/native-generated/surround-coeff733
[[ ! -e $work ]]
mkdir -p "$work/bad"
ulimit -c 0
cp "$kernel/native-generated/surround-map733/actual-q6apm-channel-ids.h" "$work/"
for header in uke-speaker-quad-apm.h uke-speaker-quad-wire.h uke-speaker-surround-wire.h uke-speaker-quad.h uke-speaker-quad-transport.h;do
 cmp "$profile/src/audio/$header" "$kernel/sound/soc/qcom/qdsp6/$header"
 cp "$profile/src/audio/$header" "$work/bad/$header"
done
# A plausible regression: omit LFE instead of preserving it in the downmix.
sed -i 's/return 2048;/return 0;/' "$work/bad/uke-speaker-surround-wire.h"
[[ $(grep -Fc 'return 0;' "$work/bad/uke-speaker-surround-wire.h") == 2 ]]
for cc in gcc clang;do
 for sanitize in 0 1;do
  flags=(-std=gnu11 -O2 -UNDEBUG -Wall -Wextra -Werror)
  [[ $sanitize == 0 ]] || flags+=(-O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$cc" "${flags[@]}" -I"$work" "$profile/tests/speaker-surround-wire.c" -o "$work/coeff"
  "$work/coeff"
  printf 'Actual surround coefficients passed:%s/sanitize%s; no firmware or physical acceptance.\n' "$cc" "$sanitize"
 done
 "$cc" -std=gnu11 -O2 -UNDEBUG -Wall -Wextra -Werror -I"$work" \
  -DUKE_SURROUND_APM_HEADER="\"$work/bad/uke-speaker-quad-apm.h\"" \
  "$profile/tests/speaker-surround-wire.c" -o "$work/missing-lfe"
 status=0
 "$work/missing-lfe" > "$work/$cc-lfe-refusal.log" 2>&1 || status=$?
 [[ $status == 134 ]]
 grep -F 'value==expected' "$work/$cc-lfe-refusal.log"
 printf 'Missing LFE coefficient regression refused:%s/status134.\n' "$cc"
done
llvm-readelf -h "$out/sound/soc/qcom/qdsp6/snd-q6apm.o" | grep -F AArch64
llvm-nm "$out/sound/soc/qcom/qdsp6/snd-q6apm.o" | grep -E '[[:space:]]T[[:space:]]+audioreach_uke_surround_matrix$'
llvm-nm "$out/sound/soc/qcom/qdsp6/snd-q6apm.o" | grep -E '[[:space:]]T[[:space:]]+audioreach_uke_quad_matrix$'
printf 'Actual ARM64 AudioReach composite retains quad and adds three-table surround transport; FE/profile/firmware/physical admission remains open.\n'

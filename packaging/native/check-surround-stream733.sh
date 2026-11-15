#!/usr/bin/bash
# COPR only; actual FE, DPCM selector, route callbacks and fresh ARM64 objects.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
out=$(realpath "${2:?Existing native output}")
profile=$kernel/native-profile
bash "$profile/src/audio/apply-speaker-surround733.sh" "$kernel"
work=$kernel/native-generated/surround-stream733
mkdir -p "$work/sound"
cp "$kernel/include/uapi/sound/asound.h" "$work/sound/asound.h"
ulimit -c 0
cp "$kernel/native-generated/surround-map733/actual-q6apm-channel-ids.h" "$work/"
cp "$kernel/native-generated/surround-map733/actual-audioreach-map.inc" "$work/"
awk '/^const struct snd_pcm_chmap_elem snd_pcm_std_chmaps\[\] = / {copy=1} copy{print} copy&&/^};/{found++;exit} END{if(found!=1)exit 1}' \
 "$kernel/sound/core/pcm_lib.c" > "$work/actual-alsa-standard-chmaps.inc"
printf '/* Controlled fixture declarations provided by the test TU. */\n' > "$work/uke-fs19xx-runtime.h"
cp "$work/uke-fs19xx-runtime.h" "$work/sound/uke-fs19xx-guard.h"
for cc in gcc clang;do
 for san in 0 1;do
  flags=(-std=gnu11 -O2 -UNDEBUG -Wall -Wextra -Werror)
  [[ $san == 0 ]] || flags+=(-O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$cc" "${flags[@]}" -I"$work" "$profile/tests/speaker-surround-stream.c" -o "$work/stream"
  "$work/stream"
  "$cc" "${flags[@]}" -I"$work" -pthread "$profile/tests/speaker-surround-lpass.c" -o "$work/lpass"
  "$work/lpass"
  printf 'Actual surround stream routing passed:%s/sanitize%s; topology, firmware and physical admission separate.\n' "$cc" "$san"
 done
done
# Verify that source application changes only the two intended call sites,
# one include and one private field; the previous quad adapter is retained.
awk '$0!="\tunsigned int uke_quad_inputs;"{print}' "$kernel/sound/soc/qcom/qdsp6/q6apm-lpass-dais.c" | cmp - "$work/before/q6apm-lpass-dais.c"
awk '
 $0=="#include \"uke-speaker-surround-fe.h\"" {skip=1;next}
 skip {if($0!="")exit 1;skip=0;next}
 $0=="\tret = uke_surround_fe_open(substream, graph_id);" {call=3;next}
 call {call--;next}
 $0=="\treturn uke_surround_fe_chmap(pcm, graph_id);" {print "\treturn 0;";next}
 {print}
 END{if(skip||call)exit 1}
' "$kernel/sound/soc/qcom/qdsp6/q6apm-dai.c" | cmp - "$work/before/q6apm-dai.c"
cmp "$profile/src/audio/uke-speaker-quad-lpass.h" "$work/before/uke-speaker-quad-lpass.h"
release=$(jq -er .full_release "$profile/manifests/cumulative-release.json")
find "$out/sound/soc/qcom/qdsp6" -maxdepth 1 -type f \( -name q6apm-dai.o -o -name q6apm-lpass-dais.o \) -delete
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION="-$release-unstable" KCFLAGS=-Werror W=1 -j4 \
 sound/soc/qcom/qdsp6/q6apm-dai.o sound/soc/qcom/qdsp6/q6apm-lpass-dais.o
for object in q6apm-dai q6apm-lpass-dais;do
 llvm-readelf -h "$out/sound/soc/qcom/qdsp6/$object.o" | grep -F AArch64
 llvm-nm "$out/sound/soc/qcom/qdsp6/$object.o" > "$work/$object.symbols"
done
grep -E '[[:space:]]U[[:space:]]+snd_pcm_add_chmap_ctls$' "$work/q6apm-dai.symbols"
grep -E '[[:space:]]U[[:space:]]+audioreach_uke_surround_matrix$' "$work/q6apm-lpass-dais.symbols"
grep -E '[[:space:]]U[[:space:]]+audioreach_uke_quad_matrix$' "$work/q6apm-lpass-dais.symbols"
printf 'Actual ARM64 FE/LPASS objects include6/8 channel controls and protected MFC selection; source inverse/default4/error paths pass. No topology/profile activation or physical acceptance.\n'

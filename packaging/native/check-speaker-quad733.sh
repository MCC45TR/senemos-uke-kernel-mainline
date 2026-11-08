#!/usr/bin/bash
# Inspect actual source and AArch64 objects without rerunning old suites.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
out=$(realpath "${2:?Native output}")
phase=${3:?source, objects or linked}
[[ $phase == source || $phase == objects || $phase == linked ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
core=$kernel/sound/soc/qcom/qdsp6
saved=$kernel/native-generated/speaker-quad-before
# Reconstruct the original files to account for every inherited byte.
awk '
 $0=="\tstruct mutex uke_quad_lock;" {state++;next}
 $0=="\tunsigned int uke_quad_turn;" {turn++;next}
 $0=="\tmutex_init(&dai_data->uke_quad_lock);" {init++;next}
 $0=="#include \"uke-speaker-quad-lpass.h\"" {header++;getline; if($0!="")exit 1;next}
 $0=="static const struct snd_soc_dai_ops q6tdm_ops = {" {block=1;ops++}
 block && $0=="\t.set_channel_map = uke_quad_set_map," {set++;next}
 block && $0=="\t.get_channel_map = uke_quad_get_map," {get++;next}
 block {
  gsub(/uke_quad_prepare/,"q6apm_lpass_dai_prepare")
  gsub(/uke_quad_startup/,"q6apm_lpass_dai_startup")
  gsub(/uke_quad_shutdown/,"q6i2s_lpass_dai_shutdown")
  gsub(/uke_quad_hw_params/,"q6dma_hw_params")
  gsub(/uke_quad_trigger/,"q6apm_lpass_dai_trigger")
 }
 block && $0=="};" {block=0}
 {print}
 END{if(state!=1||turn!=1||init!=1||header!=1||ops!=1||set!=1||get!=1||block)exit 1}
' "$core/q6apm-lpass-dais.c" > "$work/lpass-before.c"
cmp "$work/lpass-before.c" "$saved/sound/soc/qcom/qdsp6/q6apm-lpass-dais.c"
awk '
 $0=="\tstruct snd_soc_dai *rotation_dai;" {field++;next}
 $0=="#include \"uke-speaker-quad-control.h\"" {print "#include \"uke-speaker-display-control.h\"";header++;next}
 {print}
 END{if(field!=1||header!=1)exit 1}
' "$kernel/sound/soc/qcom/uke-audio-card.c" > "$work/card-before.c"
cmp "$work/card-before.c" "$saved/sound/soc/qcom/uke-audio-card.c"
cmp <(cat "$saved/sound/soc/qcom/qdsp6/audioreach.c";printf '\n#include "uke-speaker-quad-apm.h"\n') "$core/audioreach.c"
for name in uke-speaker-quad.h uke-speaker-quad-lpass.h uke-speaker-quad-wire.h uke-speaker-quad-apm.h uke-speaker-quad-transport.h;do cmp "$core/$name" "$kernel/native-profile/src/audio/$name";done
grep -Fx 'EXPORT_SYMBOL_GPL(audioreach_uke_quad_matrix);' "$core/uke-speaker-quad-apm.h"
for name in uke-speaker-quad.h uke-speaker-quad-control.h;do cmp "$kernel/sound/soc/qcom/$name" "$kernel/native-profile/src/audio/$name";done
[[ $phase != source ]] || { printf 'Actual quad source and complete inherited-file inverse passed; no native or physical acceptance.\n';exit 0; }
for name in sound/soc/qcom/qdsp6/q6apm-lpass-dais sound/soc/qcom/qdsp6/snd-q6apm sound/soc/qcom/uke-audio-card;do
 llvm-readelf -h "$out/$name.o" | grep -F AArch64
 llvm-nm "$out/$name.o" > "$work/${name##*/}.symbols"
done
for symbol in uke_quad_get_map uke_quad_set_map uke_quad_prepare uke_quad_shutdown;do
 grep -Eq " [Tt] $symbol$" "$work/q6apm-lpass-dais.symbols"
done
for symbol in q6apm_fs19xx_graph q6apm_fs19xx_fault audioreach_uke_quad_matrix;do
 grep -Eq " U $symbol$" "$work/q6apm-lpass-dais.symbols"
done
! grep -Eq ' U audioreach_set_media_format$' "$work/q6apm-lpass-dais.symbols"
! grep -Eq ' U (q6apm_send_cmd_sync|audioreach_alloc_apm_cmd_pkt)$' "$work/q6apm-lpass-dais.symbols"
grep -Eq ' T audioreach_uke_quad_matrix$' "$work/snd-q6apm.symbols"
! grep -Eq ' U (q6apm_send_cmd_sync|audioreach_uke_quad_matrix)$' "$work/snd-q6apm.symbols"
for symbol in snd_soc_dai_get_channel_map snd_soc_dai_set_channel_map q6apm_fs19xx_fault;do
 grep -Eq " U $symbol$" "$work/uke-audio-card.symbols"
done
if [[ $phase == linked ]];then
 for name in sound/soc/qcom/qdsp6/q6apm-lpass-dais sound/soc/qcom/qdsp6/snd-q6apm sound/soc/qcom/uke-audio-card;do
  llvm-readelf -h "$out/$name.ko" | grep -F AArch64
 done
fi
printf 'Actual cumulative quad speaker card/LPASS source and native callbacks passed:%s; firmware/live/physical acceptance separate.\n' "$phase"

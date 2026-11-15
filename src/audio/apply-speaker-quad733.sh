#!/usr/bin/bash
# COPR source-only composition. Keep the inherited source gates unchanged.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
profile=$kernel/native-profile
core=$kernel/sound/soc/qcom/qdsp6
card=$kernel/sound/soc/qcom/uke-audio-card.c
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
[[ ! -e $core/uke-speaker-quad.h ]]
mkdir -p "$kernel/native-generated/speaker-quad-before"
for path in sound/soc/qcom/qdsp6/q6apm-lpass-dais.c sound/soc/qcom/qdsp6/audioreach.c sound/soc/qcom/uke-audio-card.c;do
 install -Dm644 "$kernel/$path" "$kernel/native-generated/speaker-quad-before/$path"
done
awk '
 $0=="struct q6apm_lpass_dai_data {" {
  print;print "\tstruct mutex uke_quad_lock;";print "\tunsigned int uke_quad_turn;";state++;next
 }
 $0=="static const struct snd_soc_dai_ops q6tdm_ops = {" {
  print "#include \"uke-speaker-quad-lpass.h\"";print "";block=1;print;ops++;next
 }
 block && $0=="};" {block=0;print "\t.set_channel_map = uke_quad_set_map,";print "\t.get_channel_map = uke_quad_get_map,";print;next}
 block {
  gsub(/q6apm_lpass_dai_prepare/,"uke_quad_prepare")
  gsub(/q6apm_lpass_dai_startup/,"uke_quad_startup")
  gsub(/q6i2s_lpass_dai_shutdown/,"uke_quad_shutdown")
  gsub(/q6dma_hw_params/,"uke_quad_hw_params")
  gsub(/q6apm_lpass_dai_trigger/,"uke_quad_trigger")
 }
 $0=="\tdev_set_drvdata(dev, dai_data);" {print "\tmutex_init(&dai_data->uke_quad_lock);";init++}
 {print}
 END{if(state!=1||ops!=1||init!=1||block)exit 1}
' "$core/q6apm-lpass-dais.c" > "$work/lpass.c"
awk '
 $0=="\tstruct snd_kcontrol *rotation_controls[4];" {print;print "\tstruct snd_soc_dai *rotation_dai;";field++;next}
 $0=="#include \"uke-speaker-display-control.h\"" {print "#include \"uke-speaker-quad-control.h\"";header++;next}
 {print}
 END{if(field!=1||header!=1)exit 1}
' "$card" > "$work/card.c"
install -m644 "$work/lpass.c" "$core/q6apm-lpass-dais.c"
install -m644 "$work/card.c" "$card"
install -m644 "$profile/src/audio/uke-speaker-quad.h" "$core/"
install -m644 "$profile/src/audio/uke-speaker-quad.h" "$kernel/sound/soc/qcom/"
install -m644 "$profile/src/audio/uke-speaker-quad-lpass.h" "$core/"
install -m644 "$profile/src/audio/uke-speaker-quad-wire.h" "$core/"
install -m644 "$profile/src/audio/uke-speaker-surround-wire.h" "$core/"
install -m644 "$profile/src/audio/uke-speaker-quad-apm.h" "$core/"
install -m644 "$profile/src/audio/uke-speaker-quad-transport.h" "$core/"
printf '\n#include "uke-speaker-quad-apm.h"\n' >> "$core/audioreach.c"
install -m644 "$profile/src/audio/uke-speaker-quad-control.h" "$kernel/sound/soc/qcom/"
printf 'Quad program-channel source applied; existing physical topology/calibration/VI/codec files remain unchanged. Native and physical acceptance pending.\n'

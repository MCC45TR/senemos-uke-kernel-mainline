#!/usr/bin/bash
# COPR only, after inherited source and object checks. No topology activation.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative source}")
profile=$kernel/native-profile
core=$kernel/sound/soc/qcom/qdsp6
work=$kernel/native-generated/surround-stream733
[[ ! -e $work ]]
mkdir -p "$work/before"
for file in q6apm-lpass-dais.c q6apm-dai.c uke-speaker-quad-lpass.h;do
 cp "$core/$file" "$work/before/$file"
done
awk '
 $0=="\tunsigned int uke_quad_turn;" {print;print "\tunsigned int uke_quad_inputs;";n++;next}
 {print}
 END{if(n!=1)exit 1}
' "$core/q6apm-lpass-dais.c" > "$work/lpass.c"
awk '
 $0=="static int q6apm_dai_open(struct snd_soc_component *component," {
  print "#include \"uke-speaker-surround-fe.h\"";print "";header++
 }
 $0=="\t/* Ensure that buffer size is a multiple of period size */" {
  print "\tret = uke_surround_fe_open(substream, graph_id);"
  print "\tif (ret < 0)";print "\t\tgoto err;";print "";open++
 }
 /^static int q6apm_dai_pcm_new\(/ {pcm=1}
 pcm && $0=="\treturn 0;" {
  print "\treturn uke_surround_fe_chmap(pcm, graph_id);";pcm=0;chmap++;next
 }
 {print}
 END{if(header!=1||open!=1||chmap!=1||pcm)exit 1}
' "$core/q6apm-dai.c" > "$work/fe.c"
install -m644 "$work/lpass.c" "$core/q6apm-lpass-dais.c"
install -m644 "$work/fe.c" "$core/q6apm-dai.c"
for header in uke-speaker-surround-stream.h uke-speaker-surround-fe.h;do
 install -m644 "$profile/src/audio/$header" "$core/$header"
done
install -m644 "$profile/src/audio/uke-speaker-surround-lpass.h" "$core/uke-speaker-quad-lpass.h"
printf 'Speaker FE6/8 constraints/channel maps and protected BE selector prepared; topology/profiles unchanged, firmware acceptance pending.\n'

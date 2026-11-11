#!/usr/bin/bash
# COPR only. Execute the actual C encoders with independent wire expectations.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
profile=$kernel/native-profile
core=$kernel/sound/soc/qcom/qdsp6
work=$kernel/native-generated/pcm-surround733
[[ -s $work/before.c && -s $work/applied.sha256 ]]
extract(){ awk -v start="$2" '$0~start{emit=1} emit{print} emit&&/^}/{found++;exit}END{if(found!=1)exit 1}' "$1"; }
for name in param_id_pcm_output_format_cfg payload_pcm_output_format_cfg media_format payload_media_fmt_pcm;do
 extract "$core/audioreach.h" "^struct $name [{]" >> "$work/pcm-types.inc"
done
grep -E '^#define (DATA_FORMAT_FIXED_POINT|PCM_LSB_ALIGNED|PCM_LITTLE_ENDIAN|MEDIA_FMT_ID_PCM|PARAM_ID_PCM_OUTPUT_FORMAT_CFG|PARAM_ID_MEDIA_FORMAT|AR_PCM_MAX_NUM_CHANNEL)\b' "$core/audioreach.h" >> "$work/pcm-types.inc"
awk '/^#define PCM_CHANNEL_(FL|FR|FC|LS|RS|LFE|LB|RB)[[:space:]]/{print;n++}END{if(n!=8)exit 1}' "$core/q6apm.h" >> "$work/pcm-types.inc"
for name in apm_pcm_module_media_fmt_cmd apm_sh_module_media_fmt_cmd;do
 extract "$core/audioreach.c" "^struct $name [{]" >> "$work/pcm-types.inc"
done
sed -n '/^#define APM_SHMEM_FMT_CFG_PSIZE/,/^struct apm_i2s_module_intf_cfg/p' "$core/audioreach.c" | sed '$d' >> "$work/pcm-types.inc"
for name in audioreach_set_default_channel_mapping audioreach_pcm_word_size audioreach_pcm_channels_valid audioreach_pcm_set_media_format audioreach_shmem_set_media_format;do
 extract "$core/audioreach.c" "^(static (int|bool)|void) $name[(]" >> "$work/pcm-encoders.inc"
done
cp "$work/pcm-encoders.inc" "$work/good.inc"
cp "$work/pcm-types.inc" "$work/good-types.inc"
ulimit -c 0
for cc in gcc clang;do
 for san in 0 1;do
  flags=(-std=gnu11 -O2 -UNDEBUG -Wall -Wextra -Werror)
  [[ $san == 0 ]] || flags+=(-O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$cc" "${flags[@]}" -I"$work" "$profile/tests/pcm-surround-encoders.c" -o "$work/check"
  "$work/check"
  printf 'Actual PCM surround encoder passed:%s/sanitize%s.\n' "$cc" "$san"
 done
 for bad in max4 length missing-map;do
  cp "$work/good.inc" "$work/pcm-encoders.inc"
  cp "$work/good-types.inc" "$work/pcm-types.inc"
  case $bad in
   max4) sed -i 's/cfg->num_channels > AR_PCM_MAX_NUM_CHANNEL/cfg->num_channels > 4/' "$work/pcm-encoders.inc";;
   length) sed -i 's/header->payload_size = sizeof(\*cfg) + num_channels \* sizeof(cfg->channel_mapping\[0\]);/header->payload_size = payload_size - sizeof(*header);/' "$work/pcm-encoders.inc";;
   missing-map) sed -i 's/return mapped >= cfg->num_channels;/return mapped <= AR_PCM_MAX_NUM_CHANNEL;/' "$work/pcm-encoders.inc";;
  esac
  ! cmp -s "$work/good.inc" "$work/pcm-encoders.inc"
  "$cc" -std=gnu11 -O2 -UNDEBUG -Wall -Wextra -Werror -I"$work" "$profile/tests/pcm-surround-encoders.c" -o "$work/bad"
  status=0
  "$work/bad" > "$work/$cc-$bad.log" 2>&1 || status=$?
  [[ $status == 134 ]]
  grep -F 'Assertion' "$work/$cc-$bad.log"
  printf 'Historical PCM encoder regression refused:%s/%s/status134.\n' "$cc" "$bad"
 done
 cp "$work/good.inc" "$work/pcm-encoders.inc"
 cp "$work/good-types.inc" "$work/pcm-types.inc"
done
(cd "$kernel";sha256sum -c --strict --quiet "$work/applied.sha256")
printf 'PCM source/packet qualification only; firmware, physical sound, prepare/STOP lifecycle and gain243 remain separate.\n'

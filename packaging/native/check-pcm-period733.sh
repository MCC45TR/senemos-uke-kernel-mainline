#!/usr/bin/env bash
# Source/lifecycle and real native-object checks; no hardware acceptance claim.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative source}")
out=$(realpath "${2:?Output directory}")
phase=${3:-objects}
[[ $phase == source || $phase == objects || $phase == linked ]]
source=$kernel/sound/soc/qcom/qdsp6/q6apm-dai.c
before=$kernel/native-generated/pcm-before-period-work.c
for file in "$source" "$before";do [[ -f $file && ! -L $file ]];done
printf '%s  %s\n' \
 acb1773a93e99881ff51bcc78c26e8d48b6e8c59cb396755d47100dd91a6797b "$before" \
 f14978b215fe56b1e5505ca9f36da9633c5631fd7b1be40ae85896aea86d7e65 "$source" | sha256sum -c --strict --quiet -
jq -e '.pcm_period_work_layer==1 and .pcm_period_work_queue=="system_unbound_wq" and
 .pcm_period_close_gate_and_drain and .pcm_period_compressed_unchanged and
 .pcm_period_capture_eos_unchanged and .speaker_gain_ceiling==223 and
 .muted_stop_deadline_layer==1 and .muted_stop_deadline_ms==6000 and
 .muted_stop_faults_retained and (.physical_acceptance|not)' "$kernel/native-profile/source-composition.json" >/dev/null
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
extract(){ awk -v name="$2" '$0~"^static .* "name"\\("{p=1}p{print}p&&/^}/{n++;exit}END{if(n!=1)exit 1}' "$1"; }
# Preserve the complete compressed path, trigger, DMA, pointer and format setup.
for fn in event_handler_compr q6apm_dai_trigger q6apm_dai_prepare q6apm_dai_hw_params q6apm_dai_pointer;do
 extract "$before" "$fn" > "$work/old";extract "$source" "$fn" > "$work/new";cmp "$work/old" "$work/new"
done
extract "$source" q6apm_dai_open > "$work/open"
extract "$source" q6apm_dai_close > "$work/close"
# Initialization precedes callback publication; failure closes only a valid graph.
awk '/spin_lock_init\(&prtd->pcm_period_lock\)/{lock=NR}/INIT_WORK\(&prtd->pcm_period_work/{work=NR}/prtd->graph = q6apm_graph_open/{publish=NR}/^err:/{err=NR}/q6apm_pcm_period_quiesce/{quiesce=NR}/if \(!IS_ERR_OR_NULL\(prtd->graph\)\)/{valid=NR}/q6apm_graph_close\(prtd->graph\)/{close=NR}/kfree\(prtd\)/{release=NR}END{if(!(lock<work&&work<publish&&publish<err&&err<quiesce&&quiesce<valid&&valid<close&&close<release))exit 1}' "$work/open"
awk '/q6apm_pcm_period_quiesce/{drain=NR}/q6apm_graph_stop\(/{stop=NR}/q6apm_graph_close\(/{close=NR}/kfree\(prtd\)/{release=NR}END{if(!(drain&&drain<stop&&stop<close&&close<release))exit 1}' "$work/close"
[[ $phase != source ]] || exit 0
object=$out/sound/soc/qcom/qdsp6/q6apm-dai.o
llvm-readelf -h "$object" | grep -E 'Machine:.*AArch64'
llvm-nm -u "$object" > "$work/imports"
for symbol in queue_work_on system_unbound_wq cancel_work_sync snd_pcm_period_elapsed;do
 grep -Eq " U $symbol\$" "$work/imports"
done
llvm-nm "$object" | grep -E ' t q6apm_pcm_period_work$'
if [[ $phase == linked ]];then
 module=$out/sound/soc/qcom/qdsp6/q6apm-dai.ko
 [[ $(modinfo -F vermagic "$module") == "$(jq -er .kernel_release "$kernel/native-profile/source-composition.json") "* ]]
fi
printf 'Actual cumulative AArch64 PCM period source/object/lifetime gates passed:%s; compressed, capture, formats and protection retained.\n' "$phase"

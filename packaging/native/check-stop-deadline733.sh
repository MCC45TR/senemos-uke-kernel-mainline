#!/usr/bin/env bash
# Actual cumulative sources and objects, in addition to every retained gate.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Complete cumulative kernel}")
out=$(realpath "${2:?Native source/output directory}")
phase=${3:-objects}
[[ $phase == source || $phase == objects || $phase == linked ]]
profile=$kernel/native-profile
test -f "$kernel/native-generated/codec-before-stop-deadline.c"
source "$profile/packaging/native/stop-deadline-source-view.sh" "$kernel"
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
# Every hardware writer and running health check remains byte-identical.
for function in fs19xx_chip_init fs19xx_chip_start fs19xx_chip_stop fs19xx_check_health fs19xx_unmute_output fs19xx_set_volume_reg;do
 for kind in before after;do
  file=$kernel/sound/soc/codecs/fs19xx.c
  [[ $kind != before ]] || file=$uke_stop_codec_view
  awk -v name="$function" '$0~"^static (int|void) "name"\\("{p=1}p{print}p&&/^}/{n++;exit}END{if(n!=1)exit 1}' "$file" > "$work/$kind"
 done
 cmp "$work/before" "$work/after"
done
[[ $phase != source ]] || exit 0
codec=$out/sound/soc/codecs/fs19xx.o
apm=$out/sound/soc/qcom/qdsp6/snd-q6apm.o
for file in "$codec" "$apm";do llvm-readelf -h "$file" | grep -E 'Machine:.*AArch64';done
llvm-nm -u "$codec" > "$work/imports"
grep -Eq ' U jiffies$' "$work/imports"
grep -Eq ' U q6apm_fs19xx_configured$' "$work/imports"
grep -Eq ' U q6apm_fs19xx_output_fault$' "$work/imports"
llvm-nm "$codec" > "$work/codec-symbols"
grep -Eq ' t fs19xx_unmute_work$' "$work/codec-symbols"
if [[ $phase == linked ]];then
 module=$out/sound/soc/codecs/snd-soc-fs19xx.ko
 test -s "$module"
 [[ $(modinfo -F vermagic "$module") == "$(jq -er .kernel_release "$profile/source-composition.json") "* ]]
fi
printf 'Actual cumulative AArch64 muted STOP source/object/guard gates passed:%s; all running hardware writers exact, physical limiting unqualified.\n' "$phase"

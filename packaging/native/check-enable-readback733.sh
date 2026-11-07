#!/usr/bin/env bash
# Inverse source and real cumulative kernel-object/link admission.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Cumulative kernel}")
out=$(realpath "${2:?Native output}")
phase=${3:-objects}
[[ $phase == source || $phase == objects || $phase == linked ]]
profile=$kernel/native-profile
core=$kernel/sound/soc/qcom/qdsp6
before=$(bash "$profile/packaging/native/speaker-readback-source-view.sh" "$kernel")
[[ $before == "$kernel/native-generated/runtime-before-enable-readback.c" ]]
for file in uke-fs19xx-readback.c uke-fs19xx-readback.h uke-fs19xx-enable-control.h;do
 cmp "$profile/src/audio/$file" "$core/$file"
done
cmp <(cat "$kernel/native-generated/qdsp6-makefile-before-enable-readback";printf '\nsnd-q6apm-y += uke-fs19xx-readback.o\n') "$core/Makefile"
[[ $phase != source ]] || exit 0
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
for name in uke-fs19xx-runtime uke-fs19xx-readback snd-q6apm;do
 llvm-readelf -h "$out/sound/soc/qcom/qdsp6/$name.o" | grep -E 'Machine:.*AArch64'
done
llvm-nm -u "$out/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o" > "$work/runtime"
grep -Eq ' U q6apm_fs19xx_read_enables$' "$work/runtime"
llvm-nm "$out/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o" | grep -E ' t fs19xx_enable_get$'
llvm-nm -u "$out/sound/soc/qcom/qdsp6/uke-fs19xx-readback.o" > "$work/backend"
for symbol in gpr_alloc_port gpr_free_port gpr_send_port_pkt;do grep -Eq " U $symbol$" "$work/backend";done
! grep -Eq ' U (dma_|uke_audio_config_|q6apm_fs19xx_fault)' "$work/backend"
llvm-nm -g --defined-only "$out/sound/soc/qcom/qdsp6/snd-q6apm.o" | grep -E ' T q6apm_fs19xx_read_enables$'
llvm-nm -u "$out/sound/soc/qcom/qdsp6/snd-q6apm.o" > "$work/composite"
! grep -Eq ' U q6apm_fs19xx_read_enables$' "$work/composite"
strings "$out/sound/soc/qcom/qdsp6/snd-q6apm.o" | grep -Fx 'FS19xx DSP Enable State'
if [[ $phase == linked ]];then
 module=$out/sound/soc/qcom/qdsp6/snd-q6apm.ko
 [[ $(modinfo -F vermagic "$module") == "$(jq -er .kernel_release "$profile/source-composition.json") "* ]]
 strings "$module" | grep -Fx 'FS19xx DSP Enable State'
fi
printf 'Actual cumulative AArch64 FS19xx query runtime/backend/composite passed:%s; limiter and243 remain unqualified.\n' "$phase"

#!/usr/bin/env bash
# COPR only: actual cumulative objects and the APM composite, no final module.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
out=$(realpath "${2:?Native output}")
bash "$kernel/native-profile/packaging/native/check-oob-runtime731.sh" "$kernel"
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
for object in drivers/soc/qcom/uke-audio-config-memory.o drivers/misc/fastrpc.o \
 sound/soc/qcom/qdsp6/uke-fs19xx-oob-backend.o sound/soc/qcom/qdsp6/snd-q6apm.o;do
 test -s "$out/$object"
 llvm-readelf -h "$out/$object" | grep -E 'Machine:.*AArch64'
done
llvm-nm -u "$out/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o" > "$work/runtime"
grep -Eq ' U q6apm_fs19xx_oob_send$' "$work/runtime"
llvm-nm -g --defined-only "$out/sound/soc/qcom/qdsp6/snd-q6apm.o" > "$work/apm"
grep -Eq ' T q6apm_fs19xx_oob_send$' "$work/apm"
llvm-nm -u "$out/sound/soc/qcom/qdsp6/snd-q6apm.o" > "$work/apm-unresolved"
! grep -Eq ' U q6apm_fs19xx_oob_send$' "$work/apm-unresolved"
for symbol in uke_audio_config_acquire uke_audio_config_release;do
 grep -Eq " U $symbol$" "$work/apm-unresolved"
 llvm-nm -g --defined-only "$out/drivers/soc/qcom/uke-audio-config-memory.o" | grep -E " T $symbol$"
 grep -Fx "EXPORT_SYMBOL_GPL($symbol);" "$kernel/drivers/soc/qcom/uke-audio-config-memory.c"
done
grep -Fx 'obj-$(CONFIG_ARCH_QCOM) += uke-audio-config-memory.o' "$kernel/drivers/soc/qcom/Makefile"
grep -Fx CONFIG_ARCH_QCOM=y "$out/.config"
grep -aqF xiaomi,uke-audio-config-memory "$out/arch/arm64/kernel/uke-abl.o"
printf 'Actual AArch64 permanent provider/backend/FastRPC and linked APM runtime dispatch pass; no Image or hardware acceptance.\n'

#!/usr/bin/env bash
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Cumulative kernel}")
out=$(realpath "${2:?Native output}")
phase=${3:-objects}
[[ $phase == objects || $phase == linked ]]
printf '%s  %s\n' ebebdc288110bc5eac1ab4f19e9ea8f48f6585650fdcba340e8cf47a0339cde3 "$kernel/drivers/iommu/arm/arm-smmu/arm-smmu-qcom.c" | sha256sum -c --strict -
cmp "$kernel/native-profile/src/audio/uke-audio-config-smmu.c" "$kernel/drivers/iommu/arm/arm-smmu/uke-audio-config-smmu.c"
obj=$out/drivers/iommu/arm/arm-smmu/arm-smmu-qcom.o
test -s "$obj"
llvm-readelf -h "$obj" | grep -E 'Machine:.*AArch64'
grep -aqF xiaomi,uke-audio-config-memory "$obj"
grep -aqF /audio-config-memory "$obj"
grep -Fx CONFIG_ARM_SMMU=y "$out/.config"
if [[ $phase == linked ]];then
 test -s "$out/vmlinux";test -s "$out/arch/arm64/boot/Image"
 grep -aqF xiaomi,uke-audio-config-memory "$out/vmlinux"
fi
printf 'Actual cumulative AArch64 SMMU root-supplier admission passed:%s; physical DMA/audio remain unqualified.\n' "$phase"

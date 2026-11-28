#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -Eeuo pipefail
export LC_ALL=C
out=$(realpath -e "$1")
bash "${0%/*}/check-initrd-unit-modes.sh" "$out/boot-initramfs.cpio.gz"
cd "$out"
objects=(
    drivers/power/supply/qcom_battmgr.o
    drivers/usb/typec/ucsi/ucsi_glink.o
    drivers/soc/qcom/pmic_glink_altmode.o
    drivers/gpu/drm/msm/adreno/a6xx_gmu.o
    drivers/gpu/drm/panel/panel-xiaomi-o82.o
    sound/soc/qcom/qdsp6/q6apm-dai.o
    sound/soc/qcom/uke-audio-card.o
)
for object in "${objects[@]}"; do
    header=$(llvm-readelf -h "$object")
    grep -Eq 'Machine:[[:space:]]+AArch64' <<< "$header"
    sha256sum "$object"
done
provider=$(llvm-nm --defined-only drivers/power/supply/qcom_battmgr.o)
consumer=$(llvm-nm -u drivers/usb/typec/ucsi/ucsi_glink.o)
queue=$(llvm-nm -u sound/soc/qcom/qdsp6/q6apm-dai.o)
grep -Eq ' T qcom_battmgr_uke_read_cc_orientation$' <<< "$provider"
grep -Eq ' U qcom_battmgr_uke_read_cc_orientation$' <<< "$consumer"
grep -Eq ' U system_dfl_wq$' <<< "$queue"
if grep -Eq ' U system_unbound_wq$' <<< "$queue"; then exit 1; fi
strings sound/soc/qcom/uke-audio-card.o > "$out/uke-audio-card-strings.txt"
grep -Fxq 'DP0 Jack' "$out/uke-audio-card-strings.txt"
grep -Fxq 'mic:uke-4ch-v3' "$out/uke-audio-card-strings.txt"
grep -Eq '^mic:uke-4ch-v4 kernel:' "$out/uke-audio-card-strings.txt"

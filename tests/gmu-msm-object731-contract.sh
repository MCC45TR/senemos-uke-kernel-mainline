#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# COPR only: real composite object; no Image, final module or device activity.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 3 && $(uname -m) == aarch64 ]] || exit 2
kernel=$(realpath -- "$1")
output=$(realpath -m -- "$2")
config=$(realpath -- "$3")
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
source_config=$(sha256sum "$config")
gmu=$kernel/drivers/gpu/drm/msm/adreno/a6xx_gmu.c
hfi=$kernel/drivers/gpu/drm/msm/adreno/a6xx_hfi.c
awk '/^static irqreturn_t a6xx_hfi_irq\(/ {emit=1} emit{print} emit&&/^}/{exit}' \
 "$gmu" > "$stage/irq.inc"
awk '/^static int a6xx_hfi_wait_for_msg_interrupt\(/ {emit=1} emit{print} emit&&/^}/{exit}' \
 "$hfi" > "$stage/wait.inc"
printf '%s  %s\n' \
 27090a6a64d647b12b24125bfe0ae5c3b22abbbc88f9c7202c8c921377a39ae3 "$stage/irq.inc" \
 89cd584b2e2f874b7afa8e1a036a07ac5ae77a0802a82aa5e964a150751b3741 "$stage/wait.inc" \
 | sha256sum -c --strict
mkdir -p "$output"
if [[ ! -e $output/.config ]]; then
 install -m644 "$config" "$output/.config"
 bash "$kernel/scripts/config" --file "$output/.config" --set-str INITRAMFS_SOURCE ''
fi
# Reuse the sensor check's output and generated headers when present.
before_config=$(sha256sum "$output/.config")
install -m644 "$output/.config" "$stage/config-before"
make -C "$kernel" ARCH=arm64 LLVM=1 LLVM_IAS=1 O="$output" \
 LOCALVERSION=-12101-unstable olddefconfig prepare modules_prepare
if [[ $(sha256sum "$output/.config") != "$before_config" ]]; then
 diff -u "$stage/config-before" "$output/.config" || :
 printf 'Unexpected config change after the preceding sensor preparation\n' >&2
 exit 1
fi
for flag in CONFIG_DRM_MSM=m CONFIG_DRM_MSM_KMS=y CONFIG_DRM_MSM_GPU_STATE=y \
 CONFIG_LTO_NONE=y 'CONFIG_INITRAMFS_SOURCE=""'; do
 grep -Fx "$flag" "$output/.config"
done
[[ $(make -s -C "$kernel" ARCH=arm64 LLVM=1 LLVM_IAS=1 O="$output" \
 LOCALVERSION=-12101-unstable kernelrelease) == 7.3.1-12101-unstable ]]
# Build only this real relocatable driver composite, with the retained config.
make -C "$kernel" ARCH=arm64 LLVM=1 LLVM_IAS=1 O="$output" \
 LOCALVERSION=-12101-unstable KCFLAGS=-Werror -j4 drivers/gpu/drm/msm/msm.o
object=$output/drivers/gpu/drm/msm/msm.o
llvm-readelf -h "$object" | grep -E 'Machine:.*AArch64'
llvm-readelf -h "$object" | grep -E 'Type:.*REL'
llvm-nm --defined-only "$object" > "$stage/symbols"
for symbol in a6xx_hfi_irq a6xx_gmu_resume a6xx_hfi_set_freq \
 msm_gpu_fault_crashstate_capture; do
 grep -E "[[:space:]][Tt][[:space:]]+$symbol$" "$stage/symbols"
done
printf 'Fully prepared corrected GMU/HFI sources and linked composite SHA256:\n'
sha256sum "$gmu" "$hfi" "$object"
printf 'Actual linked AArch64 fault IRQ disassembly (record, not an instruction-pattern oracle):\n'
llvm-objdump -d --disassemble-symbols=a6xx_hfi_irq "$object"
[[ $(sha256sum "$config") == "$source_config" ]]
[[ $(sha256sum "$output/.config") == "$before_config" ]]
test ! -e "$output/arch/arm64/boot/Image"
test ! -e "$kernel/arch/arm64/boot/Image"
test ! -e "$output/drivers/gpu/drm/msm/msm.ko"
printf 'Actual AArch64 MSM composite links the corrected IRQ, original HFI vote and retained fault capture; no Image, final module, signature or hardware acceptance is claimed\n'

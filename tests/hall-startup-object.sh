#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# COPR only; compile the production input driver, never an Image or module.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 3 && $(uname -m) == aarch64 ]] || exit 2
kernel=$(realpath "$1")
output=$(realpath -m "$2")
config=$(realpath "$3")
input_hash=$(sha256sum "$config")
mkdir -p "$output"
install -m644 "$config" "$output/.config"
bash "$kernel/scripts/config" --file "$output/.config" --set-str INITRAMFS_SOURCE ''
make -C "$kernel" ARCH=arm64 LLVM=1 LLVM_IAS=1 O="$output" \
    LOCALVERSION=-12204-unstable olddefconfig prepare modules_prepare
grep -Fx CONFIG_INPUT_QCOM_SMP2P_SWITCH=m "$output/.config"
config_hash=$(sha256sum "$output/.config")
make -C "$kernel" ARCH=arm64 LLVM=1 LLVM_IAS=1 O="$output" \
    LOCALVERSION=-12204-unstable KCFLAGS=-Werror -j4 drivers/input/misc/qcom-smp2p-switch.o
[[ $(sha256sum "$config") == "$input_hash" && $(sha256sum "$output/.config") == "$config_hash" ]]
object=$output/drivers/input/misc/qcom-smp2p-switch.o
llvm-readelf -h "$object" | grep -E 'Machine:.*AArch64'
llvm-nm --defined-only "$object" | grep -E '[[:space:]]smp2p_switch_initial_state$'
sha256sum "$object"
test ! -e "$output/arch/arm64/boot/Image"
test ! -e "$output/drivers/input/misc/qcom-smp2p-switch.ko"
printf 'Actual AArch64 SMP2P switch object with retained input config and -Werror PASS\n'

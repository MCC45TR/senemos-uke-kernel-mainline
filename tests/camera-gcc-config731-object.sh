#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# COPR only: actual AArch64 GCC object; no Image, module or device operation.
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
    LOCALVERSION=-12203-unstable olddefconfig prepare modules_prepare
grep -Fx CONFIG_SM_GCC_CLIFFS=y "$output/.config"
config_hash=$(sha256sum "$output/.config")
make -C "$kernel" ARCH=arm64 LLVM=1 LLVM_IAS=1 O="$output" \
    LOCALVERSION=-12203-unstable KCFLAGS=-Werror -j4 drivers/clk/qcom/gcc-cliffs.o
[[ $(sha256sum "$config") == "$input_hash" && $(sha256sum "$output/.config") == "$config_hash" ]]
object=$output/drivers/clk/qcom/gcc-cliffs.o
llvm-readelf -h "$object" | grep -E 'Machine:.*AArch64'
llvm-nm --defined-only "$object" | grep -E '[[:space:]]gcc_cliffs_probe$'
sha256sum "$object"
test ! -e "$output/arch/arm64/boot/Image"
test ! -e "$output/drivers/clk/qcom/gcc-cliffs.ko"
printf 'Real AArch64 GCC object compiled with retained input config and-Werror; no linked/packaged kernel or physical camera acceptance\n'

#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# COPR only: real retained AArch64 sensor object, no image/module packaging.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 3 && $(uname -m) == aarch64 ]] || exit 2
kernel=$(realpath -- "$1")
output=$(realpath -m -- "$2")
config=$(realpath -- "$3")
mkdir -p "$output"
install -m644 "$config" "$output/.config"
# A source-only object has no embedded initramfs. Do not change the input config.
bash "$kernel/scripts/config" --file "$output/.config" --set-str INITRAMFS_SOURCE ''
make -C "$kernel" ARCH=arm64 LLVM=1 LLVM_IAS=1 O="$output" \
    LOCALVERSION=-12101-unstable olddefconfig prepare modules_prepare
grep -Fx CONFIG_VIDEO_OV08D10=m "$output/.config"
make -C "$kernel" ARCH=arm64 LLVM=1 LLVM_IAS=1 O="$output" \
    LOCALVERSION=-12101-unstable KCFLAGS=-Werror -j4 drivers/media/i2c/ov08d10.o
object=$output/drivers/media/i2c/ov08d10.o
llvm-readelf -h "$object" | grep -E 'Machine:.*AArch64'
llvm-nm --defined-only "$object" | grep -E '[[:space:]]ov08d10_get_selection$'
llvm-nm --defined-only "$object" | grep -E '[[:space:]]ov08d10_pad_ops$'
test ! -e "$output/arch/arm64/boot/Image"
test ! -e "$output/drivers/media/i2c/ov08d10.ko"
printf 'Real AArch64 OV08D10 object includes the exact selection callback/pad ops; not linked, packaged or installed\n'

#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# COPR only: force production ROM callbacks into an actual ARM64 provider object.
set -Eeuo pipefail
[[ $# == 2 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1"); out=$(realpath -m "$2")
[[ ! -e $out ]]
mkdir "$out"
cp "$kernel/native-profile/native.config" "$out/.config"
bash "$kernel/scripts/config" --file "$out/.config" --set-str INITRAMFS_SOURCE ''
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-28-unstable olddefconfig prepare modules_prepare
bash "$kernel/native-profile/tests/kernel-hardening-config-contract.sh" "$out/.config"
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-28-unstable KCFLAGS=-Werror -j4 drivers/clk/qcom/camcc-sm7675.o
stage=$out/rom-adapter
mkdir "$stage"
cat > "$stage/rom.c" <<'C'
// SPDX-License-Identifier: GPL-2.0-only
#define UKE_CAMCC_OBJECT_TEST
#include "camcc-sm7675.c"
int uke_camcc_rom_check(u32, cam_cc_crm_lut_read_fn, void *, struct cam_cc_crm_lut *);
int uke_camcc_rom_check(u32 client, cam_cc_crm_lut_read_fn read, void *context,
                       struct cam_cc_crm_lut *table)
{
 return cam_cc_crm_rom_load(client, read, context, table);
}
int uke_camcc_managed_check(struct cam_cc_crm_clock *);
int uke_camcc_managed_check(struct cam_cc_crm_clock *clients)
{
 return cam_cc_crm_managed_attach(clients);
}
C
printf '%s\n' 'obj-y += rom.o' "ccflags-y += -I$kernel/drivers/clk/qcom" > "$stage/Makefile"
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 M="$stage" LOCALVERSION=-28-unstable KCFLAGS=-Werror -j4 rom.o
for object in "$out/drivers/clk/qcom/camcc-sm7675.o" "$stage/rom.o"; do
 llvm-readelf -h "$object" | grep -F AArch64
 sha256sum "$object"
done
for symbol in uke_camcc_rom_check uke_camcc_managed_check; do
 llvm-nm --defined-only "$stage/rom.o" | awk -v symbol="$symbol" '$NF==symbol{found=1}END{exit !found}'
done
grep -aqF firmware-enabled-refused "$out/drivers/clk/qcom/camcc-sm7675.o"
[[ $(cat "$out/include/config/kernel.release") == 7.3.3-28-unstable && ! -e $out/arch/arm64/boot/Image && ! -e $stage/rom.ko ]]
printf 'Actual cumulative28 provider, ROM resolution and all38 adapter ARM64 objects compiled-Werror; no Image, module or firmware request\n'

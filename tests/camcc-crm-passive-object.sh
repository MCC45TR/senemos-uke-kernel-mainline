#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# COPR only: compile exact cumulative full26 with the reviewed passive delta.
set -Eeuo pipefail
[[ $# == 3 && ! -e /etc/senemos/kernel-update.conf && $(uname -m) == aarch64 ]]
kernel=$(realpath "$1")
output=$(realpath -m "$2")
config=$(realpath "$3")
before=$(sha256sum "$config")
project=$(cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$output"
install -m644 "$config" "$output/.config"
bash "$kernel/scripts/config" --file "$output/.config" --set-str INITRAMFS_SOURCE ''
make -s -C "$kernel" ARCH=arm64 LLVM=1 LLVM_IAS=1 O="$output" \
 LOCALVERSION=-26-unstable olddefconfig prepare modules_prepare
make -C "$kernel" ARCH=arm64 LLVM=1 LLVM_IAS=1 O="$output" \
 LOCALVERSION=-26-unstable KCFLAGS=-Werror -j4 drivers/clk/qcom/camcc-sm7675.o
stage=$output/passive-adapter
mkdir "$stage"
cat > "$stage/passive.c" <<'C'
// SPDX-License-Identifier: GPL-2.0-only
#define UKE_CAMCC_OBJECT_TEST
#include "camcc-sm7675.c"
int uke_camcc_crm_managed_check(struct cam_cc_crm_clock *);
int uke_camcc_crm_managed_check(struct cam_cc_crm_clock *clients)
{
	return cam_cc_crm_managed_attach(clients);
}
C
printf '%s\n' 'obj-y += passive.o' "ccflags-y += -I$kernel/drivers/clk/qcom" > "$stage/Makefile"
make -C "$kernel" ARCH=arm64 LLVM=1 LLVM_IAS=1 O="$output" M="$stage" \
 LOCALVERSION=-26-unstable KCFLAGS=-Werror -j4 passive.o
for object in "$output/drivers/clk/qcom/camcc-sm7675.o" "$stage/passive.o";do
 llvm-readelf -h "$object" | grep -F AArch64
 sha256sum "$object"
done
llvm-nm --defined-only "$stage/passive.o" | awk '$NF=="uke_camcc_crm_managed_check"{ok=1}END{exit !ok}'
grep -aqF firmware-enabled-refused "$output/drivers/clk/qcom/camcc-sm7675.o"
[[ $(sha256sum "$config") == "$before" ]]
[[ ! -e $output/arch/arm64/boot/Image && ! -e $stage/passive.ko ]]
printf 'Actual cumulative full26 CAMCC and all38 managed attachment AArch64 objects passed-Werror; firmware refusal retained, no activation or Image\n'

#!/usr/bin/bash
# COPR only: compile the real prepared controller against accepted24 sources.
set -Eeuo pipefail
[[ ! -e /etc/senemos/kernel-update.conf && $# == 3 && $(uname -m) == aarch64 ]]
kernel=$(realpath "$1")
output=$(realpath -m "$2")
config=$(realpath "$3")
before=$(sha256sum "$config")
mkdir -p "$output"
install -m644 "$config" "$output/.config"
bash "$kernel/scripts/config" --file "$output/.config" --set-str INITRAMFS_SOURCE ''
make -s -C "$kernel" ARCH=arm64 LLVM=1 LLVM_IAS=1 O="$output" \
 LOCALVERSION=-24-unstable olddefconfig prepare modules_prepare
grep -Fx 'CONFIG_SM_CAMCC_7675=y' "$output/.config"
make -C "$kernel" ARCH=arm64 LLVM=1 LLVM_IAS=1 O="$output" \
 LOCALVERSION=-24-unstable KCFLAGS=-Werror -j4 drivers/clk/qcom/camcc-sm7675.o
object=$output/drivers/clk/qcom/camcc-sm7675.o
llvm-readelf -h "$object" | grep -E 'Machine:.*AArch64'
for symbol in platform_get_irq_byname __request_region ioremap_prot; do
 llvm-nm --undefined-only "$object" | awk -v s="$symbol" '$NF==s{found=1}END{exit !found}'
done
for marker in crmc-map crm-admission firmware-enabled-refused; do
 grep -aqF "$marker" "$object"
done
project=$(cd -- "$(dirname -- "$0")/.." && pwd)
stage=$output/crm-adapters
mkdir "$stage"
install -m644 "$project/tests/fixtures/camcc-crm-ccf-object.c" "$stage/crm-adapters.c"
printf '%s\n' 'obj-y += crm-adapters.o' "ccflags-y += -I$kernel/drivers/clk/qcom" > "$stage/Makefile"
make -C "$kernel" ARCH=arm64 LLVM=1 LLVM_IAS=1 O="$output" M="$stage" \
 LOCALVERSION=-24-unstable KCFLAGS=-Werror -j4 crm-adapters.o
llvm-readelf -h "$stage/crm-adapters.o" | grep -E 'Machine:.*AArch64'
for symbol in uke_camcc_crm_ccf_attach_check uke_camcc_crm_transport_vote_check;do
 llvm-nm --defined-only "$stage/crm-adapters.o" | awk -v s="$symbol" '$NF==s{found=1}END{exit !found}'
done
for symbol in synchronize_irq wait_for_completion_timeout clk_hw_get_parent_by_index;do
 llvm-nm --undefined-only "$stage/crm-adapters.o" | awk -v s="$symbol" '$NF==s{found=1}END{exit !found}'
done
[[ $(sha256sum "$config") == "$before" ]]
[[ ! -e $output/arch/arm64/boot/Image && ! -e $output/drivers/clk/qcom/camcc-sm7675.ko ]]
[[ ! -e $stage/crm-adapters.ko ]]
sha256sum "$object" "$stage/crm-adapters.o" "$output/.config"
printf 'Actual prepared full24 CAMCC AArch64 object passes-Werror with passive CRMC/IRQ resolution; firmware CRM remains refused\n'

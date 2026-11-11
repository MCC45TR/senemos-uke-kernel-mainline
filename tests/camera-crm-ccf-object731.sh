#!/usr/bin/env bash
# COPR only: compile the full driver and force code generation for CCF/PM adapters.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 3 && $(uname -m) == aarch64 ]]
project=$(cd -- "$(dirname -- "$0")/.." && pwd)
kernel=$(realpath "$1")
output=$(realpath -m "$2")
config=$(realpath "$3")
input_hash=$(sha256sum "$config")
mkdir -p "$output"
install -m644 "$config" "$output/.config"
bash "$kernel/scripts/config" --file "$output/.config" --set-str INITRAMFS_SOURCE ''
make -C "$kernel" ARCH=arm64 LLVM=1 LLVM_IAS=1 O="$output" \
    LOCALVERSION=-12204-unstable olddefconfig prepare modules_prepare
config_hash=$(sha256sum "$output/.config")
stage=$output/camcc-crm-ccf-object
mkdir -p "$stage"
install -m644 "$project/src/camera/camcc-sm7675.c" "$stage/camcc-crm-builtin.c"
install -m644 "$project/tests/fixtures/camcc-crm-ccf-object.c" "$stage/camcc-crm-adapters.c"
printf '%s\n' 'obj-y += camcc-crm-builtin.o camcc-crm-adapters.o' \
    "ccflags-y += -I$project/src/camera -I$project/src/camera/include -I$kernel/drivers/clk/qcom" \
    > "$stage/Makefile"
make -C "$kernel" ARCH=arm64 LLVM=1 LLVM_IAS=1 O="$output" M="$stage" \
    LOCALVERSION=-12204-unstable KCFLAGS=-Werror -j4 \
    camcc-crm-builtin.o camcc-crm-adapters.o
for variant in builtin adapters; do
    object=$stage/camcc-crm-$variant.o
    llvm-readelf -h "$object" | grep -E 'Machine:.*AArch64'
    sha256sum "$object"
done
llvm-readelf -SW "$stage/camcc-crm-builtin.o" | grep -F '.initcall'
if llvm-readelf -SW "$stage/camcc-crm-adapters.o" | grep -Fq '.initcall'; then exit 1; fi
for symbol in uke_camcc_crm_ccf_attach_check uke_camcc_crm_transport_vote_check; do
    llvm-nm --defined-only "$stage/camcc-crm-adapters.o" | grep -E "[[:space:]]${symbol}$"
done
for symbol in synchronize_irq wait_for_completion_timeout clk_hw_get_parent_by_index; do
    llvm-nm --undefined-only "$stage/camcc-crm-adapters.o" | grep -E "[[:space:]]${symbol}$"
done
[[ $(sha256sum "$config") == "$input_hash" && $(sha256sum "$output/.config") == "$config_hash" ]]
test ! -e "$output/arch/arm64/boot/Image"
test ! -e "$stage/camcc-crm-adapters.ko"
printf 'Complete AArch64 CAMCC provider and actual CCF/PM adapter objects compiled with-Werror; no Image/module/activation\n'

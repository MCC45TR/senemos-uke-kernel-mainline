#!/usr/bin/env bash
# COPR only: actual kernel API/code generation against the complete12204 tree.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 3 && $(uname -m) == aarch64 ]]
project=$(cd -- "$(dirname -- "$0")/.." && pwd)
kernel=$(realpath "$1")
output=$(realpath -m "$2")
config=$(realpath "$3")
input_hash=$(sha256sum "$config")
test ! -e "$kernel/drivers/clk/qcom/uke-crm-qualification.c"
mkdir -p "$kernel/drivers/clk/qcom/uke-crm-check" "$output"
for header in core transport lut; do
    install -m644 "$project/src/camera/provider/camcc-sm7675-crm-$header.h" \
        "$kernel/drivers/clk/qcom/uke-crm-check/"
done
cat > "$kernel/drivers/clk/qcom/uke-crm-qualification.c" <<'C'
// SPDX-License-Identifier: GPL-2.0-only
#include "uke-crm-check/camcc-sm7675-crm-transport.h"
#include "uke-crm-check/camcc-sm7675-crm-lut.h"
int uke_cam_crm_probe(struct cam_cc_crm_transport *, struct device *, void __iomem *,
                     int, int (*)(void *), void *);
int uke_cam_crm_vote(struct cam_cc_crm_transport *, u32, u32, u32);
int uke_cam_crm_lut(u32, cam_cc_crm_lut_read_fn, cam_cc_crm_lut_parent_fn,
                   void *, struct cam_cc_crm_lut *);
int uke_cam_crm_idle(struct cam_cc_crm_transport *, bool);
int uke_cam_crm_resume(struct cam_cc_crm_transport *);
int uke_cam_crm_probe(struct cam_cc_crm_transport *t, struct device *dev,
                     void __iomem *base, int irq, int (*access)(void *), void *context)
{ return cam_cc_crm_transport_init(t, dev, base, irq, access, context); }
int uke_cam_crm_vote(struct cam_cc_crm_transport *t, u32 kind, u32 resource, u32 value)
{ return cam_cc_crm_transport_vote(t, kind, resource, value); }
int uke_cam_crm_lut(u32 vcd, cam_cc_crm_lut_read_fn read,
                   cam_cc_crm_lut_parent_fn parent, void *context,
                   struct cam_cc_crm_lut *table)
{ return cam_cc_crm_lut_load(vcd, 0x2000, read, parent, context, table); }
int uke_cam_crm_idle(struct cam_cc_crm_transport *t, bool release)
{ return cam_cc_crm_transport_idle(t, release); }
int uke_cam_crm_resume(struct cam_cc_crm_transport *t)
{ return cam_cc_crm_transport_resume(t); }
C
install -m644 "$config" "$output/.config"
bash "$kernel/scripts/config" --file "$output/.config" --set-str INITRAMFS_SOURCE ''
make -C "$kernel" ARCH=arm64 LLVM=1 LLVM_IAS=1 O="$output" \
    LOCALVERSION=-12204-unstable olddefconfig prepare modules_prepare
config_hash=$(sha256sum "$output/.config")
make -C "$kernel" ARCH=arm64 LLVM=1 LLVM_IAS=1 O="$output" \
    LOCALVERSION=-12204-unstable KCFLAGS=-Werror -j4 drivers/clk/qcom/uke-crm-qualification.o
[[ $(sha256sum "$config") == "$input_hash" && $(sha256sum "$output/.config") == "$config_hash" ]]
object=$output/drivers/clk/qcom/uke-crm-qualification.o
llvm-readelf -h "$object" | grep -E 'Machine:.*AArch64'
for symbol in uke_cam_crm_probe uke_cam_crm_vote uke_cam_crm_lut uke_cam_crm_idle uke_cam_crm_resume cam_cc_crm_transport_irq; do
    llvm-nm --defined-only "$object" | grep -E "[[:space:]]${symbol}$"
done
llvm-nm --undefined-only "$object" | grep -E '[[:space:]]request_threaded_irq$'
llvm-nm --undefined-only "$object" | grep -E '[[:space:]]wait_for_completion_timeout$'
llvm-nm --undefined-only "$object" | grep -E '[[:space:]]synchronize_irq$'
llvm-nm --undefined-only "$object" | grep -E '[[:space:]]free_irq$'
sha256sum "$object"
test ! -e "$output/arch/arm64/boot/Image"
test ! -e "$output/drivers/clk/qcom/uke-crm-qualification.ko"
printf 'Real AArch64 CRM IRQ/vote/LUT/idle/resume object compiled with complete12204 config and-Werror; no provider activation, Image or module\n'

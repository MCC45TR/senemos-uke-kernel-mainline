#!/usr/bin/env bash
# Host-only preparation on an isolated, already qualified ordered source tree.
set -Eeuo pipefail
[[ $# == 2 && -d $1 && -d $2 ]] || exit 2
kernel=$(realpath "$1") output=$(realpath "$2")
here=$(cd -- "$(dirname -- "$0")" && pwd)
usb_profile=${UKE_USB_PROFILE:-peripheral}
case $usb_profile in peripheral|typec-v1) ;; *) echo 'Unknown USB source profile' >&2; exit 2;; esac
llcc_profile=${UKE_LLCC_PROFILE:-disabled}
case $llcc_profile in
    disabled) llcc_native=0;;
    native-v1) llcc_native=1;;
    *) echo 'Unknown LLCC source profile' >&2; exit 2;;
esac
version=$(jq -er .version "$kernel/senemos-adaptation/source-lock.json")
case $version in 7.2.9|7.2.10|7.2.11|7.2.12|7.3.0) ;; *) exit 1;; esac
[[ $(awk '/^VERSION =/ {v=$3} /^PATCHLEVEL =/ {p=$3} /^SUBLEVEL =/ {s=$3} END {print v "." p "." s}' "$kernel/Makefile") == "$version" ]]
cmp "$kernel/senemos-applied-patches.txt" <(jq -er '.patches[].path | split("/") | last' "$kernel/senemos-adaptation/source-lock.json")
if [[ $llcc_native == 1 ]]; then
    bash "$here/../../tests/llcc-sm7675-contract.sh" "$kernel"
    bash "$here/../../tests/llcc-gpu-startup-contract.sh" "$kernel/drivers/gpu/drm/msm/adreno/adreno_device.c"
    bash "$here/../../tests/llcc-boot-fdt-contract.sh" "$kernel"
fi
# Wi-Fi requires the package-owned RF/GENI/SMMU contract; older pairs keep their frozen recipe.
grep -Fxq 0015-uke-wlan-supplies-and-dma.patch "$kernel/senemos-applied-patches.txt"
grep -Fxq 0016-uke-wlan-ordered-rails.patch "$kernel/senemos-applied-patches.txt"
# The second backlight bus requires its own NoC and translated-DMA admission.
grep -Fxq 0023-uke-qup1-backlight-bus.patch "$kernel/senemos-applied-patches.txt"
grep -Fxq 0025-uke-paired-normal-backlight.patch "$kernel/senemos-applied-patches.txt"
grep -Fxq 0026-cliffs-lpass-adsp-interconnect.patch "$kernel/senemos-applied-patches.txt"
grep -Fxq 0036-uke-adreno732-render.patch "$kernel/senemos-applied-patches.txt"
grep -Fxq 0037-uke-gpu-interconnect.patch "$kernel/senemos-applied-patches.txt"
hook_args=(--exclude=drivers/regulator/qcom-rpmh-regulator-uke.c --exclude=drivers/iommu/arm/arm-smmu/arm-smmu-qcom.c)
git -C "$kernel" apply --check "${hook_args[@]}" "$here/../../patches/boot/0001-arm64-uke-abl-dt-hook.patch"
git -C "$kernel" apply "${hook_args[@]}" "$here/../../patches/boot/0001-arm64-uke-abl-dt-hook.patch"
git -C "$kernel" apply --check "$here/../../patches/boot/0002-uke-sensor-context-banks.patch"
git -C "$kernel" apply "$here/../../patches/boot/0002-uke-sensor-context-banks.patch"
git -C "$kernel" apply --check "$here/../../patches/boot/0003-uke-socinfo-sensor-profile.patch"
git -C "$kernel" apply "$here/../../patches/boot/0003-uke-socinfo-sensor-profile.patch"
git -C "$kernel" apply --check "$here/../../patches/boot/0004-uke-bluetooth-power.patch"
git -C "$kernel" apply "$here/../../patches/boot/0004-uke-bluetooth-power.patch"
git -C "$kernel" apply --check "$here/../../patches/boot/0005-uke-root-selector.patch"
git -C "$kernel" apply "$here/../../patches/boot/0005-uke-root-selector.patch"
git -C "$kernel" apply --check "$here/../../patches/boot/0006-uke-uart-wake-order.patch"
git -C "$kernel" apply "$here/../../patches/boot/0006-uke-uart-wake-order.patch"
bash "$here/../../tests/uart-wake-contract.sh" "$kernel/drivers/tty/serial/qcom_geni_serial.c"
install -m644 "$here/uke-abl.c" "$kernel/arch/arm64/kernel/uke-abl.c"
install -m644 "$here/uke-identity.c" "$kernel/arch/arm64/kernel/uke-identity.c"
install -m644 "$here/uke-llcc.h" "$kernel/arch/arm64/kernel/uke-llcc.h"
printf '#define UKE_LLCC_NATIVE_PROFILE %s\n' "$llcc_native" > "$kernel/arch/arm64/kernel/uke-llcc-profile.h"
install -m644 "$here/uke-root-selector.h" "$kernel/arch/arm64/kernel/uke-root-selector.h"
install -m644 "$here/uke-bluetooth.h" "$kernel/arch/arm64/kernel/uke-bluetooth.h"
install -m644 "$here/uke-pmic-adc.h" "$kernel/arch/arm64/kernel/uke-pmic-adc.h"
install -m644 "$here/uke-cpu-thermal.h" "$kernel/arch/arm64/kernel/uke-cpu-thermal.h"
install -m644 "$here/uke-hall.h" "$kernel/arch/arm64/kernel/uke-hall.h"
install -m644 "$here/../usb/wcd939x-uke-typec.c" "$kernel/drivers/usb/typec/mux/wcd939x-uke-typec.c"
[[ $(sha256sum "$here/vendor/fdt_check.c" | cut -d ' ' -f1) == "$(jq -er .sha256 "$here/vendor/source.json")" ]]
grep -F 'DTC 1.7.2-g53373d13' "$kernel/scripts/dtc/version_gen.h" >/dev/null
install -m644 "$here/vendor/fdt_check.c" "$kernel/scripts/dtc/libfdt/fdt_check.c"
for name in overlay check; do
    {
        printf '// SPDX-License-Identifier: GPL-2.0-only\n#include <linux/libfdt_env.h>\n'
        # The embedded, source-compiled overlays contain bounded decimal
        # fixup offsets. Upstream libfdt's libc parser needs the kernel API.
        if [[ $name == overlay ]]; then
            printf '#include <linux/kstrtox.h>\n#define strtoul simple_strtoul\n'
        fi
        printf '#include "../scripts/dtc/libfdt/fdt_%s.c"\n' "$name"
    } > "$kernel/lib/fdt_$name.c"
done
header=$kernel/arch/arm64/kernel/uke-abl-overlays.h
: > "$header"
for name in ufs usb; do
    source=$here/sm7675-uke-ufs.dtso
    [[ $name != usb ]] || source=$here/sm7675-uke-usb2.dtso
    if [[ $name == usb && $usb_profile == typec-v1 ]]; then source=$here/sm7675-uke-typec.dtso; fi
    cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp -I "$kernel/include" "$source" > "$output/$name.dts"
    dtc -q -@ -I dts -O dtb -o "$output/$name.dtbo" "$output/$name.dts"
    {
        printf 'static unsigned char uke_%s_overlay[] __initdata __aligned(8) = {\n' "$name"
        od -An -v -tx1 "$output/$name.dtbo" | sed -E 's/[a-f0-9]{2}/0x&,/g'
        printf '};\n'
    } >> "$header"
done
printf '%s\n' "$usb_profile" > "$output/usb-profile"
printf '%s\n' "$llcc_profile" > "$output/llcc-profile"
(cd "$output"; sha256sum ufs.dtbo usb.dtbo > overlay-SHA256SUMS)
sha256sum "$here/uke-abl.c" "$here/uke-identity.c" "$here/uke-bluetooth.h" "$here/vendor/fdt_check.c" "$here/vendor/source.json" \
    "$here/uke-pmic-adc.h" "$here/uke-cpu-thermal.h" "$here/uke-hall.h" \
    "$here/../../patches/boot/0001-arm64-uke-abl-dt-hook.patch" \
    "$here/../../patches/boot/0002-uke-sensor-context-banks.patch" \
    "$here/../../patches/boot/0003-uke-socinfo-sensor-profile.patch" \
    "$here/../../patches/boot/0004-uke-bluetooth-power.patch" \
    "$here/../../patches/$version/0036-uke-adreno732-render.patch" \
    "$here/../../patches/$version/0037-uke-gpu-interconnect.patch" \
    "$here/sm7675-uke-adreno732.dtsi" "$header" > "$output/abl-source-SHA256SUMS"
sha256sum "$here/sm7675-uke-pinctrl.dtsi" >> "$output/abl-source-SHA256SUMS"
sha256sum "$here/uke-root-selector.h" "$here/../../patches/boot/0005-uke-root-selector.patch" >> "$output/abl-source-SHA256SUMS"
sha256sum "$here/../../patches/boot/0006-uke-uart-wake-order.patch" >> "$output/abl-source-SHA256SUMS"
sha256sum "$here/uke-llcc.h" "$kernel/arch/arm64/kernel/uke-llcc-profile.h" \
    "$output/llcc-profile" >> "$output/abl-source-SHA256SUMS"

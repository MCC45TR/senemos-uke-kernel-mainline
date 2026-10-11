#!/usr/bin/env bash
# Kernel-libfdt host fixtures; never a hardware result.
set -Eeuo pipefail
[[ $# == 5 && -x $1 && -s $2 && -s $3 && -s $4 && ! -e $5 ]] || exit 2
binary=$1 input=$2 ufs=$3 usb=$4 out=$5
mkdir -p "$out"
"$binary" "$input" "$ufs" "$usb" "$out/admitted.dtb"
[[ $(fdtget -t s "$out/admitted.dtb" / compatible) == 'xiaomi,uke qcom,sm7675 qcom,cliffs' ]]
[[ $(fdtget -t s "$out/admitted.dtb" / model) == 'Xiaomi Pad 7' ]]
[[ $(fdtget -t s "$out/admitted.dtb" /soc/reboot_reason compatible) == nvmem-reboot-mode ]]
[[ $(fdtget -t s "$out/admitted.dtb" /soc/reboot_reason nvmem-cell-names) == reboot-mode ]]
[[ $(fdtget -t x "$out/admitted.dtb" /soc/reboot_reason nvmem-cells) == "$(fdtget -t x "$input" /soc/reboot_reason nvmem-cells)" ]]
for mode in 'normal 20' 'recovery 1' 'bootloader 2'; do
    read -r name value <<< "$mode"
    [[ $(fdtget -t x "$out/admitted.dtb" /soc/reboot_reason "mode-$name") == "$value" ]]
done
[[ $(fdtget -t s "$out/admitted.dtb" /soc/ufshc@1d84000 compatible) == qcom,ufshc ]]
[[ $(fdtget -t s "$out/admitted.dtb" /soc/ssusb@a600000 dr_mode) == peripheral ]]
for path in /soc/qcom,pmic_glink /soc/qcom,pmic_glink_log /soc/qcom,pmic_glink/qcom,ucsi/connector; do
    [[ $(fdtget -t s "$out/admitted.dtb" "$path" status) == disabled ]]
done
apps=$(fdtget -t x "$out/admitted.dtb" /soc/apps-smmu@15000000 phandle)
for target in 'ufshc@1d84000 60' 'ssusb@a600000 40' 'qcom,gpi-dma@a00000 b6' 'qcom,qupv3_0_geni_se@ac0000 a3'; do
    read -r node sid <<< "$target"
    status=$(fdtget -t s "$out/admitted.dtb" "/soc/$node" status)
    [[ $status == okay || $status == ok ]]
    [[ $(fdtget -t x "$out/admitted.dtb" "/soc/$node" iommus) == "$apps $sid 0" ]]
done
[[ $(fdtget -t s "$out/admitted.dtb" /soc/qcom,qupv3_0_geni_se@ac0000/i2c@a80000 status) == okay ]]
[[ $(fdtget -t s "$out/admitted.dtb" /soc/qcom,qupv3_0_geni_se@ac0000/i2c@a80000/wcd939x_i2c@e status) == okay ]]
for node in qcom,smmu_sde_unsec_cb qcom,smmu_sde_sec_cb; do
    [[ $(fdtget -t s "$out/admitted.dtb" "/soc/$node" status) == disabled ]]
    [[ $(fdtget -t x "$out/admitted.dtb" "/soc/$node" iommus) == "$(fdtget -t x "$input" "/soc/$node" iommus)" ]]
done
[[ $(fdtget -t x "$out/admitted.dtb" /soc/apps-smmu@15000000 qcom,handoff-smrs) == "$(fdtget -t x "$input" /soc/apps-smmu@15000000 qcom,handoff-smrs)" ]]
framebuffer=$(fdtget -t s "$out/admitted.dtb" /chosen stdout-path)
[[ $(fdtget -t u "$out/admitted.dtb" "$framebuffer" width) == 3200 ]]
[[ $(fdtget -t u "$out/admitted.dtb" "$framebuffer" height) == 2136 ]]
[[ $(fdtget -t u "$out/admitted.dtb" "$framebuffer" stride) == 12800 ]]
[[ $(fdtget -t s "$out/admitted.dtb" "$framebuffer" format) == a8r8g8b8 ]]
for scenario in board graph symbols splash truncated overlay iommu-provider iommu-length iommu-id geni-id reboot-cell reboot-offset reboot-bits; do
    cp "$input" "$out/$scenario.dtb"
    case $scenario in
        board) fdtput -t x "$out/$scenario.dtb" / qcom,board-id 9 0;;
        graph) fdtput -t x "$out/$scenario.dtb" /soc/ufshc@1d84000 reg 1d85000 3000;;
        symbols) fdtput -r "$out/$scenario.dtb" /__symbols__;;
        splash) fdtput -t x "$out/$scenario.dtb" /reserved-memory/splash_region reg 0 0 0 1000;;
        truncated) truncate -s 100 "$out/$scenario.dtb";;
        overlay) cp "$usb" "$out/bad.dtbo"; truncate -s 50 "$out/bad.dtbo";;
        iommu-provider) fdtput -t x "$out/$scenario.dtb" /soc/ufshc@1d84000 iommus deadbeef 60 0;;
        iommu-length) fdtput -t x "$out/$scenario.dtb" /soc/ufshc@1d84000 iommus "$apps" 60;;
        iommu-id) fdtput -t x "$out/$scenario.dtb" /soc/ufshc@1d84000 iommus "$apps" 1c00 2;;
        geni-id) fdtput -t x "$out/$scenario.dtb" /soc/qcom,qupv3_0_geni_se@ac0000 iommus "$apps" a4 0;;
        reboot-cell) fdtput -t x "$out/$scenario.dtb" /soc/reboot_reason nvmem-cells deadbeef;;
        reboot-offset) fdtput -t x "$out/$scenario.dtb" /soc/qcom,spmi@c42d000/qcom,pmk8550@0/sdam@7100/restart@48 reg 49 1;;
        reboot-bits) fdtput -t x "$out/$scenario.dtb" /soc/qcom,spmi@c42d000/qcom,pmk8550@0/sdam@7100/restart@48 bits 0 8;;
    esac
    usb_input=$usb
    [[ $scenario != overlay ]] || usb_input=$out/bad.dtbo
    if "$binary" "$out/$scenario.dtb" "$ufs" "$usb_input" "$out/rejected-$scenario.dtb"; then
        echo "Invalid DT was admitted: $scenario" >&2; exit 1
    fi
    [[ ! -e $out/rejected-$scenario.dtb ]]
done
printf '/dts-v1/; / { model="QEMU virtual fixture"; compatible="linux,dummy-virt"; };\n' | dtc -q -I dts -O dtb -o "$out/foreign.dtb"
result=0
"$binary" "$out/foreign.dtb" "$ufs" "$usb" "$out/foreign-output.dtb" || result=$?
[[ $result == 3 && ! -e $out/foreign-output.dtb ]]
echo 'Live-stock DT transform, scoped DMA consumers and malformed-input/foreign-DT rejection groups passed'

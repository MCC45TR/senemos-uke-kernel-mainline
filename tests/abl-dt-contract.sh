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
sram=/soc/mmio-sram@17D09400
sdam=/soc/qcom,spmi@c42d000/qcom,pmk8550@0/sdam@7000
[[ $(fdtget -t x "$out/admitted.dtb" "$sram" reg) == '17d09400 400' ]]
[[ $(fdtget -t x "$out/admitted.dtb" "$sram" ranges) == '0 0 17d09400 0 400' ]]
[[ $(fdtget -t x "$out/admitted.dtb" "$sram/scmi-shmem@0" reg) == '0 0 0 400' ]]
[[ $(fdtget -t x "$out/admitted.dtb" "$sdam/smb1510_present@5d" reg) == '5d 2' ]]
[[ $(fdtget -t x "$out/admitted.dtb" "$sdam/smb1510_present@5d" bits) == '5 5' ]]
[[ $(fdtget -t x "$out/admitted.dtb" "$sdam/ufs_dev@ad" reg) == 'af 1' ]]
if fdtget "$out/admitted.dtb" "$sdam/ufs_dev@ad" bits 2>/dev/null; then exit 1; fi
for node in "$sram" "$sram/scmi-shmem@0" "$sdam" "$sdam/smb1510_present@5d" "$sdam/ufs_dev@ad"; do
    [[ $(fdtget -t x "$out/admitted.dtb" "$node" phandle) == "$(fdtget -t x "$input" "$node" phandle)" ]]
done
[[ $(fdtget -t x "$out/admitted.dtb" "$sdam/ocp-log@76" reg) == "$(fdtget -t x "$input" "$sdam/ocp-log@76" reg)" ]]
apps=$(fdtget -t x "$out/admitted.dtb" /soc/apps-smmu@15000000 phandle)
[[ $(fdtget -t s "$out/admitted.dtb" /soc/qcom,wcn6750 compatible) == 'xiaomi,uke-wcn6750-wifi qcom,wcn6750-wifi' ]]
[[ $(fdtget -t s "$out/admitted.dtb" /soc/qcom,wcn6750 status) == okay ]]
[[ $(fdtget -t x "$out/admitted.dtb" /soc/qcom,wcn6750 iommus) == "$apps 1400 1" ]]
[[ $(fdtget -t x "$out/admitted.dtb" /soc/qcom,wcn6750 qcom,rproc) == "$(fdtget -t x "$input" /soc/remoteproc-wpss@9bb00000 phandle)" ]]
[[ $(fdtget -t x "$out/admitted.dtb" /soc/qcom,wcn6750 memory-region) == "$(fdtget -t x "$input" /reserved-memory/wlan_msa_region@a6400000 phandle)" ]]
[[ $(fdtget -t s "$out/admitted.dtb" /soc/ufshc@1d84000 compatible) == qcom,ufshc ]]
[[ $(fdtget -t s "$out/admitted.dtb" /soc/ssusb@a600000 dr_mode) == peripheral ]]
for path in /soc/qcom,pmic_glink /soc/qcom,pmic_glink_log /soc/qcom,pmic_glink/qcom,ucsi/connector; do
    [[ $(fdtget -t s "$out/admitted.dtb" "$path" status) == disabled ]]
done
for target in 'ufshc@1d84000 60' 'ssusb@a600000 40' 'qcom,gpi-dma@a00000 b6' 'qcom,qupv3_0_geni_se@ac0000 a3' 'qcom,gpi-dma@800000 436' 'qcom,qupv3_1_geni_se@8c0000 423'; do
    read -r node sid <<< "$target"
    status=$(fdtget -t s "$out/admitted.dtb" "/soc/$node" status)
    [[ $status == okay || $status == ok ]]
    [[ $(fdtget -t x "$out/admitted.dtb" "/soc/$node" iommus) == "$apps $sid 0" ]]
done
second=/soc/qcom,qupv3_1_geni_se@8c0000
bus=$second/i2c@890000
gpi=$(fdtget -t x "$input" /soc/qcom,gpi-dma@800000 phandle)
[[ $(fdtget -t s "$out/admitted.dtb" "$bus" compatible) == qcom,geni-i2c ]]
[[ $(fdtget -t s "$out/admitted.dtb" "$bus" clock-names) == se ]]
[[ $(fdtget -t u "$out/admitted.dtb" "$bus" clock-frequency) == 400000 ]]
[[ $(fdtget -t x "$out/admitted.dtb" "$bus" dmas) == "$gpi 0 4 3 $gpi 1 4 3" ]]
for parent in "$second" "$bus"; do
    for child in $(fdtget -l "$out/admitted.dtb" "$parent"); do
        case "$parent/$child" in "$bus"|"$bus/ktz8866@11") continue;; esac
        [[ $(fdtget -t s "$out/admitted.dtb" "$parent/$child" status) == disabled ]]
    done
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
for scenario in board graph symbols splash truncated overlay iommu-provider iommu-length iommu-id geni-id second-geni-id second-gpi-id second-bus-reg second-dma-length second-dma-route second-dma-cells second-dma-count second-dma-mask second-dma-offset second-bus-frequency second-backlight-reg second-backlight-compatible reboot-cell reboot-offset reboot-bits wlan-sid wlan-mask wlan-reg wlan-irq wlan-rproc wlan-msa wlan-supply wlan-voltage soc-cells sram-cells sram-reg sram-range sram-child sram-compatible sdam-reg sdam-bits sdam-size ufs-cell; do
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
        second-geni-id) fdtput -t x "$out/$scenario.dtb" "$second" iommus "$apps" 422 0;;
        second-gpi-id) fdtput -t x "$out/$scenario.dtb" /soc/qcom,gpi-dma@800000 iommus "$apps" 435 0;;
        second-bus-reg) fdtput -t x "$out/$scenario.dtb" "$bus" reg 8a0000 4000;;
        second-dma-length) fdtput -t x "$out/$scenario.dtb" "$bus" dmas "$gpi" 0 4 3;;
        second-dma-route) fdtput -t x "$out/$scenario.dtb" "$bus" dmas "$gpi" 0 3 3 40 0 "$gpi" 1 3 3 40 0;;
        second-dma-cells) fdtput -t u "$out/$scenario.dtb" /soc/qcom,gpi-dma@800000 '#dma-cells' 3;;
        second-dma-count) fdtput -t u "$out/$scenario.dtb" /soc/qcom,gpi-dma@800000 qcom,max-num-gpii 16;;
        second-dma-mask) fdtput -t x "$out/$scenario.dtb" /soc/qcom,gpi-dma@800000 qcom,gpii-mask 1f;;
        second-dma-offset) fdtput -t x "$out/$scenario.dtb" /soc/qcom,gpi-dma@800000 qcom,gpi-ee-offset 0;;
        second-bus-frequency) fdtput -t u "$out/$scenario.dtb" "$bus" qcom,clk-freq-out 100000;;
        second-backlight-reg) fdtput -t x "$out/$scenario.dtb" "$bus/ktz8866@11" reg 10;;
        second-backlight-compatible) fdtput -t s "$out/$scenario.dtb" "$bus/ktz8866@11" compatible kinetic,ktz8866;;
        reboot-cell) fdtput -t x "$out/$scenario.dtb" /soc/reboot_reason nvmem-cells deadbeef;;
        reboot-offset) fdtput -t x "$out/$scenario.dtb" /soc/qcom,spmi@c42d000/qcom,pmk8550@0/sdam@7100/restart@48 reg 49 1;;
        reboot-bits) fdtput -t x "$out/$scenario.dtb" /soc/qcom,spmi@c42d000/qcom,pmk8550@0/sdam@7100/restart@48 bits 0 8;;
        wlan-sid) fdtput -t x "$out/$scenario.dtb" /soc/qcom,wcn6750 iommus "$apps" 1c00 1;;
        wlan-mask) fdtput -t x "$out/$scenario.dtb" /soc/qcom,wcn6750 iommus "$apps" 1400 0;;
        wlan-reg) fdtput -t x "$out/$scenario.dtb" /soc/qcom,wcn6750 reg 17110000 0 c0000000 10000;;
        wlan-irq) fdtput -t x "$out/$scenario.dtb" /soc/qcom,wcn6750 interrupts 0 301 1;;
        wlan-rproc) fdtput -t x "$out/$scenario.dtb" /soc/qcom,wcn6750 qcom,rproc-handle deadbeef;;
        wlan-msa) fdtput -t x "$out/$scenario.dtb" /reserved-memory/wlan_msa_region@a6400000 reg 0 a6400000 0 1000;;
        wlan-supply) fdtput -t x "$out/$scenario.dtb" /soc/qcom,wcn6750 vdd-1.3-rfa-supply deadbeef;;
        wlan-voltage) fdtput -t x "$out/$scenario.dtb" /soc/rsc@17a00000/drv@2/rpmh-regulator-smpb3/regulator-pmxr2230-s3 qcom,init-voltage ffffff;;
        soc-cells) fdtput -t x "$out/$scenario.dtb" /soc '#address-cells' 2;;
        sram-cells) fdtput -t x "$out/$scenario.dtb" "$sram" '#size-cells' 1;;
        sram-reg) fdtput -t x "$out/$scenario.dtb" "$sram" reg 0 17d09400 0 800;;
        sram-range) fdtput -t x "$out/$scenario.dtb" "$sram" ranges 0 0 0 17d09500 0 400;;
        sram-child) fdtput -t x "$out/$scenario.dtb" "$sram/scmi-shmem@0" reg 0 17d09400 0 800;;
        sram-compatible) fdtput -t s "$out/$scenario.dtb" "$sram" compatible simple-bus;;
        sdam-reg) fdtput -t x "$out/$scenario.dtb" "$sdam" reg 7100;;
        sdam-bits) fdtput -t x "$out/$scenario.dtb" "$sdam/smb1510_present@5d" bits 5 1;;
        sdam-size) fdtput -t x "$out/$scenario.dtb" "$sdam/smb1510_present@5d" reg 5d 2;;
        ufs-cell) fdtput -t x "$out/$scenario.dtb" "$sdam/ufs_dev@ad" reg ad 1;;
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

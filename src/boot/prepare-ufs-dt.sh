#!/usr/bin/env bash
# Host-only candidate generation from an existing bounded stock-DT receipt.
# No image flashing, firmware replacement, donor execution or RAM invention.
set -Eeuo pipefail
[[ $# == 3 || ( $# == 4 && $4 == --usb2-peripheral ) ]] || { echo 'Usage: prepare-ufs-dt.sh STOCK_RECEIPT KERNEL_SOURCE OUTPUT_DIR [--usb2-peripheral]' >&2; exit 2; }
receipt=$(realpath "$1") kernel=$(realpath "$2") out=$(realpath -m "$3")
here=$(cd -- "$(dirname -- "$0")" && pwd)
usb=false
[[ $# == 3 ]] || usb=true
[[ -f $receipt/manifest.json && ! -e $out ]]
[[ $(awk '/^VERSION =/ {v=$3} /^PATCHLEVEL =/ {p=$3} /^SUBLEVEL =/ {s=$3} END {print v "." p "." s}' "$kernel/Makefile") == 7.2.9 ]]
for tool in jq sha256sum cpp dtc fdtoverlay fdtget fdtput; do command -v "$tool" >/dev/null; done
[[ $(jq -r '.scope' "$receipt/manifest.json") == stock-package-static-inspection ]]
(cd "$receipt/raw"; sha256sum -c SHA256SUMS)
[[ $(sha256sum "$receipt/raw/vendor_boot.img" | cut -d ' ' -f1) == "$(jq -er '.vendor_boot_sha256' "$receipt/manifest.json")" ]]
[[ $(sha256sum "$receipt/raw/dtbo.img" | cut -d ' ' -f1) == "$(jq -er '.dtbo_sha256' "$receipt/manifest.json")" ]]
[[ -s $receipt/derived/dtb-inventory.tsv ]]
fdtget -t s "$receipt/derived/overlay-0.dtbo" / model | grep -F Uke >/dev/null
mkdir -p "$out"
cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp -I "$kernel/include" \
    "$here/sm7675-uke-ufs.dtso" > "$out/ufs-overlay.dts"
dtc -q -@ -I dts -O dtb -o "$out/ufs-overlay.dtbo" "$out/ufs-overlay.dts"
overlays=("$out/ufs-overlay.dtbo")
if [[ $usb == true ]]; then
    cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp -I "$kernel/include" \
        "$here/sm7675-uke-usb2.dtso" > "$out/usb2-overlay.dts"
    dtc -q -@ -I dts -O dtb -o "$out/usb2-overlay.dtbo" "$out/usb2-overlay.dts"
    overlays+=("$out/usb2-overlay.dtbo")
fi
count=$(jq -r '.base_dtb_count' "$receipt/manifest.json")
[[ $count =~ ^[1-9][0-9]?$ && $count -le 16 ]]
for ((index=0; index<count; ++index)); do
    original=$receipt/derived/merged-$index.dtb
    candidate=$out/stock-ufs-$index.dtb
    [[ -s $original ]]
    expected=$(awk -F '\t' -v i="$index" 'NR>1 && $1==i {print $3}' "$receipt/derived/dtb-inventory.tsv")
    [[ $expected =~ ^[a-f0-9]{64}$ && $(sha256sum "$original" | cut -d ' ' -f1) == "$expected" ]]
    fdtoverlay -i "$original" -o "$candidate" "${overlays[@]}"
    # The generic host must not acquire an unported downstream MSI/ICE backend.
    for property in msi-parent shared-ice-cfg; do
        fdtput -d "$candidate" /soc/ufshc@1d84000 "$property"
    done
    if [[ $usb == true ]]; then
        for property in interrupts-extended extcon usb-role-switch; do
            if fdtget -p "$candidate" /soc/ssusb@a600000 | grep -Fx "$property" >/dev/null; then
                fdtput -d "$candidate" /soc/ssusb@a600000 "$property"
            fi
        done
        [[ $(fdtget -t s "$candidate" /soc/ssusb@a600000 dr_mode) == peripheral ]]
        [[ $(fdtget -t x "$candidate" /soc/ssusb@a600000 interrupts) == '0 85 4' ]]
        [[ $(fdtget -t s "$candidate" /soc/ssusb@a600000/dwc3@a600000 status) == disabled ]]
        [[ $(fdtget -t x "$candidate" /soc/hsphy@88e3000 clocks | awk '{print $2}') == 1d ]]
    fi
    [[ $(fdtget -t x "$candidate" /memory reg) == "$(fdtget -t x "$original" /memory reg)" ]]
    [[ $(fdtget -t x "$candidate" /soc/ufshc@1d84000 iommus) == "$(fdtget -t x "$original" /soc/ufshc@1d84000 iommus)" ]]
    [[ $(fdtget -t x "$candidate" /soc/ufshc@1d84000 reset-gpios) == "$(fdtget -t x "$original" /soc/ufshc@1d84000 reset-gpios)" ]]
    fdtget -t s "$candidate" /soc/ufsphy_mem@1d80000 compatible | grep -Fx qcom,sm7675-qmp-ufs-phy
    dtc -q -I dtb -O dts -o "$out/stock-ufs-$index.dts" "$candidate"
done
jq --arg overlay "$(sha256sum "$out/ufs-overlay.dtbo" | cut -d ' ' -f1)" --argjson usb "$usb" \
    --arg profile "$(sha256sum "$here/../../manifests/linux-7.2.9.json" | cut -d ' ' -f1)" \
    '. + {scope:"stock-derived-UFS-source-candidate",overlay_sha256:$overlay,
          android_dtbo_image:false,launchable:false,selected_dtb_index:null,
          usb2_peripheral_source_candidate:$usb,esp32_host_qualified:false,
          board_identity_applied_as_root_fragment:true,
          required_adaptation_profile_sha256:$profile,
          independent_board_provider_graph_complete:false,
          ram_fixups_modified:false,boot_tested:false,hardware_tested:false}' \
    "$receipt/manifest.json" > "$out/manifest.json"
(cd "$out"; sha256sum ./*.dtb ./*.dtbo ./*.dts manifest.json > SHA256SUMS)
echo 'UFS DT/DTS candidates generated; first-console USB and firmware/RAM admission remain separate'

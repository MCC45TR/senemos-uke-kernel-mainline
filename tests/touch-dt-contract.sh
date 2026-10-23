#!/usr/bin/env bash
# Host-only application to a retained running Uke FDT; no tablet write.
set -Eeuo pipefail
[[ $# == 3 ]] || { echo 'Usage: touch-dt-contract.sh kernel-source running-fdt output-directory' >&2; exit 2; }
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
kernel=$(realpath "$1") input=$(realpath "$2") output=$(realpath -m "$3")
[[ -f $kernel/include/dt-bindings/gpio/gpio.h && -f $input && ! -e $output ]]
mkdir -p "$output"
leaf=/soc/qcom,qupv3_0_geni_se@ac0000/spi@a90000/novatek@0
panel=$(fdtget -t s "$input" /__symbols__ uke_panel)
tlmm=$(fdtget -t s "$input" /__symbols__ tlmm)
tlmm_handle=$(fdtget -t x "$input" "$tlmm" phandle)
[[ $(fdtget -t s "$input" "$leaf" compatible) == novatek,NVT-ts-spi ]]
[[ $(fdtget -t s "$input" "$panel" compatible) == xiaomi,o82-42-02-0b ]]
[[ $(fdtget -t x "$input" "$leaf" novatek,irq-gpio) == "$tlmm_handle 36 2001" ]]
[[ $(fdtget -t x "$input" "$leaf" novatek,lcd_id-gpio) == "$tlmm_handle 1a 0" ]]
if fdtget "$input" "$leaf" interrupts-extended >/dev/null 2>&1; then
    echo 'Unreviewed inherited extended IRQ binding' >&2; exit 1
fi
sha256sum "$input" > "$output/input-before.sha256"
cat > "$output/candidate.dts" <<'DTS'
/dts-v1/;
/plugin/;
#include "sm7675-uke-thp.dtsi"
DTS
cpp -P -nostdinc -undef -D__DTS__ -x assembler-with-cpp -I "$kernel/include" -I "$root/src/input" \
    "$output/candidate.dts" > "$output/overlay.dts"
dtc -q -@ -I dts -O dtb -o "$output/overlay.dtbo" "$output/overlay.dts"
fdtoverlay -i "$input" -o "$output/candidate.dtb" "$output/overlay.dtbo"
[[ $(fdtget -t s "$output/candidate.dtb" "$leaf" compatible) == novatek,nt36532-uke-thp ]]
[[ $(fdtget -t x "$output/candidate.dtb" "$leaf" interrupt-parent) == "$tlmm_handle" ]]
[[ $(fdtget -t x "$output/candidate.dtb" "$leaf" interrupts) == '36 1' ]]
[[ $(fdtget -t x "$output/candidate.dtb" "$leaf" panel-id-gpios) == "$tlmm_handle 1a 0" ]]
[[ $(fdtget -t x "$output/candidate.dtb" "$leaf" panel) == "$(fdtget -t x "$input" "$panel" phandle)" ]]
while IFS= read -r property; do
    case $property in compatible|interrupt-parent|interrupts|panel-id-gpios|panel) continue;; esac
    cmp <(fdtget -t bx "$input" "$leaf" "$property") <(fdtget -t bx "$output/candidate.dtb" "$leaf" "$property")
done < <(fdtget -p "$input" "$leaf")
sha256sum -c "$output/input-before.sha256"
printf 'Candidate touch DT: exact running GPIO/IRQ/panel resources, new driver binding and retained other leaf properties: PASS (host only)\n'

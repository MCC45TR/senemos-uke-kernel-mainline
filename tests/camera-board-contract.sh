#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Host-only DT/schema check. Never opens a device, bus or calibration file.
set -Eeuo pipefail
kernel=${1:?Pass the prepared Linux 7.2.11 source}
provider=${2:?Pass the native camera provider include directory}
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
board=$project/src/camera/board
manifest=$project/manifests/camera-board-candidate-20261021.json
jq -e '.active_series == false and .dt_enabled == false and .kernel_release_changed == false and .physical_capture == null and .rear.eeprom.effective_address == null' "$manifest" >/dev/null
(cd "$project"; jq -r '.source_assets[] | .sha256 + "  " + .path' "$manifest" | sha256sum -c -)
for tool in cpp dtc fdtget fdtput dt-doc-validate dt-mk-schema dt-validate git; do
    command -v "$tool" >/dev/null
done
test -f "$provider/dt-bindings/clock/qcom,sm7675-camcc.h"
clock_ids=$(printf '%s\n' 'CAM_CC_MCLK0_CLK CAM_CC_MCLK4_CLK' | \
    cpp -P -undef -include "$provider/dt-bindings/clock/qcom,sm7675-camcc.h" -)
[[ $clock_ids == '105 113' ]]
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
schema=Documentation/devicetree/bindings/eeprom/at24.yaml
printf '%s  %s\n' \
    98452b4e32c41de9f74608356d2126e0743f7f229391577f0bb451bc180f2e3e \
    "$kernel/$schema" | sha256sum -c -
mkdir -p "$work/$(dirname -- "$schema")"
cp -- "$kernel/$schema" "$work/$schema"
git -C "$work" init -q
git -C "$work" apply --check "$board/0001-dt-bindings-eeprom-camera-64k-models.patch"
git -C "$work" apply "$board/0001-dt-bindings-eeprom-camera-64k-models.patch"
git -C "$work" apply --reverse --check "$board/0001-dt-bindings-eeprom-camera-64k-models.patch"
bindings=$kernel/Documentation/devicetree/bindings
ln -s "$bindings/nvmem" "$work/Documentation/devicetree/bindings/nvmem"
ln -s "$bindings/regulator" "$work/Documentation/devicetree/bindings/regulator"
dt-doc-validate "$work/$schema" > "$work/document.log" 2>&1
test ! -s "$work/document.log" || { cat "$work/document.log"; exit 1; }
dt-mk-schema -j -o "$work/processed.json" "$work/$schema" \
    "$bindings/nvmem/nvmem.yaml" "$bindings/nvmem/nvmem-deprecated-cells.yaml" \
    "$bindings/nvmem/layouts/nvmem-layout.yaml" "$bindings/nvmem/layouts/fixed-cell.yaml" \
    "$bindings/regulator/regulator.yaml" "$bindings/regulator/fixed-regulator.yaml"
cpp -nostdinc -undef -x assembler-with-cpp -I "$kernel/include" -I "$provider" \
    -I "$board" "$project/tests/fixtures/camera-board-resources.dts" > "$work/board.dts"
# Inactive alternatives can share an address; enabled clients cannot.
dtc -@ -Wno-unique_unit_address -Wunique_unit_address_if_enabled \
    -I dts -O dtb -o "$work/board.dtb" "$work/board.dts" 2> "$work/dtc.log"
test ! -s "$work/dtc.log" || { cat "$work/dtc.log"; exit 1; }
validate_schema() {
    dt-validate -s "$work/processed.json" -l 'at24:fixed-regulator' "$1" > "$work/schema.log" 2>&1
    test ! -s "$work/schema.log" || { cat "$work/schema.log"; return 1; }
}
check_board() {
    local dtb=$1 node
    for node in /front-camera /rear-camera /regulator-camera-front-avdd \
        /regulator-camera-rear-avdd /i2c/eeprom@51 /i2c/legacy-eeprom@51; do
        [[ $(fdtget -t s "$dtb" "$node" status) == disabled ]] || return 1
    done
    node=/i2c/eeprom@51
    fdtget "$dtb" "$node" read-only >/dev/null || return 1
    [[ $(fdtget -t u "$dtb" "$node" size) == 8192 ]] || return 1
    [[ $(fdtget -t u "$dtb" "$node" address-width) == 16 ]] || return 1
    [[ $(fdtget -t u "$dtb" "$node" pagesize) == 1 ]] || return 1
    [[ $(fdtget -t x "$dtb" "$node" reg) == 51 ]] || return 1
    [[ $(fdtget -t x "$dtb" "$node" vcc-supply) == \
        "$(fdtget -t x "$dtb" /regulator-io phandle)" ]] || return 1
    # The board source must leave effective sensor topology unspecified.
    ! fdtget "$dtb" /front-camera reg >/dev/null 2>&1 || return 1
    ! fdtget "$dtb" /rear-camera reg >/dev/null 2>&1 || return 1
}
validate_schema "$work/board.dtb"
check_board "$work/board.dtb"
cp "$work/board.dtb" "$work/rear-model.dtb"
fdtput -t s "$work/rear-model.dtb" /i2c/eeprom@51 compatible belling,bl24sa64 atmel,24c64
validate_schema "$work/rear-model.dtb"
# Model-only fixture above is not a rear board address declaration.
for node in /front-camera /rear-camera /regulator-camera-front-avdd \
    /regulator-camera-rear-avdd /i2c/eeprom@51 /i2c/legacy-eeprom@51; do
    cp "$work/board.dtb" "$work/unsafe.dtb"
    fdtput -t s "$work/unsafe.dtb" "$node" status okay
    if check_board "$work/unsafe.dtb"; then echo "Accepted an enabled camera consumer: $node" >&2; exit 1; fi
done
for mutation in readonly width capacity; do
    cp "$work/board.dtb" "$work/unsafe.dtb"
    case $mutation in
        readonly) fdtput -d "$work/unsafe.dtb" /i2c/eeprom@51 read-only ;;
        width) fdtput -t u "$work/unsafe.dtb" /i2c/eeprom@51 address-width 8 ;;
        capacity) fdtput -t u "$work/unsafe.dtb" /i2c/eeprom@51 size 256 ;;
    esac
    if check_board "$work/unsafe.dtb" 2> "$work/expected.log"; then
        echo "Accepted unsafe EEPROM configuration: $mutation" >&2; exit 1
    fi
done
cp "$work/board.dtb" "$work/unsafe.dtb"
fdtput -t s "$work/unsafe.dtb" /i2c/eeprom@51 compatible giantec,gt24p64e atmel,24c32
dt-validate -s "$work/processed.json" -l at24 "$work/unsafe.dtb" > "$work/expected.log" 2>&1
grep -q 'giantec,gt24p64e\|atmel,24c32' "$work/expected.log"
sed '/uke_camera_front_sensor: front-camera/d' "$project/tests/fixtures/camera-board-resources.dts" > "$work/missing.dts"
cpp -nostdinc -undef -x assembler-with-cpp -I "$kernel/include" -I "$provider" \
    -I "$board" "$work/missing.dts" > "$work/missing.pp"
if dtc -I dts -O dtb -o "$work/missing.dtb" "$work/missing.pp" > "$work/expected.log" 2>&1; then
    echo 'Accepted a missing native sensor topology label' >&2; exit 1
fi
grep -q 'uke_camera_front_sensor' "$work/expected.log"
printf '%s\n' 'Camera resource DT and two EEPROM bindings passed; eleven unsafe/missing-topology cases rejected. No hardware operations.'

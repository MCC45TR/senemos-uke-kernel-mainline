#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Host-only validation of real compiled DT examples; never powers a camera.
set -Eeuo pipefail
kernel=${1:?Pass the prepared kernel tree}
output=${2:?Pass the completed dt_binding_check output tree}
schema=$kernel/Documentation/devicetree/bindings/media/i2c/ovti,ov13b10.yaml
processed=$output/Documentation/devicetree/bindings/processed-schema.json
example=$output/Documentation/devicetree/bindings/media/i2c/ovti,ov13b10.example.dts
test -s "$schema" -a -s "$example" -a -s "$processed"
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
check() {
    local name=$1 expected=$2
    cpp -nostdinc -undef -x assembler-with-cpp -I "$kernel/include" "$work/$name.dts" > "$work/$name.pp"
    dtc -@ -I dts -O dtb -o "$work/$name.dtb" "$work/$name.pp"
    dt-validate -s "$processed" -l ovti,ov13b10 "$work/$name.dtb" > "$work/$name.log" 2>&1
    if [[ $expected == accept ]]; then
        if [[ -s $work/$name.log ]]; then cat "$work/$name.log"; return 1; fi
    else
        test -s "$work/$name.log"
        grep -q 'ov13b10\|camera@36' "$work/$name.log"
    fi
}
cp "$example" "$work/four-lane.dts"; check four-lane accept
sed 's/data-lanes = <1 2 3 4>/data-lanes = <1 2>/' "$example" > "$work/two-lane.dts"; check two-lane accept
for field in clocks avdd-supply dovdd-supply dvdd-supply remote-endpoint; do
    sed "/^[[:space:]]*$field =/d" "$example" > "$work/missing-$field.dts"
    check "missing-$field" reject
done
sed 's/data-lanes = <1 2 3 4>/data-lanes = <1 2 3>/' "$example" > "$work/three-lane.dts"; check three-lane reject
sed 's/560000000/400000000/' "$example" > "$work/wrong-link.dts"; check wrong-link reject
sed '/reg = <0x36>;/a\                invented-control = <1>;' "$example" > "$work/unknown.dts"; check unknown reject
printf '%s\n' 'OV13B10 real DT validation: two accepted lane examples and eight rejected resource/endpoint/frequency/property cases passed.'

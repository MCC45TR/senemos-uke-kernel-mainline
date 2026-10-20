#!/usr/bin/env bash
# Synthetic binding fixtures, not an admitted Uke storage device tree.
set -Eeuo pipefail
kernel=${1:?Pass prepared kernel source}
schema=${2:?Pass processed-schema.json}
work=$(mktemp -d)
trap 'result=$?; if ((result)); then for log in "$work"/*.log; do test ! -f "$log" || cat "$log" >&2; done; fi; rm -rf -- "$work"' EXIT
cat > "$work/valid.dts" <<'DTS'
/dts-v1/;
/plugin/;
/ {
    #address-cells = <1>;
    #size-cells = <1>;
    intc: interrupt-controller {
        interrupt-controller;
        #interrupt-cells = <3>;
        #address-cells = <0>;
    };
    ufshc@1d84000 {
        compatible = "qcom,sm7675-ufshc", "qcom,ufshc", "jedec,ufs-2.0";
        reg = <0x1d84000 0x3000>, <0x1da0000 0x800>,
              <0x1da5000 0x2000>, <0x1da4000 0x10>;
        reg-names = "std", "mcq", "mcq-sqd", "mcq-vs";
        interrupt-parent = <&intc>;
        interrupts = <0 265 4>;
        clocks = <&gcc 0>, <&gcc 1>, <&gcc 2>, <&gcc 3>,
                 <&rpmhcc 0>, <&gcc 4>, <&gcc 5>, <&gcc 6>;
        clock-names = "core_clk", "bus_aggr_clk", "iface_clk", "core_clk_unipro",
                      "ref_clk", "tx_lane0_sync_clk", "rx_lane0_sync_clk", "rx_lane1_sync_clk";
    };
};
DTS
sed '/reg-names/d' "$work/valid.dts" > "$work/missing-names.dts"
sed 's/"mcq-sqd", "mcq-vs"/"mcq-vs", "mcq-sqd"/' "$work/valid.dts" > "$work/swapped.dts"
sed 's/<0x1da5000 0x2000>, <0x1da4000 0x10>/<0x1da5000 0x2000>/' "$work/valid.dts" > "$work/missing-reg.dts"
sed 's/, "mcq-vs"//' "$work/valid.dts" > "$work/missing-vs-name.dts"
sed 's/qcom,sm7675-ufshc/qcom,sm8650-ufshc/' "$work/valid.dts" > "$work/foreign-split.dts"
sed '/reg = /c\        reg = <0x1d84000 0x3000>, <0x1da0000 0x800>;' "$work/foreign-split.dts" |
    sed '/<0x1da5000/d; s/, "mcq-sqd", "mcq-vs"//' > "$work/legacy.dts"
for name in valid legacy missing-names swapped missing-reg missing-vs-name foreign-split; do
    dtc -@ -I dts -O dtb -o "$work/$name.dtb" "$work/$name.dts"
    dt-validate -s "$schema" -l qcom,sm8650-ufshc "$work/$name.dtb" \
        > "$work/$name.log" 2>&1
done
test ! -s "$work/valid.log"
test ! -s "$work/legacy.log"
grep -q 'reg-names.*required property' "$work/missing-names.log"
grep -q 'expected' "$work/swapped.log"
grep -q 'reg:.*too short' "$work/missing-reg.log"
grep -q 'reg-names:.*too short' "$work/missing-vs-name.log"
grep -q 'too long' "$work/foreign-split.log"
printf 'UFS binding: SM7675 split and legacy accepted; five incomplete/foreign cases rejected\n'

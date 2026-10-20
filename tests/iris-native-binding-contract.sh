#!/usr/bin/env bash
# Synthetic schema fixtures; addresses and stream IDs are not a board DT.
set -Eeuo pipefail
kernel=${1:?Pass the prepared kernel source}
schema=${2:?Pass processed-schema.json}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cat > "$work/valid.dts" <<'DTS'
/dts-v1/;
/plugin/;
/ {
    #address-cells = <1>;
    #size-cells = <1>;
    video-codec@10000000 {
        compatible = "qcom,sm7675-iris";
        reg = <0x10000000 0x10000>, <0x20000000 0x1000>,
              <0x30000000 0x1000>, <0x40000000 0x1000>;
        reg-names = "iris", "aon", "fence", "qtimer";
        interrupt-parent = <&intc>;
        interrupts = <1>;
        clocks = <&clocks 0>, <&clocks 1>, <&clocks 2>;
        clock-names = "iface", "core", "vcodec0_core";
        power-domains = <&power 0>, <&power 1>;
        power-domain-names = "venus", "vcodec0";
        resets = <&resets 0>, <&resets 1>, <&resets 2>;
        reset-names = "bus", "xo", "core";
        interconnects = <&icc 0 &icc 1>, <&icc 2 &icc 3>;
        interconnect-names = "cpu-cfg", "video-mem";
        iommus = <&smmu 1>;
        dma-coherent;
        memory-region = <&memory>;
        operating-points-v2 = <&opp>;
        pixel {
            compatible = "qcom,sm7675-iris-pixel";
            iommus = <&smmu 2>;
            dma-coherent;
        };
    };
};
DTS
sed '/        pixel {/,/        };/d' "$work/valid.dts" > "$work/missing-pixel.dts"
sed '/            iommus/d' "$work/valid.dts" > "$work/missing-pixel-iommu.dts"
sed '/            dma-coherent/d' "$work/valid.dts" > "$work/noncoherent-pixel.dts"
sed 's/iommus = <&smmu 1>;/iommus = <\&smmu 1>, <\&smmu 2>;/' "$work/valid.dts" > "$work/mixed-control.dts"
sed 's/iommus = <&smmu 2>;/iommus = <\&smmu 2>, <\&smmu 3>;/' "$work/valid.dts" > "$work/mixed-pixel.dts"
sed 's/"fence", "qtimer"/"fence", "timer"/' "$work/valid.dts" > "$work/wrong-mmio-name.dts"
sed 's/<0x30000000 0x1000>, <0x40000000 0x1000>/<0x30000000 0x1000>/' "$work/valid.dts" > "$work/missing-mmio.dts"
for name in valid missing-pixel missing-pixel-iommu noncoherent-pixel mixed-control mixed-pixel wrong-mmio-name missing-mmio; do
    cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp -I "$kernel/include" \
        "$work/$name.dts" | dtc -@ -I dts -O dtb -o "$work/$name.dtb" 2> "$work/$name.dtc.log"
    dt-validate -s "$schema" -l qcom,sm7675-iris "$work/$name.dtb" > "$work/$name.log" 2>&1
done
test ! -s "$work/valid.log"
grep -q "pixel.*required property" "$work/missing-pixel.log"
grep -q "iommus.*required property" "$work/missing-pixel-iommu.log"
grep -q "dma-coherent.*required property" "$work/noncoherent-pixel.log"
grep -q "iommus.*too long" "$work/mixed-control.log"
grep -q "iommus.*too long" "$work/mixed-pixel.log"
grep -q "reg-names" "$work/wrong-mmio-name.log"
grep -q "reg.*too short" "$work/missing-mmio.log"
printf 'Native Iris binding: synthetic valid tree and seven missing/mixed resource refusals passed\n'

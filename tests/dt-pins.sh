#!/usr/bin/env bash
# Read-only audit and deliberately malformed host fixtures; no device writes.
set -Eeuo pipefail
[[ $# == 5 && -x $1 && -s $2 && -s $3 && -s $4 && ! -e $5 ]] || exit 2
binary=$1 input=$2 oem=$3 linux=$4 out=$5
mkdir -p "$out"
"$binary" "$input" "$oem" "$linux" > "$out/accepted.tsv"
reject() {
    local expected=$1 status=0
    shift
    "$@" > "$out/rejected.log" 2>&1 || status=$?
    [[ $status == "$expected" ]]
}
for fault in mux sentinel reference provider gpio gpio-controller; do
    cp "$input" "$out/$fault.dtb"
    case $fault in
        mux) fdtput -t s "$out/$fault.dtb" /soc/pinctrl@f000000/qupv3_se3_spi_pins/qupv3_se3_spi_clk_active/mux function qup1_se3_l2;;
        sentinel) fdtput -t s "$out/$fault.dtb" /soc/pinctrl@f000000/qupv3_se3_spi_pins/qupv3_se3_spi_clk_active/mux function NA;;
        reference) fdtput -t x "$out/$fault.dtb" /soc/qcom,qupv3_0_geni_se@ac0000/i2c@a80000 pinctrl-0 ffffffff;;
        provider) fdtput -t x "$out/$fault.dtb" /soc/clock-controller@100000 '#clock-cells' 20;;
        gpio) fdtput -t x "$out/$fault.dtb" /soc/ufshc@1d84000 reset-gpios ffffffff b2 1;;
        gpio-controller) fdtput -d "$out/$fault.dtb" /soc/pinctrl@f000000 gpio-controller;;
    esac
    reject 1 "$binary" "$out/$fault.dtb" "$oem" "$linux"
done
sed 's/qup0_se3_l2/qup9_se3_l2/g' "$linux" > "$out/wrong-mux.c"
reject 2 "$binary" "$input" "$oem" "$out/wrong-mux.c"
sed -E 's/\{[[:space:]]*0,[[:space:]]*56[[:space:]]*\}/{ 0, 55 }/' "$linux" > "$out/wrong-wake.c"
reject 2 "$binary" "$input" "$oem" "$out/wrong-wake.c"
head -c 40 "$input" > "$out/truncated.dtb"
reject 2 "$binary" "$out/truncated.dtb" "$oem" "$linux"
printf '%s\n' 'DT pin audit: valid input and nine fault cases passed.'

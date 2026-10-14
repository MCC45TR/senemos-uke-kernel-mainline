#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
for tool in dtc fdtoverlay fdtget fdtput; do command -v "$tool" >/dev/null; done
testdir=$(mktemp -d)
trap 'rm -rf "$testdir"' EXIT
pmic=/soc/qcom,spmi@c42d000/qcom,pmxr2230@1
lpg=$pmic/pwm@e800
cat > "$testdir/base.dts" <<'EOF'
/dts-v1/;
/ {
 compatible = "xiaomi,uke";
 #address-cells = <2>;
 #size-cells = <2>;
 soc {
  #address-cells = <1>;
  #size-cells = <1>;
  qcom,spmi@c42d000 {
   reg = <0xc42d000 0x4000>;
   #address-cells = <2>;
   #size-cells = <0>;
   qcom,pmxr2230@1 {
    compatible = "qcom,spmi-pmic";
    reg = <1 0>;
    #address-cells = <1>;
    #size-cells = <0>;
    pwms@e800 { compatible = "qcom,pwm-lpg"; reg = <0xe800>; qcom,num-lpg-channels = <3>; #pwm-cells = <2>; };
    pwms@e900 { compatible = "qcom,pwm-lpg"; reg = <0xe900>; qcom,num-lpg-channels = <1>; #pwm-cells = <2>; };
    pwms@eb00 { compatible = "qcom,pwm-lpg"; reg = <0xeb00>; qcom,num-lpg-channels = <1>; #pwm-cells = <2>; };
    qcom,leds@ef00 { compatible = "qcom,tri-led"; reg = <0xef00>; };
   };
  };
 };
};
EOF
dtc -@ -I dts -O dtb -o "$testdir/base.dtb" "$testdir/base.dts"
dtc -@ -I dts -O dtb -o "$testdir/led.dtbo" src/leds/uke-pmxr2230.dts
check_source() {
    local file=$1 base count
    [[ " $(fdtget -t s "$file" / compatible) " == *' xiaomi,uke '* ]] || return 1
    [[ $(fdtget -t s "$file" "$pmic" compatible) == qcom,spmi-pmic ]] || return 1
    [[ $(fdtget -t x "$file" "$pmic" reg) == '1 0' ]] || return 1
    for base in e800 e900 eb00; do
        count=1
        [[ $base != e800 ]] || count=3
        [[ $(fdtget -t s "$file" "$pmic/pwms@$base" compatible) == qcom,pwm-lpg ]] || return 1
        [[ $(fdtget -t x "$file" "$pmic/pwms@$base" reg) == "$base" ]] || return 1
        [[ $(fdtget -t x "$file" "$pmic/pwms@$base" qcom,num-lpg-channels) == "$count" ]] || return 1
    done
    [[ $(fdtget -t s "$file" "$pmic/qcom,leds@ef00" compatible) == qcom,tri-led ]] || return 1
}
check_graph() {
    local file=$1 path channel
    [[ $(fdtget -t s "$file" "$lpg" compatible) == 'qcom,pmxr2230-pwm qcom,pm8350c-pwm' ]] || return 1
    [[ $(fdtget -t x "$file" "$lpg" reg) == e800 ]] || return 1
    [[ $(fdtget -t x "$file" "$lpg" '#pwm-cells') == 2 ]] || return 1
    for path in pwms@e800 pwms@e900 pwms@eb00 qcom,leds@ef00; do
        [[ $(fdtget -t s "$file" "$pmic/$path" status) == disabled ]] || return 1
    done
    [[ $(fdtget -l "$file" "$lpg" | LC_ALL=C sort | tr '\n' ' ') == 'led@1 led@2 led@3 ' ]] || return 1
    for channel in 1 2 3; do
        path=$lpg/led@$channel
        [[ $(fdtget -t x "$file" "$path" reg) == "$channel" ]] || return 1
        [[ $(fdtget -t x "$file" "$path" color) == "$channel" ]] || return 1
        [[ $(fdtget -t s "$file" "$path" default-state) == off ]] || return 1
        [[ $(fdtget -t s "$file" "$path" function) == status ]] || return 1
        ! fdtget "$file" "$path" linux,default-trigger >/dev/null 2>&1 || return 1
    done
    ! fdtget -p "$file" "$lpg" | grep -Eq 'nvmem|sdam|lut|current|power-source' || return 1
}
check_source "$testdir/base.dtb"
fdtoverlay -i "$testdir/base.dtb" -o "$testdir/result.dtb" "$testdir/led.dtbo"
check_graph "$testdir/result.dtb"
cp "$testdir/result.dtb" "$testdir/bad.dtb"
fdtput -t x "$testdir/bad.dtb" "$lpg/led@3" reg 1
if check_graph "$testdir/bad.dtb"; then echo 'duplicate channel accepted' >&2; exit 1; fi
cp "$testdir/base.dtb" "$testdir/foreign.dtb"
fdtput -t s "$testdir/foreign.dtb" / compatible qcom,foreign
if check_source "$testdir/foreign.dtb"; then echo 'foreign board accepted' >&2; exit 1; fi
fdtput -t s "$testdir/base.dtb" "$pmic" compatible qcom,foreign-pmic
if check_source "$testdir/base.dtb"; then echo 'foreign PMIC accepted' >&2; exit 1; fi
fdtput -t s "$testdir/base.dtb" "$pmic" compatible qcom,spmi-pmic
fdtput -t x "$testdir/base.dtb" "$pmic/pwms@e800" qcom,num-lpg-channels 4
if check_source "$testdir/base.dtb"; then echo 'wrong channel count accepted' >&2; exit 1; fi
if [[ -n ${UKE_LED_TEST_FDT:-} ]]; then
    check_source "$UKE_LED_TEST_FDT"
    fdtoverlay -i "$UKE_LED_TEST_FDT" -o "$testdir/captured.dtb" "$testdir/led.dtbo"
    check_graph "$testdir/captured.dtb"
fi
printf '%s\n' 'PMXR2230 LED ownership and default-off graph checks passed; hardware activation is not included'

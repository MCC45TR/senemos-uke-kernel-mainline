#!/usr/bin/env bash
# Actual callbacks, FDT, additive source and native object gates, COPR only.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
out=$(realpath -m "${2:?Native output}")
phase=${3:?prepared, objects or linked}
[[ $phase == prepared || $phase == objects || $phase == linked ]]
profile=$kernel/native-profile
before=$(bash "$profile/packaging/native/hall-initial-source-view733.sh" "$kernel")
[[ $before == "$kernel/native-generated/hall-before-physical-startup.c" ]]
history=$profile/history-before-hall-initial
(cd "$history";sha256sum -c --strict --quiet SHA256SUMS)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
install -Dm644 "$profile/src/boot/uke-hall.h" "$work/src/boot/uke-hall.h"
git -C "$work" apply --reverse --check --whitespace=error "$profile/src/input/0004-hall-initial-gpio-dt.patch"
git -C "$work" apply --reverse --whitespace=error "$profile/src/input/0004-hall-initial-gpio-dt.patch"
cmp "$history/uke-hall.h" "$work/src/boot/uke-hall.h"
cmp "$profile/src/boot/uke-hall.h" "$kernel/boot-recipe/src/boot/uke-hall.h"
awk '
 $0=="hall_initial_legacy=$(bash \"$profile/packaging/native/hall-initial-source-view733.sh\" \"$kernel\")" {init++;next}
 {if(sub(/"\$hall_initial_legacy"/,"\"$kernel/drivers/input/misc/qcom-smp2p-switch.c\""))paths++;print}
 END{if(init!=1||paths!=3)exit 1}
' "$profile/packaging/native/check-migration-cohort731.sh" | cmp - "$history/check-migration-cohort731.sh"
awk '
 $0=="driver=$(bash \"$root/packaging/native/hall-initial-source-view733.sh\" \"$kernel\")" {print "driver=$kernel/drivers/input/misc/qcom-smp2p-switch.c";n++;next}
 {print}END{if(n!=1)exit 1}
' "$profile/tests/hall-startup-controls.sh" | cmp - "$history/hall-startup-controls.sh"
if [[ $phase == prepared ]];then
 for cc in gcc clang;do
  cxx=g++;[[ $cc != clang ]] || cxx=clang++
  for sanitize in 0 1;do CC=$cc CXX=$cxx SANITIZE=$sanitize bash "$profile/tests/hall-initial-gpio.sh" "$kernel";done
 done
 printf 'Actual Hall optional initial GPIO: four callback/DT modes and ten behavioral mutants passed; old callbacks retained, physical boot separate.\n'
 exit 0
fi
grep -Fx 'CONFIG_GPIOLIB=y' "$out/.config"
object=$out/drivers/input/misc/qcom-smp2p-switch.o
llvm-readelf -h "$object" | grep -E 'Machine:.*AArch64'
llvm-nm -u "$object" > "$work/imports"
for symbol in gpiod_get gpiod_get_direction gpiod_get_value_cansleep gpiod_put irq_get_irqchip_state;do
 grep -Eq " U $symbol$" "$work/imports"
done
! grep -Eq ' U (gpiod_direction_|gpiod_set_|gpiod_to_irq)' "$work/imports"
strings "$out/arch/arm64/kernel/uke-abl.o" | grep -Fx state-gpios
if [[ $phase == linked ]];then
 modinfo -F vermagic "$out/drivers/input/misc/qcom-smp2p-switch.ko" | grep -F "$(jq -er .kernel_release "$profile/source-composition.json") "
fi
printf 'Actual cumulative AArch64 Hall initial GPIO and early DT passed:%s; no output/direction/physicalIRQ writers, stationary boot acceptance separate.\n' "$phase"

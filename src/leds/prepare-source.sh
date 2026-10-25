#!/usr/bin/env bash
set -Eeuo pipefail
kernel=$(realpath "${1:?prepared kernel}")
here=$(cd -- "$(dirname -- "$0")" && pwd)
install -m644 "$here/leds-uke-rgb.c" "$kernel/drivers/leds/"
install -m644 "$here/uke-rgb-policy.h" "$here/uke-rgb-uapi.h" "$kernel/drivers/leds/"
install -m644 "$here/uke-rgb-uapi.h" "$kernel/include/uapi/linux/uke-rgb.h"
install -m644 "$here/uke-rgb.h" "$kernel/include/linux/uke-rgb.h"
! grep -q '^config LEDS_UKE_RGB$' "$kernel/drivers/leds/Kconfig"
cat >> "$kernel/drivers/leds/Kconfig" <<'KCONFIG'

config LEDS_UKE_RGB
	tristate "Uke RGB notification policy"
	depends on LEDS_TRIGGERS && LEDS_CLASS_MULTICOLOR && POWER_SUPPLY && OF
	help
	  Exact-board notification LED ownership, battery warnings and a bounded
	  color test. Original QCOM LPG supplies the electrical implementation.
KCONFIG
printf '\nobj-$(CONFIG_LEDS_UKE_RGB) += leds-uke-rgb.o\n' >> "$kernel/drivers/leds/Makefile"
git -C "$kernel" apply --check "$here/../../patches/boot/0012-led-multicolor-sysfs-disable.patch"
git -C "$kernel" apply "$here/../../patches/boot/0012-led-multicolor-sysfs-disable.patch"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$here/../../tests/rgb-policy.sh"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$here/../../tests/rgb-supplier.sh"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$here/../../tests/rgb-lifetime.sh"
[[ ${UKE_SKIP_TESTS:-0} == 1 ]] || bash "$here/../../tests/rgb-sysfs.sh" "$kernel"

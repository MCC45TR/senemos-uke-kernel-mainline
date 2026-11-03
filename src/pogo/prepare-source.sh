#!/usr/bin/env bash
set -Eeuo pipefail
kernel=$(realpath "${1:?Pass prepared kernel}")
here=$(cd -- "$(dirname -- "$0")" && pwd)
for name in hid-nanosic-uke.c nanosic-uke-protocol.h nanosic-uke-hid.h; do
    install -m644 "$here/$name" "$kernel/drivers/hid/$name"
done
cat >> "$kernel/drivers/hid/Kconfig" <<'KCONFIG'

config HID_NANOSIC_UKE
    tristate "POCO Pad X1 Nanosic WN8030 pogo keyboard"
    depends on HID && I2C && OF && GPIOLIB && REGULATOR && LEDS_CLASS && ARCH_QCOM
    select CRYPTO_LIB_SHA256
    help
      Uke-specific WN8030 RAM firmware download, HID keyboard/touchpad,
      attachment, LED and sleep support. Requires the exact local Uke MCU
      image. Authentication tokens require a trusted userspace provider.
      Physical accessory compatibility remains under qualification.
KCONFIG
printf '\nobj-$(CONFIG_HID_NANOSIC_UKE) += hid-nanosic-uke.o\n' >> "$kernel/drivers/hid/Makefile"

#!/usr/bin/env bash
set -Eeuo pipefail
[[ $# == 1 && -f $1/drivers/firmware/qcom/qcom_scm.c ]] || exit 64
kernel=$(realpath "$1")
here=$(cd -- "$(dirname -- "$0")" && pwd)
git -C "$kernel" apply --check "$here/../../patches/boot/0072-uke-el2-query.patch"
git -C "$kernel" apply "$here/../../patches/boot/0072-uke-el2-query.patch"
install -m644 "$here/uke-el2-query.h" "$kernel/drivers/firmware/qcom/uke-el2-query.h"
cat >> "$kernel/drivers/firmware/qcom/Kconfig" <<'KCONFIG'

config QCOM_UKE_EL2_QUERY
	bool "Read Uke EL2 service advertisement once during SCM probe"
	depends on QCOM_SCM && ARM64
	default n
	help
	  Query SCM INFO for BOOT command 0x21 and expose the returned snapshot.
	  This never invokes BOOT command 0x21 or requests Gunyah exit.
	  Advertisement does not establish early-boot policy or EL2 delivery.
KCONFIG

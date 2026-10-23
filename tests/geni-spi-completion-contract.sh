#!/usr/bin/env bash
# Compile the actual callback against its SPI-core completion contract.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
kernel=${1:?prepared kernel source required}
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
awk '
 /^spi_gsi_callback_result\(/ { copying=1 }
 copying { print }
 copying && /^}/ { copying=0; found++ }
 END { if (found!=1) exit 1 }
' "$kernel/drivers/spi/spi-geni-qcom.c" > "$stage/body.h"
{ printf 'static void\n'; cat "$stage/body.h"; } > "$stage/production.h"
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -I "$stage" "$root/tests/geni-spi-completion.c" -o "$stage/check"
"$stage/check"
printf '%s\n' 'GPI success retains SPI-core accounting; DMA error/residue fail and every path completes once: PASS'

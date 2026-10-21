#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Host-only exact-preimage and inactive-patch validation; no device operations.
set -Eeuo pipefail
kernel=${1:?Pass the pristine prepared Linux 7.2.11 tree}
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
printf '%s  %s\n' \
  f3ea8784ee3a5cccda14e2b9f727eba4bd974b52c6656962f3c9ab6f82b447f6 "$kernel/drivers/media/i2c/ov13b10.c" | sha256sum -c -
mkdir -p "$work/drivers/media/i2c"
cp "$kernel/drivers/media/i2c/ov13b10.c" "$work/drivers/media/i2c/"
cp "$kernel/MAINTAINERS" "$work/"
git -C "$work" init -q
for patch in "$project"/src/camera/*.patch; do
    if grep -Fq "${patch##*/}" "$project/patches/7.2.11/series"; then
        printf 'Camera prerequisite unexpectedly active\n' >&2; exit 1
    fi
    git -C "$work" apply --check "$patch"
    git -C "$work" apply "$patch"
done
grep -q 'MODULE_DEVICE_TABLE(of, ov13b10_of_match)' "$work/drivers/media/i2c/ov13b10.c"
grep -q '\.of_match_table = ov13b10_of_match' "$work/drivers/media/i2c/ov13b10.c"
grep -q 'MODULE_DEVICE_TABLE(acpi, ov13b10_acpi_ids)' "$work/drivers/media/i2c/ov13b10.c"
test -s "$work/Documentation/devicetree/bindings/media/i2c/ovti,ov13b10.yaml"
for patch in "$project"/src/camera/*.patch; do git -C "$work" apply --reverse --check "$patch"; done
printf '%s\n' 'OV13B10 exact preimage, fresh Git application, OF/ACPI tables and inactive-series checks passed.'

#!/usr/bin/env bash
# COPR source preparation: no clock, gain, ADC or physical protection change.
set -Eeuo pipefail
kernel=$(realpath "${1:?Prepared kernel source}")
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
git -C "$kernel" apply --check "$owner/patches/boot/0074-uke-speaker-pcm-formats.patch"
git -C "$kernel" apply "$owner/patches/boot/0074-uke-speaker-pcm-formats.patch"

#!/usr/bin/env bash
# Host-only fixture of the exact cached sysfs reader; no GPU or device writes.
set -Eeuo pipefail
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source=${1:?Pass prepared drivers/gpu/drm/msm/msm_gpu_devfreq.c}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
awk '/^static ssize_t gpu_engine_ns_show/{copy=1} /^static DEVICE_ATTR_RO\(gpu_engine_ns\)/{copy=0} copy' "$source" > "$work/reader.inc"
test -s "$work/reader.inc"
! grep -E 'pm_runtime|gpu_busy\(|mutex_|atomic64_(set|add)' "$work/reader.inc"
cp "$project/tests/gpu-load.cpp" "$work/"
${CXX:-c++} -std=c++20 -O2 -Wall -Wextra -Werror -Wno-unused-parameter "$work/gpu-load.cpp" -o "$work/test"
"$work/test"

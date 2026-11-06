#!/usr/bin/env bash
# COPR only: actual callbacks, original failure and bandwidth-factor mutant.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
ulimit -c 0
owner=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
kernel=$(realpath -- "${1:?Prepared Linux directory}")
original=$(realpath -- "${2:?Exact original performance source}")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
source=$kernel/drivers/gpu/drm/msm/disp/dpu1/dpu_core_perf.c
sed 's/crtc_plane_bw \*= bw_factor;/crtc_plane_bw *= 100;/' "$source" > "$work/wrong-factor.c"
! cmp -s "$source" "$work/wrong-factor.c"
expect_assertion() {
  local label=$1
  shift
  set +e
  "$@" > "$work/control.txt" 2>&1
  local status=$?
  set -e
  [[ $status == 134 ]]
  grep -F 'result.bw_ctl == expected' "$work/control.txt" >/dev/null
  printf '%s: expected bandwidth assertion, status134\n' "$label"
}
for compiler in gcc clang; do
  for mode in ordinary sanitizer; do
    flags=
    [[ $mode != sanitizer ]] || flags='-fsanitize=address,undefined -fno-omit-frame-pointer'
    printf 'DPU mode=%s compiler=%s\n' "$mode" "$compiler"
    CC=$compiler DPU_TEST_FLAGS=$flags bash "$owner/tests/dpu-checked-state-contract.sh" "$kernel"
    expect_assertion "$compiler/$mode original" env CC="$compiler" DPU_TEST_FLAGS="$flags" \
      DPU_PERF_SOURCE="$original" bash "$owner/tests/dpu-checked-state-contract.sh" "$kernel"
    expect_assertion "$compiler/$mode wrong-factor" env CC="$compiler" DPU_TEST_FLAGS="$flags" \
      DPU_PERF_SOURCE="$work/wrong-factor.c" bash "$owner/tests/dpu-checked-state-contract.sh" "$kernel"
  done
done

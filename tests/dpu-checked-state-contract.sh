#!/usr/bin/env bash
# COPR only: executes the actual callbacks and actual DRM iterator/fallback.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
kernel=$(realpath -- "${1:?Prepared kernel source directory}")
source=${DPU_PERF_SOURCE:-$kernel/drivers/gpu/drm/msm/disp/dpu1/dpu_core_perf.c}
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
extract_function() {
  awk -v name="$2" '
    $0 ~ name "\\(" && $0 !~ /^ \*/ && !emit {
      if ($0 !~ /^(static |u64 )/) print previous;
      emit=1;
    }
    emit { print }
    emit && /^}/ { found=1;exit }
    { previous=$0 }
    END { if (!found) exit 1 }
  ' "$1"
}
extract_macro() {
  awk -v name="$2" '
    $0 ~ "^#define " name "\\(" {emit=1}
    emit {print;if($0 !~ /\\$/){found=1;exit}}
    END{if(!found)exit 1}
  ' "$1"
}
extract_function "$kernel/include/drm/drm_atomic.h" __drm_atomic_get_current_plane_state > "$work/atomic-current.inc"
extract_macro "$kernel/include/drm/drm_atomic_helper.h" drm_atomic_crtc_state_for_each_plane_state > "$work/atomic-iterators.inc"
extract_macro "$kernel/include/drm/drm_atomic_helper.h" drm_atomic_crtc_for_each_plane >> "$work/atomic-iterators.inc"
for function in dpu_core_perf_adjusted_mode_clk _dpu_core_perf_calc_bw _dpu_core_perf_calc_clk _dpu_core_perf_calc_crtc; do
  extract_function "$source" "$function" >> "$work/dpu-callbacks.inc"
done
read -ra flags <<< "${DPU_TEST_FLAGS:-}"
"${CC:-gcc}" -std=gnu11 -O1 -g -Wall -Wextra -Werror -Wno-unused-function \
  "${flags[@]}" -I"$work" "$owner/tests/fixtures/dpu-checked-state.c" -o "$work/check"
"$work/check"

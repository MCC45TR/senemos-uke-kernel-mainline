#!/usr/bin/env bash
# Source-only COPR integration; never patches a running/installed kernel.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
kernel=$(realpath -- "${1:?Prepared Linux source directory}")
source=$kernel/drivers/gpu/drm/msm/disp/dpu1/dpu_core_perf.c
before=$(git hash-object "$source")
case "$before" in
  fea173e374648e35b085e51a99661151709d00bf)
    git -C "$kernel" apply --check "$owner/0001-dpu-bw-checked-state.patch"
    git -C "$kernel" apply "$owner/0001-dpu-bw-checked-state.patch"
    ;;
  9fa55904dba1a440a9e9ae22bf6fe0fedf79059c)
    printf 'DPU bandwidth checked-state correction already present\n'
    ;;
  *)
    printf 'Unexpected DPU performance source; preserve it and review the cumulative delta\n' >&2
    exit 2
    ;;
esac
test "$(git hash-object "$source")" = 9fa55904dba1a440a9e9ae22bf6fe0fedf79059c
printf 'DPU source equals upstream480ba24/f66469d9; clocks, limits and modes retained\n'

#!/usr/bin/bash
# COPR native only: compile actual production functions with asserted providers.
set -Eeuo pipefail
[[ $# == 1 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1")
here=$(cd -- "$(dirname -- "$0")" && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
extract() {
 awk -v prefix="$2" -v end="$3" 'index($0,prefix)==1{copy=1;found=1}copy{print}copy&&$0~end{exit}END{if(!found)exit 1}' "$1"
}
panel=$kernel/drivers/gpu/drm/panel/panel-xiaomi-o82.c
manager=$kernel/drivers/gpu/drm/msm/dsi/dsi_manager.c
atomic=$kernel/drivers/gpu/drm/msm/msm_atomic.c
extract "$panel" 'struct o82_command {' '^};' > "$work/panel-types.inc"
for signature in 'static int o82_apply_abm(' 'static int o82_abm_apply_locked(' 'static int o82_abm_update(' 'static void o82_abm_first_frame_complete(';do
 extract "$panel" "$signature" '^}' >> "$work/panel-functions.inc"
done
for signature in 'int qcom_uke_dsi_abm_register(' 'int msm_dsi_manager_uke_abm_apply(';do
 extract "$manager" "$signature" '^}' >> "$work/registry-functions.inc"
done
for signature in 'static bool msm_uke_abm_changed(' 'static void msm_uke_abm_commit(';do
 extract "$atomic" "$signature" '^}' >> "$work/commit-functions.inc"
done
! grep -Fq 'old_connector_state->abm_level != new_connector_state->abm_level' "$kernel/drivers/gpu/drm/drm_atomic_helper.c"
grep -Fq 'if (msm_uke_abm_changed(state, crtc))' "$atomic"
grep -Fq 'msm_uke_abm_commit(state);' "$atomic"
ulimit -c 0
for compiler in gcc clang;do
 for mode in plain sanitized;do
  flags=()
  [[ $mode != sanitized ]] || flags=(-fsanitize=address,undefined -fno-omit-frame-pointer)
  "$compiler" -std=gnu11 -O2 -g -UNDEBUG -Wall -Wextra -Werror "${flags[@]}" -I "$work" "$here/native-abm734.c" -o "$work/check"
  readelf -h "$work/check" | grep -F AArch64
  timeout 15s "$work/check"
 done
done

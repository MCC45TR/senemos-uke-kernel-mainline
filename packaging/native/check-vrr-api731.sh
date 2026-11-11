#!/usr/bin/env bash
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative source}")
out=$(realpath "${2:?Native output}")
phase=${3:-objects}
[[ $phase == source || $phase == objects || $phase == linked ]]
profile=$kernel/native-profile
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
file=$kernel/drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c
awk '/^static unsigned int o82_vrr_test_min_hz;/ {copy=1} copy{print}
 /^MODULE_PARM_DESC\(o82_vrr_floor_api,/ {description=1}
 description&&/\);$/ {found++;exit} END{if(found!=1)exit 1}' "$file" > "$work/block.c"
jq -r '.after_block_sha256+"  '"$work"'/block.c"' "$profile/manifests/audio-vrr-20261107.json" | sha256sum -c --strict -
jq -e '.vrr_saved_floor_api_layer==1 and .vrr_saved_floor_api_get_only and .vrr_kernel_default_and_display_admission_unchanged and .vrr_default_enabled==false and .protected_idle_worker_layer==1 and (.physical_acceptance|not)' "$profile/source-composition.json" >/dev/null
[[ $phase != source ]] || exit 0
bash "$profile/packaging/native/check-idle-stop731.sh" "$kernel" "$out" "$phase"
object=$out/drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.o
llvm-readelf -h "$object" | grep -E 'Machine:.*AArch64'
llvm-readelf -p .modinfo "$object" > "$work/modinfo"
for parameter in o82_vrr_test_min_hz o82_vrr_floor_api;do grep -Fq "parmtype=$parameter:uint" "$work/modinfo";done
llvm-nm "$object" > "$work/symbols"
grep -Eq ' [rR] o82_vrr_api_ops$' "$work/symbols"
grep -Eq ' [dD] o82_vrr_floor_api$' "$work/symbols"
printf 'Actual AArch64 O82 VRR read-only API and both module type fields passed:%s; capability still follows actual admission.\n' "$phase"

#!/usr/bin/env bash
# COPR only; preserve all existing mode/receiver/atomic display admission.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative source}")
profile=$(realpath "${2:?Cumulative profile}")
[[ $profile == "$kernel/native-profile" ]]
file=$kernel/drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c
before=$kernel/native-generated/dpu-encoder-before-vrr-api.c
[[ ! -e $before ]]
cp "$file" "$before"
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
awk '/^static unsigned int o82_vrr_test_min_hz;/ {copy=1} copy{print}
 /^MODULE_PARM_DESC\(o82_vrr_test_min_hz,/ {description=1}
 description&&/\);$/ {found++;exit} END{if(found!=1)exit 1}' "$file" > "$work/old-block.c"
jq -r '.before_block_sha256+"  '"$work"'/old-block.c"' "$profile/manifests/audio-vrr-20261107.json" | sha256sum -c --strict -
git -C "$kernel" apply --check --whitespace=error "$profile/src/display/0075-o82-vrr-floor-api.patch"
git -C "$kernel" apply --whitespace=error "$profile/src/display/0075-o82-vrr-floor-api.patch"
install -Dm644 "$file" "$work/drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c"
git -C "$work" apply --reverse --whitespace=error "$profile/src/display/0075-o82-vrr-floor-api.patch"
cmp "$before" "$work/drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c"
bash "$profile/packaging/native/check-vrr-api731.sh" "$kernel" "$kernel/native-generated" source
for cc in gcc clang;do for san in 0 1;do CC=$cc SANITIZE=$san bash "$profile/tests/o82-vrr-api.sh" "$kernel";done;done
printf 'O82 VRR ABI marker and metadata qualified; zero/default, exact receiver admission and all display timing stay unchanged; physical VRR acceptance separate.\n'

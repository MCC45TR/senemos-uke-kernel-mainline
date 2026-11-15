#!/usr/bin/bash
# Read-only view for the original five-file MST ledger after the native VRR layer.
set -Eeuo pipefail
[[ $# == 2 ]]
kernel=$(realpath "$1");ledger=$(realpath "$2")
profile=$kernel/native-profile
contract=$profile/manifests/native-vrr734-20261115.json
patch=$profile/src/display/0076-uke-native-vrr734.patch
path=drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c
paths=(drivers/soc/qcom/uke-platform-profile.c drivers/gpu/drm/msm/dp/dp_mst_drm.c drivers/gpu/drm/msm/dp/dp_display.c drivers/gpu/drm/msm/msm_drv.h "$path")
[[ -f $ledger && ! -L $ledger ]]
[[ $(wc -l < "$ledger") == 5 ]]
for index in "${!paths[@]}";do
 line=$(sed -n "$((index+1))p" "$ledger")
 [[ $line =~ ^[a-f0-9]{64}'  ' && ${line:66} == "${paths[index]}" ]]
done
before=$(jq -er .before_encoder_sha256 "$contract")
after=$(jq -er .after_encoder_sha256 "$contract")
[[ $(sed -n '5p' "$ledger") == "$before  $path" ]]
[[ $(cat "$kernel/native-generated/native-vrr734-applied") == "$after" ]]
printf '%s  %s\n' "$after" "$kernel/$path" "$(jq -er .patch_sha256 "$contract")" "$patch" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
for file in "${paths[@]}";do install -Dm644 "$kernel/$file" "$work/$file";done
git -C "$work" init -q
git -C "$work" apply --reverse --check --whitespace=error "$patch"
git -C "$work" apply --reverse --whitespace=error "$patch"
# The original ledger and every non-VRR byte remain unchanged. The actual
# production source and linked object stay on the independently checked new side.
(cd "$work";sha256sum -c --strict --quiet "$ledger")
printf 'Original five-file MST source ledger passed through the exact native VRR inverse; production source unchanged.\n'

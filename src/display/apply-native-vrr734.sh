#!/usr/bin/bash
# Late source layer after the complete full28 display controls.
set -Eeuo pipefail
[[ $# == 1 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1"); profile=$kernel/native-profile
contract=$profile/manifests/native-vrr734-20261115.json
path=drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c
patch=$profile/src/display/0076-uke-native-vrr734.patch
sha256sum "$kernel/$path" "$patch"
printf '%s  %s\n' "$(jq -er .before_encoder_sha256 "$contract")" "$kernel/$path" \
 "$(jq -er .patch_sha256 "$contract")" "$patch" | sha256sum -c --strict --quiet -
git -C "$kernel" apply --check --whitespace=error "$patch"
git -C "$kernel" apply --whitespace=error "$patch"
printf '%s  %s\n' "$(jq -er .after_encoder_sha256 "$contract")" "$kernel/$path" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
install -Dm644 "$kernel/$path" "$work/$path"
git -C "$work" init -q
git -C "$work" apply --reverse --whitespace=error "$patch"
printf '%s  %s\n' "$(jq -er .before_encoder_sha256 "$contract")" "$work/$path" | sha256sum -c --strict --quiet -
printf '%s\n' "$(jq -er .after_encoder_sha256 "$contract")" > "$kernel/native-generated/native-vrr734-applied"
for cc in gcc clang;do for san in 0 1;do
 CC=$cc SANITIZE=$san bash "$profile/tests/native-vrr734.sh" "$kernel"
 CC=$cc SANITIZE=$san bash "$profile/tests/o82-vrr-api.sh" "$kernel"
 CC=$cc bash "$profile/tests/o82-vrr-capability-contract.sh" "$kernel"
done;done
printf 'Native Uke VRR default staged with exact receiver/DT/DSC/atomic admission and explicit disabled/saved policy retained; original KDE/backlight unchanged.\n'

#!/usr/bin/bash
# Data-only regression fixture using the actual qualified DPU source and ledger.
set -Eeuo pipefail
[[ $# == 1 ]]
kernel=$(realpath "$1")
checker=$kernel/native-profile/tests/vrr734-historical-source-check.sh
ledger=$kernel/native-generated/mst-power-delivery733/applied.sha256
bash "$checker" "$kernel" "$ledger"
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
paths=(drivers/soc/qcom/uke-platform-profile.c drivers/gpu/drm/msm/dp/dp_mst_drm.c drivers/gpu/drm/msm/dp/dp_display.c drivers/gpu/drm/msm/msm_drv.h drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c)
mkdir -p "$work/tree/native-profile/"{tests,manifests,src/display} "$work/tree/native-generated/mst-power-delivery733"
for file in "${paths[@]}";do install -Dm644 "$kernel/$file" "$work/tree/$file";done
cp "$kernel/native-profile/manifests/native-vrr734-20261115.json" "$work/tree/native-profile/manifests/"
cp "$kernel/native-profile/src/display/0076-uke-native-vrr734.patch" "$work/tree/native-profile/src/display/"
cp "$kernel/native-generated/native-vrr734-applied" "$work/tree/native-generated/"
cp "$ledger" "$work/tree/native-generated/mst-power-delivery733/"
fixture=$work/tree
record=$fixture/native-generated/mst-power-delivery733/applied.sha256
refuse() {
 if bash "$checker" "$fixture" "$record" > "$work/refusal.log" 2>&1;then
  printf 'Unexpected historical source acceptance: %s\n' "$1" >&2;exit 1
 fi
 printf 'Historical VRR/MST source refusal passed:%s.\n' "$1"
}
for file in "${paths[@]}";do
 cp "$fixture/$file" "$work/before"
 printf '\n' >> "$fixture/$file"
 refuse "$file-unrelated-byte"
 cp "$work/before" "$fixture/$file"
done
cp "$record" "$work/ledger"
cat "$work/ledger" >> "$record";refuse duplicate-ledger;cp "$work/ledger" "$record"
sed -i '5s/^[a-f0-9]*/0000000000000000000000000000000000000000000000000000000000000000/' "$record"
refuse changed-before-identity;cp "$work/ledger" "$record"
printf 'invalid\n' > "$fixture/native-generated/native-vrr734-applied"
refuse missing-production-receipt
cp "$kernel/native-generated/native-vrr734-applied" "$fixture/native-generated/"
printf '\n' >> "$fixture/native-profile/src/display/0076-uke-native-vrr734.patch"
refuse changed-inverse-patch
cp "$kernel/native-profile/src/display/0076-uke-native-vrr734.patch" "$fixture/native-profile/src/display/"
bash "$checker" "$fixture" "$record"
printf 'Actual VRR postimage, exact original five-file ledger and nine independent alteration refusals passed; no Image or hardware qualification.\n'

#!/usr/bin/bash
# Exact full9 text fixture; no compilation, firmware or device operation.
set -Eeuo pipefail
[[ $# == 2 ]]
profile=$(realpath "${1:?Source profile}")
original=$(realpath "${2:?Actual full9 spec}")
printf '%s  %s\n' 1de02bab494d752213e714d09ea2507353b731ce4cc719b1a6c5f1dab976155f "$original" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
rewrite=$profile/packaging/native/rewrite-proximity-full-spec733.sh
cp "$original" "$work/positive.spec"
bash "$rewrite" "$work/positive.spec"
awk '
 $0=="Requires: uke-control(critical-crash-count-v1) >= 1"{next}
 $0=="# UKE_PROXIMITY_CRASH_HISTORY_DELIVERY"{next}
 /^bash native-profile\/src\/sensors\/apply-proximity-input733.sh /{next}
 /^bash native-profile\/src\/health\/apply-rproc-count733.sh /{next}
 /^bash native-profile\/packaging\/native\/check-(proximity-input|rproc-count)733.sh /{next}
 {print}
' "$work/positive.spec" | cmp - "$original"
for variant in missing-source missing-linked missing-image missing-control duplicate-source duplicate-image duplicate-build stable-family source-after-image already-rewritten; do
 case $variant in
  missing-source) sed '/^bash native-profile\/packaging\/native\/check-speaker-quad733.sh .* source$/d' "$original" > "$work/input.spec";;
  missing-linked) sed '/^bash native-profile\/packaging\/native\/check-speaker-quad733.sh .* linked$/d' "$original" > "$work/input.spec";;
  missing-image) sed '/^bash boot-recipe\/src\/boot\/build-payload.sh /d' "$original" > "$work/input.spec";;
  missing-control) sed '/^Requires: uke-control(critical-rollback-v1) >= 1$/d' "$original" > "$work/input.spec";;
  duplicate-source) sed '/^bash native-profile\/packaging\/native\/check-speaker-quad733.sh .* source$/p' "$original" > "$work/input.spec";;
  duplicate-image) sed '/^bash boot-recipe\/src\/boot\/build-payload.sh /p' "$original" > "$work/input.spec";;
  duplicate-build) sed '/^%build$/p' "$original" > "$work/input.spec";;
  stable-family) sed 's/^Name: senemos-uke-linux-kernel-mainline-unstable$/Name: senemos-uke-linux-kernel-mainline/' "$original" > "$work/input.spec";;
  source-after-image) awk '/^bash native-profile\/packaging\/native\/check-speaker-quad733.sh .* source$/{saved=$0;next}{print}/^bash boot-recipe\/src\/boot\/build-payload.sh /{print saved}' "$original" > "$work/input.spec";;
  already-rewritten) cp "$work/positive.spec" "$work/input.spec";;
 esac
 cp "$work/input.spec" "$work/before.spec"
 result=0
 bash "$rewrite" "$work/input.spec" > "$work/refusal.log" 2>&1 || result=$?
 [[ $result != 0 ]]
 cmp "$work/input.spec" "$work/before.spec"
 printf 'Proximity/crash-history full-spec refusal passed:%s; input unchanged.\n' "$variant"
done
printf 'Actual full9 whole-text inverse and ten order/dependency/identity refusals passed; no native or physical acceptance.\n'

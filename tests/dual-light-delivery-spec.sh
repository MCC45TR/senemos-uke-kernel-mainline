#!/usr/bin/bash
# Pure text fixture: no compiler, package transaction, firmware or device access.
set -Eeuo pipefail
[[ $# == 2 ]]
profile=$(realpath "${1:?Profile}")
original=$(realpath "${2:?Pinned actual full spec}")
printf '%s  %s\n' 62812a75886d65fb24d7a33fcecbc717d5616fbd733fa6cbe99a03db107547c9 "$original" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
rewrite=$profile/packaging/native/rewrite-dual-light-full-spec733.sh
cp "$original" "$work/positive.spec"
bash "$rewrite" "$work/positive.spec"
# Reversing only this integration must restore every byte of the actual input.
awk '
 /^bash native-profile\/packaging\/native\/check-dual-light-(delivery|binding)733.sh / {next}
 /^bash native-profile\/packaging\/native\/check-dual-light-events733.sh / {next}
 /^bash native-profile\/packaging\/native\/check-ssc-stream-owners733.sh / {next}
 /^bash native-profile\/packaging\/native\/check-dual-light-endpoint733.sh / {next}
 /^bash native-profile\/src\/sensors\/apply-dual-light733.sh / {next}
 /^dual_light_legacy=/ {next}
 $0=="cmp native-profile/src/sensors/uke-ssc-iio.c \"$dual_light_legacy/drivers/iio/common/uke-ssc/uke-ssc-iio.c\"" {
   print "cmp native-profile/src/sensors/uke-ssc-iio.c drivers/iio/common/uke-ssc/uke-ssc-iio.c";next
 }
 {print}
' "$work/positive.spec" | cmp - "$original"
for variant in missing-prepared missing-image missing-retained-cmp duplicate-build duplicate-check stable-family prepared-after-image already-rewritten; do
  case $variant in
    missing-prepared) sed '/^bash native-profile\/packaging\/native\/check-hall-initial733.sh .* prepared$/d' "$original" > "$work/input.spec";;
    missing-image) sed '/^bash boot-recipe\/src\/boot\/build-payload.sh /d' "$original" > "$work/input.spec";;
    missing-retained-cmp) awk '$0=="cmp native-profile/src/sensors/uke-ssc-iio.c drivers/iio/common/uke-ssc/uke-ssc-iio.c"&&!removed++{next}{print}' "$original" > "$work/input.spec";;
    duplicate-build) sed '/^%build$/p' "$original" > "$work/input.spec";;
    duplicate-check) sed '/^%check$/p' "$original" > "$work/input.spec";;
    stable-family) sed 's/^Name: senemos-uke-linux-kernel-mainline-unstable$/Name: senemos-uke-linux-kernel-mainline/' "$original" > "$work/input.spec";;
    prepared-after-image) awk '/^bash native-profile\/packaging\/native\/check-hall-initial733.sh .* prepared$/{saved=$0;next}{print}/^bash boot-recipe\/src\/boot\/build-payload.sh /{print saved}' "$original" > "$work/input.spec";;
    already-rewritten) cp "$work/positive.spec" "$work/input.spec";;
  esac
  cp "$work/input.spec" "$work/before.spec"
  result=0
  bash "$rewrite" "$work/input.spec" > "$work/refusal.log" 2>&1 || result=$?
  [[ $result != 0 ]]
  cmp "$work/input.spec" "$work/before.spec"
  printf 'Dual-light full-spec refusal passed:%s; rejected input unchanged.\n' "$variant"
done
printf 'Actual pinned full5 spec, whole-text inverse and eight order/identity/re-entry refusals passed; no full generator or physical acceptance.\n'

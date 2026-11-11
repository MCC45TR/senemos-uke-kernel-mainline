#!/usr/bin/bash
# COPR-only production preparation/inverse tests on four isolated source files.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 1 ]]
kernel=$(realpath "${1:?Prepared kernel}")
profile=$kernel/native-profile
fixture=$kernel/native-generated/dual-light-delivery-fixture
[[ ! -e $fixture ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
paths=(drivers/iio/common/uke-ssc/uke-ssc-iio.c arch/arm64/kernel/uke-abl-native.h
 Documentation/devicetree/bindings/firmware/xiaomi,uke-ssc-sensors.yaml
 drivers/iio/common/uke-ssc/Kconfig)
mkdir -p "$fixture"
ln -s "$profile" "$fixture/native-profile"
for file in "${paths[@]}"; do
  install -Dm644 "$kernel/$file" "$fixture/$file"
  sha256sum "$kernel/$file" >> "$work/actual-before.sha256"
done
view=$profile/packaging/native/dual-light-legacy-view733.sh
[[ $(bash "$view" "$fixture") == "$fixture" ]]
bash "$profile/src/sensors/apply-dual-light733.sh" "$fixture"
legacy=$(bash "$view" "$fixture")
[[ $legacy == "$fixture/native-generated/dual-light-legacy-view" ]]
for file in "${paths[@]}"; do cmp "$legacy/$file" "$kernel/$file"; done
for file in "${paths[@]}"; do sha256sum "$fixture/$file" >> "$work/post-before.sha256"; done
result=0
bash "$profile/src/sensors/apply-dual-light733.sh" "$fixture" > "$work/reentry.log" 2>&1 || result=$?
[[ $result != 0 ]]
sha256sum -c --strict --quiet "$work/post-before.sha256"
printf 'Dual-light production application re-entry refused; postimages unchanged.\n'
for variant in driver native-header binding kconfig forged-history reducer-header; do
  copy=$work/$variant
  cp -a "$fixture" "$copy"
  case $variant in
    driver) printf '\n/* unreviewed independent source change */\n' >> "$copy/${paths[0]}";;
    native-header) printf '\n/* unreviewed independent source change */\n' >> "$copy/${paths[1]}";;
    binding) printf '\n# unreviewed independent property\n' >> "$copy/${paths[2]}";;
    kconfig) printf '\n# unreviewed independent dependency\n' >> "$copy/${paths[3]}";;
    forged-history)
      history=$copy/native-generated/before-dual-light
      printf '\n/* altered history */\n' >> "$history/${paths[0]}"
      (cd "$history";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS);;
    reducer-header) printf '\n/* altered payload */\n' >> "$copy/arch/arm64/kernel/uke-dual-light.h";;
  esac
  result=0
  bash "$view" "$copy" > "$work/$variant.log" 2>&1 || result=$?
  [[ $result != 0 ]]
  printf 'Dual-light inverse view refuses unrelated source/history alteration:%s.\n' "$variant"
done
sha256sum -c --strict --quiet "$work/actual-before.sha256"
printf 'Actual production dual-light helper, four-file inverse, re-entry and six independent alteration refusals passed; real kernel source untouched.\n'

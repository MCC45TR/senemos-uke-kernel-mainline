#!/usr/bin/bash
# Native-COPR source-only checks; never alter the actual compiled source.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 1 ]]
kernel=$(realpath "${1:?Prepared cumulative kernel}")
profile=$kernel/native-profile
driver=drivers/iio/common/uke-ssc/uke-ssc-iio.c
view=$profile/packaging/native/proximity-legacy-view733.sh
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
sha256sum "$kernel/$driver" > "$work/actual.sha256"
legacy=$(bash "$view" "$kernel")
printf '%s  %s\n' "$(jq -er .driver_before_sha256 "$profile/manifests/ssc-proximity-input-20261109.json")" "$legacy/$driver" | sha256sum -c --strict --quiet -
mkdir -p "$work/before"
ln -s "$profile" "$work/before/native-profile"
install -Dm644 "$legacy/$driver" "$work/before/$driver"
[[ $(bash "$view" "$work/before") == "$work/before" ]]
# The real %prep creates a Git repository. Exercise the source adapter inside
# that context as well as the ordinary temporary-directory fixtures.
nested=$work/nested
mkdir -p "$nested/native-generated"
ln -s "$profile" "$nested/native-profile"
install -Dm644 "$kernel/$driver" "$nested/$driver"
git -C "$nested" -c init.defaultBranch=senemos init -q
normalized=$(bash "$view" "$nested")
cmp "$normalized/$driver" "$legacy/$driver"
cmp "$nested/$driver" "$kernel/$driver"
printf 'Proximity inverse preserves actual source inside a prepared Git repository.\n'
for variant in altered-postimage altered-preimage wrong-inverse; do
 copy=$work/$variant
 mkdir -p "$copy/native-profile/manifests" "$copy/native-profile/src/sensors" "$copy/native-generated"
 install -Dm644 "$profile/manifests/ssc-proximity-input-20261109.json" "$copy/native-profile/manifests/ssc-proximity-input-20261109.json"
 install -Dm644 "$profile/src/sensors/0010-ssc-proximity-input.patch" "$copy/native-profile/src/sensors/0010-ssc-proximity-input.patch"
 source=$kernel
 [[ $variant != altered-preimage ]] || source=$legacy
 install -Dm644 "$source/$driver" "$copy/$driver"
 if [[ $variant == wrong-inverse ]]; then
  sed -i 's/ssc_proximity_register/ssc_unreviewed_register/g' "$copy/native-profile/src/sensors/0010-ssc-proximity-input.patch"
 else
  printf '\n/* unreviewed independent change */\n' >> "$copy/$driver"
 fi
 sha256sum "$copy/$driver" > "$work/$variant.sha256"
 result=0
 bash "$view" "$copy" > "$work/$variant.log" 2>&1 || result=$?
 [[ $result != 0 ]]
 sha256sum -c --strict --quiet "$work/$variant.sha256"
 printf 'Proximity legacy view refuses:%s; actual input unchanged.\n' "$variant"
done
sha256sum -c --strict --quiet "$work/actual.sha256"
printf 'Actual proximity pre/post inverse and three source alteration refusals pass without changing production source.\n'

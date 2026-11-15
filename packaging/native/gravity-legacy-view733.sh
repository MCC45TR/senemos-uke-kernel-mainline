#!/usr/bin/bash
# Data-only authenticated parent projection. Actual objects always stay new.
set -Eeuo pipefail
[[ $# == 1 ]]
kernel=$(realpath "$1")
profile=$kernel/native-profile
work=$kernel/native-generated/ssc-gravity733
[[ -s $work/applied.sha256 ]]
(cd "$kernel";sha256sum -c --strict --quiet "$work/applied.sha256")
inverse=$(mktemp -d)
trap 'find "$inverse" -depth -delete' EXIT
for file in drivers/iio/common/uke-ssc/uke-ssc-iio.c arch/arm64/kernel/uke-hardware.h Documentation/devicetree/bindings/firmware/xiaomi,uke-ssc-sensors.yaml Documentation/ABI/testing/sysfs-driver-uke-ssc;do
 install -Dm644 "$kernel/$file" "$inverse/$file"
done
git -C "$inverse" init -q
for patch in 0013-ssc-gravity-observation-abi.patch 0012-ssc-gravity-native-dt.patch 0011-ssc-gravity-linear-input.patch;do
 git -C "$inverse" apply -R --check --whitespace=error "$profile/src/sensors/$patch"
 git -C "$inverse" apply -R --whitespace=error "$profile/src/sensors/$patch"
done
for file in drivers/iio/common/uke-ssc/uke-ssc-iio.c arch/arm64/kernel/uke-hardware.h Documentation/devicetree/bindings/firmware/xiaomi,uke-ssc-sensors.yaml Documentation/ABI/testing/sysfs-driver-uke-ssc;do
 cmp "$work/before/$file" "$inverse/$file"
done
printf '%s  %s\n' "$(jq -er .driver_before_sha256 "$profile/manifests/ssc-gravity-20261110.json")" "$inverse/drivers/iio/common/uke-ssc/uke-ssc-iio.c" | sha256sum -c --strict --quiet -
view=$(mktemp -d "$kernel/native-generated/gravity-parent-view.XXXXXX")
project(){
 local relative=$1 source target entry name child path descend
 source=$kernel/$relative
 target=$view/$relative
 mkdir -p "$target"
 for entry in "$source"/* "$source"/.[!.]* "$source"/..?*;do
  [[ -e $entry || -L $entry ]] || continue
  name=$(basename "$entry")
  [[ $name != .git ]] || continue
  child=$relative/$name
  child=$(printf '%s' "$child" | sed 's,^/,,')
  if [[ -f $inverse/$child ]];then
   install -m644 "$inverse/$child" "$view/$child"
   continue
  fi
  descend=false
  for path in drivers/iio/common/uke-ssc/uke-ssc-iio.c arch/arm64/kernel/uke-hardware.h Documentation/devicetree/bindings/firmware/xiaomi,uke-ssc-sensors.yaml Documentation/ABI/testing/sysfs-driver-uke-ssc;do
   [[ $path != "$child/"* ]] || descend=true
  done
  if $descend;then project "$child";else ln -s "$entry" "$view/$child";fi
 done
}
project ''
for file in drivers/iio/common/uke-ssc/uke-ssc-iio.c arch/arm64/kernel/uke-hardware.h Documentation/devicetree/bindings/firmware/xiaomi,uke-ssc-sensors.yaml Documentation/ABI/testing/sysfs-driver-uke-ssc;do
 cmp "$inverse/$file" "$view/$file"
done
git -C "$view" init -q
(cd "$kernel";sha256sum -c --strict --quiet "$work/applied.sha256")
printf '%s\n' "$view"

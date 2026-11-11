#!/usr/bin/bash
# Source-only views; the full build and linked gates always use new objects.
set -Eeuo pipefail
[[ $# == 1 ]]
kernel=$(realpath "$1")
profile=$kernel/native-profile
parent=$(bash "$profile/packaging/native/quaternion-legacy-view733.sh" "$kernel")
prior=$(bash "$profile/packaging/native/gravity-legacy-view733.sh" "$parent")
for file in drivers/iio/common/uke-ssc/uke-ssc-iio.c arch/arm64/kernel/uke-hardware.h Documentation/devicetree/bindings/firmware/xiaomi,uke-ssc-sensors.yaml Documentation/ABI/testing/sysfs-driver-uke-ssc;do
 cmp "$kernel/native-generated/ssc-quaternion733/before/$file" "$parent/$file"
 cmp "$kernel/native-generated/ssc-gravity733/before/$file" "$prior/$file"
done
(cd "$kernel";sha256sum -c --strict --quiet native-generated/ssc-quaternion733/applied.sha256)
printf 'Quaternion parent projection: four exact full14 and full13 source preimages pass; actual source unchanged and compiled output is not substituted.\n'

#!/usr/bin/bash
# Authenticate old text comparisons without substituting old compiled objects.
set -Eeuo pipefail
[[ $# == 2 ]]
kernel=$(realpath "$1")
out=$(realpath -m "$2")
profile=$kernel/native-profile
before=$kernel/native-generated/ssc-gravity733/before
parent=$(bash "$profile/packaging/native/gravity-legacy-view733.sh" "$kernel")
for file in drivers/iio/common/uke-ssc/uke-ssc-iio.c arch/arm64/kernel/uke-hardware.h Documentation/devicetree/bindings/firmware/xiaomi,uke-ssc-sensors.yaml Documentation/ABI/testing/sysfs-driver-uke-ssc;do
 cmp "$before/$file" "$parent/$file"
done
legacy=$(bash "$profile/packaging/native/dual-light-legacy-view733.sh" "$parent")
cmp "$profile/src/sensors/uke-ssc-iio.c" "$legacy/drivers/iio/common/uke-ssc/uke-ssc-iio.c"
cmp "$profile/src/sensors/sysfs-driver-uke-ssc" "$parent/Documentation/ABI/testing/sysfs-driver-uke-ssc"
bash "$profile/packaging/native/check-proximity-input733.sh" "$parent" "$out" source
bash "$profile/packaging/native/check-dual-light-delivery733.sh" "$parent" "$out" source
(cd "$kernel";sha256sum -c --strict --quiet native-generated/ssc-gravity733/applied.sha256)
printf 'Gravity parent projection: all four preimages, retained full legacy SSC comparisons/proximity/dual-light checks and unchanged actual source pass; compiled output is not substituted.\n'

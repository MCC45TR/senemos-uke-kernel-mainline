#!/usr/bin/bash
# COPR only, after the exact admitted full13 source preparation.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
profile=$kernel/native-profile
work=$kernel/native-generated/ssc-gravity733
files=(drivers/iio/common/uke-ssc/uke-ssc-iio.c arch/arm64/kernel/uke-abl-native.h Documentation/devicetree/bindings/firmware/xiaomi,uke-ssc-sensors.yaml)
[[ ! -e $work ]]
printf '%s  %s\n' 3ee32c5c3a0e704d0f9864546393855093e245940c8fd20d7371663962307e15 "$kernel/${files[0]}" | sha256sum -c --strict --quiet -
mkdir -p "$work/before" "$work/inverse"
for file in "${files[@]}";do install -Dm644 "$kernel/$file" "$work/before/$file";done
for patch in src/sensors/0011-ssc-gravity-linear-input.patch src/sensors/0012-ssc-gravity-native-dt.patch;do
 git -C "$kernel" apply --check --whitespace=error "$profile/$patch"
 git -C "$kernel" apply --whitespace=error "$profile/$patch"
done
printf '%s  %s\n' 0fc9eafc99332bd80b792f145f3c2ce2c6a80bdbdd34cb0de36ab5d305b0a9b5 "$kernel/${files[0]}" | sha256sum -c --strict --quiet -
for file in "${files[@]}";do install -Dm644 "$kernel/$file" "$work/inverse/$file";done
git -C "$work/inverse" init -q
for patch in src/sensors/0012-ssc-gravity-native-dt.patch src/sensors/0011-ssc-gravity-linear-input.patch;do git -C "$work/inverse" apply -R --whitespace=error "$profile/$patch";done
for file in "${files[@]}";do cmp "$work/before/$file" "$work/inverse/$file";done
(cd "$kernel";sha256sum "${files[@]}") > "$work/applied.sha256"
printf 'Native gravity/linear source: all three full-unit inverses pass; no sensor request, private data or hardware acceptance.\n'

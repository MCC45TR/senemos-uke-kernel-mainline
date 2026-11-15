#!/usr/bin/bash
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 2 ]]
kernel=$(realpath "$1");out=$(realpath -m "$2")
profile=$kernel/native-profile
work=$kernel/native-generated/ssc-proximity-abi733
mkdir "$work"
path=drivers/iio/common/uke-ssc/uke-ssc-iio.c
printf '%s  %s\n' 0ce13ce84852f73f7c8bc473a49e52b5ac675f4d3189d5a3160791acabebfa2d "$kernel/$path" | sha256sum -c --strict --quiet -
cp "$kernel/$path" "$work/before.c"
git -C "$kernel" apply --check --whitespace=error "$profile/src/sensors/0018-ssc-proximity-input-abi.patch"
git -C "$kernel" apply --whitespace=error "$profile/src/sensors/0018-ssc-proximity-input-abi.patch"
printf '%s  %s\n' f7c689e893e8696dcf093cf859dbb07dfc6b31b5332ce4108a19be13252efca1 "$kernel/$path" | sha256sum -c --strict --quiet -
mkdir -p "$work/inverse/$(dirname "$path")"
cp "$kernel/$path" "$work/inverse/$path"
abi=Documentation/ABI/testing/sysfs-driver-uke-ssc-proximity-input
install -Dm644 "$kernel/$abi" "$work/inverse/$abi"
git -C "$work/inverse" init -q
git -C "$work/inverse" apply -R --whitespace=error "$profile/src/sensors/0018-ssc-proximity-input-abi.patch"
cmp "$work/before.c" "$work/inverse/$path"
[[ ! -e $work/inverse/$abi ]]
bash "$profile/tests/ssc-proximity-abi.sh" "$kernel"
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-17-unstable KCFLAGS=-Werror W=1 -j4 drivers/iio/common/uke-ssc/uke-ssc.o
llvm-readelf -h "$out/drivers/iio/common/uke-ssc/uke-ssc.o" | grep -F AArch64
llvm-nm "$out/drivers/iio/common/uke-ssc/uke-ssc.o" > "$work/symbols"
for symbol in ssc_proximity_input_abi_show dev_attr_ssc_proximity_input_abi ssc_proximity_open ssc_heading_read_raw ssc_read_raw_multi;do
 grep -Eq "[[:space:]][a-zA-Z][[:space:]]+$symbol\$" "$work/symbols"
done
(cd "$kernel";sha256sum "$path" "$abi") > "$work/applied.sha256"
printf 'Actual proximity ABI native: full17 inverse,62 callback cases in four modes,four regressions and fresh ARM64 SSC; no stream/calibration/physical acceptance.\n'

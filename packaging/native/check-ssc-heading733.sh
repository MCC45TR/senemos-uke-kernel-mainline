#!/usr/bin/bash
# Native proof only: actual patch, math/lifecycle callbacks and fresh ARM64 object.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Full16 prepared source}")
out=$(realpath -m "${2:?Native output}")
profile=$kernel/native-profile
contract=$profile/manifests/ssc-heading-20261110.json
work=$kernel/native-generated/ssc-heading733
file=drivers/iio/common/uke-ssc/uke-ssc-iio.c
[[ ! -e $work ]]
mkdir -p "$work/inverse/drivers/iio/common/uke-ssc"
cp "$kernel/$file" "$work/before.c"
printf '%s  %s\n' "$(jq -er '.source_units[0].before_sha256' "$contract")" "$kernel/$file" | sha256sum -c --strict --quiet -
git -C "$kernel" apply --check --whitespace=error "$profile/src/sensors/0017-ssc-magnetic-heading.patch"
git -C "$kernel" apply --whitespace=error "$profile/src/sensors/0017-ssc-magnetic-heading.patch"
printf '%s  %s\n' "$(jq -er '.source_units[0].after_sha256' "$contract")" "$kernel/$file" | sha256sum -c --strict --quiet -
for name in uke-ssc-heading.h uke-ssc-heading-input.h;do install -m644 "$profile/src/sensors/$name" "$kernel/drivers/iio/common/uke-ssc/$name";done
cp "$kernel/$file" "$work/inverse/$file"
git -C "$work/inverse" init -q
git -C "$work/inverse" apply -R --whitespace=error "$profile/src/sensors/0017-ssc-magnetic-heading.patch"
cmp "$work/before.c" "$work/inverse/$file"
bash "$profile/tests/ssc-heading-math.sh"
bash "$profile/tests/ssc-heading-callbacks.sh" "$kernel"
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-16-unstable KCFLAGS=-Werror W=1 -j4 drivers/iio/common/uke-ssc/uke-ssc.o
llvm-readelf -h "$out/drivers/iio/common/uke-ssc/uke-ssc.o" | grep -F AArch64
llvm-nm "$out/drivers/iio/common/uke-ssc/uke-ssc.o" > "$work/symbols"
for symbol in ssc_heading_read_raw ssc_heading_buffer_enable ssc_heading_buffer_disable;do grep -Eq "[[:space:]][tT][[:space:]]+$symbol\$" "$work/symbols";done
for symbol in input_event input_register_device;do grep -Eq "[[:space:]]U[[:space:]]+$symbol\$" "$work/symbols";done
if grep -Eq '[[:space:]]U[[:space:]]+(atan2|sqrt|sin|cos|__.*(df|sf)3)$' "$work/symbols";then echo 'Unexpected floating-point dependency' >&2;exit 1;fi
(cd "$kernel";sha256sum "$file" drivers/iio/common/uke-ssc/uke-ssc-heading{,-input}.h) > "$work/applied.sha256"
printf 'Actual heading native: full16 inverse,integer projection,lifecycle shared owners and fresh ARM64 SSC pass; original raw ABI unchanged,no physical heading acceptance.\n'

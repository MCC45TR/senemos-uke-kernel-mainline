#!/usr/bin/bash
# COPR source-only repeat-four sizing and fresh ARM64 SSC object acceptance.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared full15 kernel}")
out=$(realpath -m "${2:?Native output}")
profile=$kernel/native-profile
contract=$profile/manifests/ssc-quaternion-buffer-20261110.json
work=$kernel/native-generated/ssc-quaternion-buffer733
file=drivers/iio/common/uke-ssc/uke-ssc-iio.c
[[ ! -e $work ]]
mkdir -p "$work/inverse/drivers/iio/common/uke-ssc"
cp "$kernel/$file" "$work/before.c"
before=$(jq -er '.source_units[0].before_sha256' "$contract")
after=$(jq -er '.source_units[0].after_sha256' "$contract")
printf '%s  %s\n' "$before" "$kernel/$file" | sha256sum -c --strict --quiet -
git -C "$kernel" apply --check --whitespace=error "$profile/src/sensors/0016-ssc-quaternion-scan-alignment.patch"
git -C "$kernel" apply --whitespace=error "$profile/src/sensors/0016-ssc-quaternion-scan-alignment.patch"
printf '%s  %s\n' "$after" "$kernel/$file" | sha256sum -c --strict --quiet -
cp "$kernel/$file" "$work/inverse/$file"
git -C "$work/inverse" init -q
git -C "$work/inverse" apply -R --whitespace=error "$profile/src/sensors/0016-ssc-quaternion-scan-alignment.patch"
cmp "$work/before.c" "$work/inverse/$file"
bash "$profile/tests/ssc-quaternion-buffer.sh" "$kernel"
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-15-unstable KCFLAGS=-Werror W=1 -j4 drivers/iio/common/uke-ssc/uke-ssc.o
llvm-readelf -h "$out/drivers/iio/common/uke-ssc/uke-ssc.o" | grep -F AArch64
llvm-nm "$out/drivers/iio/common/uke-ssc/uke-ssc.o" > "$work/symbols"
grep -Eq '[[:space:]][tT][[:space:]]+ssc_read_raw_multi$' "$work/symbols"
for symbol in input_register_device input_event;do grep -Eq "[[:space:]]U[[:space:]]+$symbol\$" "$work/symbols";done
(cd "$kernel";sha256sum "$file") > "$work/applied.sha256"
printf 'Actual quaternion scan alignment: full15 driver inverse, real IIO64-byte sizing, padding, legacy layouts,8 regressions and fresh AArch64 SSC pass; no device acceptance.\n'

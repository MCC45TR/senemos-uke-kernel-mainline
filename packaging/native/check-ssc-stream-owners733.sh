#!/usr/bin/bash
# COPR-only actual callback/native object admission. No new endpoint or hardware test.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
out=$(realpath -m "${2:?Native output}")
phase=${3:?prepared or objects}
[[ $phase == prepared || $phase == objects ]]
profile=$kernel/native-profile
manifest=$profile/manifests/ssc-stream-owners-20261108.json
driver=drivers/iio/common/uke-ssc/uke-ssc-iio.c
delta=$profile/src/sensors/0004-ssc-shared-stream-owners.patch
before=$(jq -er .driver_before_sha256 "$manifest")
after=$(jq -er .driver_after_sha256 "$manifest")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
printf '%s  %s\n' "$before" "$kernel/$driver" | sha256sum -c --strict --quiet -
mkdir -p "$work/view/${driver%/*}"
install -m644 "$kernel/$driver" "$work/view/$driver"
git -C "$work/view" apply --check --whitespace=error "$delta"
git -C "$work/view" apply --whitespace=error "$delta"
printf '%s  %s\n' "$after" "$work/view/$driver" | sha256sum -c --strict --quiet -
git -C "$work/view" apply -R --check --whitespace=error "$delta"
cp "$work/view/$driver" "$work/post.c"
git -C "$work/view" apply -R --whitespace=error "$delta"
cmp "$work/view/$driver" "$kernel/$driver"
if [[ $phase == prepared ]]; then
 for cc in gcc clang; do
  for sanitize in 0 1; do
   CC=$cc SANITIZE=$sanitize bash "$profile/tests/ssc-stream-owners.sh" "$work/post.c"
  done
 done
 # Run every original QMI/metadata/ACK assertion against the actual postimage.
 # Only its extractor learns the new read-only demand helper. Test C is exact.
 mkdir -p "$work/legacy/tests" "$work/legacy/src/sensors"
 for path in tests/ssc-native-host.h tests/ssc-native-contract.c src/sensors/uke-ssc-protocol.c src/sensors/uke-ssc-protocol.h; do
  install -m644 "$profile/$path" "$work/legacy/$path"
 done
 install -m644 "$work/post.c" "$work/legacy/src/sensors/uke-ssc-iio.c"
 awk '
  {if(sub(/ssc_start ssc_stop ssc_close_client;/,"ssc_start ssc_stop ssc_stream_wanted ssc_close_client;"))n++;print}
  END{if(n!=1)exit 1}
 ' "$profile/tests/ssc-native-contract.sh" > "$work/legacy/tests/ssc-native-contract.sh"
 awk '
  {if(sub(/ssc_start ssc_stop ssc_stream_wanted ssc_close_client;/,"ssc_start ssc_stop ssc_close_client;"))n++;print}
  END{if(n!=1)exit 1}
 ' "$work/legacy/tests/ssc-native-contract.sh" | cmp - "$profile/tests/ssc-native-contract.sh"
 cmp "$work/legacy/tests/ssc-native-contract.c" "$profile/tests/ssc-native-contract.c"
 bash "$work/legacy/tests/ssc-native-contract.sh" "$kernel"
 # Reconciliation consumes all live owners while the existing raw-buffer
 # fault latch only suppresses that buffer, never unrelated consumer demand.
 [[ $(grep -Fc 'buffered = ssc_stream_wanted(s) != 0;' "$work/post.c") == 1 ]]
 printf 'Actual shared SSC owners: four provider modes, ten behavioral mutants, unchanged original QMI assertions and whole-driver inverse passed; combined endpoint remains absent.\n'
 exit 0
fi
[[ ! -e $kernel/native-generated/ssc-before-stream-owners.c ]]
install -m644 "$kernel/$driver" "$kernel/native-generated/ssc-before-stream-owners.c"
git -C "$kernel" apply --check --whitespace=error "$delta"
git -C "$kernel" apply --whitespace=error "$delta"
printf '%s  %s\n' "$after" "$kernel/$driver" | sha256sum -c --strict --quiet -
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCFLAGS=-Werror W=1 \
 drivers/iio/common/uke-ssc/uke-ssc.o
object=$out/drivers/iio/common/uke-ssc/uke-ssc-iio.o
test -s "$object"
if llvm-readelf -h "$object" > "$work/architecture" 2>/dev/null; then
 grep -E 'Machine:.*AArch64' "$work/architecture"
else
 llvm-dis "$object" -o "$work/object.ll"
 grep -E '^target triple = "aarch64[^\"]*"$' "$work/object.ll"
fi
test -s "$out/drivers/iio/common/uke-ssc/uke-ssc.o"
printf 'Actual AArch64 SSC shared-owner driver and composite compiled; wire/protocol, Hall/DT/config retained. No combined IIO/Hall endpoint or physical acceptance.\n'

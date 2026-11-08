#!/usr/bin/bash
# COPR-only actual endpoint callbacks and cumulative ARM64 objects. No target action.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
out=$(realpath -m "${2:?Native output}")
phase=${3:?prepared or objects}
[[ $phase == prepared || $phase == objects ]]
profile=$kernel/native-profile
manifest=$profile/manifests/dual-light-endpoint-20261108.json
driver=drivers/iio/common/uke-ssc/uke-ssc-iio.c
delta=$profile/src/sensors/0005-ssc-dual-light-endpoint.patch
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
before=$(jq -er .driver_before_sha256 "$manifest")
after=$(jq -er .driver_after_sha256 "$manifest")
mkdir -p "$work/view/${driver%/*}"
install -m644 "$kernel/$driver" "$work/view/$driver"
if [[ $phase == prepared ]]; then
 printf '%s  %s\n' c7a271fb57d329cdbc31f0d8876af4c4ef95ee16e880137e7fd003a8f45630fd "$kernel/$driver" | sha256sum -c --strict --quiet -
 git -C "$work/view" apply --check --whitespace=error "$profile/src/sensors/0004-ssc-shared-stream-owners.patch"
 git -C "$work/view" apply --whitespace=error "$profile/src/sensors/0004-ssc-shared-stream-owners.patch"
fi
printf '%s  %s\n' "$before" "$work/view/$driver" | sha256sum -c --strict --quiet -
git -C "$work/view" apply --check --whitespace=error "$delta"
git -C "$work/view" apply --whitespace=error "$delta"
printf '%s  %s\n' "$after" "$work/view/$driver" | sha256sum -c --strict --quiet -
cp "$work/view/$driver" "$work/post.c"
git -C "$work/view" apply -R --whitespace=error "$delta"
printf '%s  %s\n' "$before" "$work/view/$driver" | sha256sum -c --strict --quiet -
if [[ $phase == prepared ]]; then
 for cc in gcc clang; do
  cxx=g++; [[ $cc != clang ]] || cxx=clang++
  for sanitize in 0 1; do
   CC=$cc SANITIZE=$sanitize bash "$profile/tests/ssc-dual-light-endpoint.sh" "$work/post.c" "$kernel/include/linux/iio/types.h"
   flags=(-std=c++17 -O1 -g -UNDEBUG -Wall -Wextra -Werror -fno-omit-frame-pointer)
   [[ $sanitize == 0 ]] || flags+=(-fsanitize=address,undefined -fno-sanitize-recover=all)
   "$cxx" "${flags[@]}" "$profile/tests/ssc-dual-light-dt.cpp" -lfdt -o "$work/dt"
   ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/dt"
  done
 done
 # Every original wire/metadata/ACK test runs against the actual endpoint
 # postimage. Only extractor dependencies and inert host declarations grow.
 mkdir -p "$work/legacy/tests" "$work/legacy/src/sensors"
 for path in tests/ssc-native-host.h tests/ssc-native-contract.c src/sensors/uke-ssc-protocol.c src/sensors/uke-ssc-protocol.h src/sensors/uke-ssc-dual-light.h; do
  install -m644 "$profile/$path" "$work/legacy/$path"
 done
 cat >> "$work/legacy/tests/ssc-native-host.h" <<'HOST'
#ifndef UKE_SSC_DUAL_NATIVE_HOST_H
#define UKE_SSC_DUAL_NATIVE_HOST_H
#include "uke-ssc-dual-light.h"
#define U64_MAX UINT64_MAX
#define BIT(n) (1U << (n))
struct input_handler { void *private; };
#endif
HOST
 install -m644 "$work/post.c" "$work/legacy/src/sensors/uke-ssc-iio.c"
 awk '
  {
   if(sub(/ssc_schedule_locked ssc_invalidate_locked/,"ssc_schedule_locked ssc_dual_reset_locked ssc_invalidate_locked"))a++
   if(sub(/ssc_publish_locked ssc_response/,"ssc_dual_feed_locked ssc_publish_locked ssc_response"))b++
   if(sub(/ssc_start ssc_stop ssc_close_client;/,"ssc_start ssc_stop ssc_stream_wanted ssc_stream_user_valid ssc_stream_get ssc_stream_put ssc_close_client ssc_dual_reconcile;"))c++
   print
  }
  END{if(a!=1||b!=1||c!=1)exit 1}
 ' "$profile/tests/ssc-native-contract.sh" > "$work/legacy/tests/ssc-native-contract.sh"
 cmp "$work/legacy/tests/ssc-native-contract.c" "$profile/tests/ssc-native-contract.c"
 bash "$work/legacy/tests/ssc-native-contract.sh" "$kernel"
 printf 'Actual combined-light callbacks, twelve behavioral mutants, four DT modes and unchanged original QMI assertions passed; full/physical qualification separate.\n'
 exit 0
fi
printf '%s  %s\n' "$before" "$kernel/$driver" | sha256sum -c --strict --quiet -
cmp "$profile/src/display/uke-abl-native.h" "$kernel/arch/arm64/kernel/uke-abl-native.h"
cmp "$profile/src/boot/bindings/firmware/xiaomi,uke-ssc-sensors.yaml" "$kernel/Documentation/devicetree/bindings/firmware/xiaomi,uke-ssc-sensors.yaml"
for path in "$delta" "$profile/src/sensors/0006-ssc-dual-light-native-dt.patch" "$profile/src/sensors/0007-ssc-dual-light-binding.patch" "$profile/src/sensors/0008-ssc-dual-light-input-dependency.patch"; do
 git -C "$kernel" apply --check --whitespace=error "$path"
 git -C "$kernel" apply --whitespace=error "$path"
done
install -m644 "$profile/src/sensors/uke-ssc-dual-light.h" "$kernel/${driver%/*}/"
install -m644 "$profile/src/boot/uke-dual-light.h" "$kernel/arch/arm64/kernel/"
printf '%s  %s\n' "$after" "$kernel/$driver" | sha256sum -c --strict --quiet -
grep -Fx CONFIG_INPUT=y "$out/.config"
release=$(jq -er .kernel_release "$profile/source-composition.json")
version=$(jq -er .upstream_version "$profile/source-composition.json")
localversion=${release#"$version"}
[[ $release == "$version"-*-unstable && $(cat "$out/include/config/kernel.release") == "$release" ]]
sha256sum "$out/.config" "$out/include/config/kernel.release" "$out/include/generated/utsrelease.h" > "$work/identities.sha256"
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION="$localversion" KCFLAGS=-Werror W=1 \
 drivers/iio/common/uke-ssc/uke-ssc.o arch/arm64/kernel/uke-abl.o
sha256sum -c --strict --quiet "$work/identities.sha256"
for file in drivers/iio/common/uke-ssc/uke-ssc-iio.o arch/arm64/kernel/uke-abl.o; do
 llvm-readelf -h "$out/$file" | grep -E 'Machine:.*AArch64'
done
llvm-nm -u "$out/drivers/iio/common/uke-ssc/uke-ssc-iio.o" > "$work/imports"
for symbol in input_register_handler input_unregister_handler input_register_handle input_unregister_handle input_open_device input_close_device iio_device_register iio_device_unregister; do
 grep -Eq " U $symbol$" "$work/imports"
done
! grep -Eq ' U (hrtimer_start|mod_timer|queue_delayed_work_on|input_grab_device)$' "$work/imports"
strings "$out/arch/arm64/kernel/uke-abl.o" | grep -Fx lid-switch
printf 'Actual cumulative AArch64 dual-light SSC/input/IIO composite and early DT link passed; canonical config/release/UTS retained, binding/physical/provider parity still separate.\n'

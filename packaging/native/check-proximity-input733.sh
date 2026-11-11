#!/usr/bin/bash
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
out=$(realpath -m "${2:?Native output}")
phase=${3:?source, objects or linked}
profile=$kernel/native-profile
manifest=$profile/manifests/ssc-proximity-input-20261109.json
driver=drivers/iio/common/uke-ssc/uke-ssc-iio.c
printf '%s  %s\n' "$(jq -er .driver_after_sha256 "$manifest")" "$kernel/$driver" | sha256sum -c --strict --quiet -
cmp "$kernel/drivers/iio/common/uke-ssc/uke-ssc-proximity-input.h" "$profile/src/sensors/uke-ssc-proximity-input.h"
case $phase in
 source)
  work=$(mktemp -d)
  trap 'find "$work" -depth -delete' EXIT
  mkdir -p "$work/view/${driver%/*}"
  cp "$kernel/$driver" "$work/view/$driver"
  git -C "$work/view" apply -R --check --whitespace=error "$profile/src/sensors/0010-ssc-proximity-input.patch"
  git -C "$work/view" apply -R --whitespace=error "$profile/src/sensors/0010-ssc-proximity-input.patch"
  printf '%s  %s\n' "$(jq -er .driver_before_sha256 "$manifest")" "$work/view/$driver" | sha256sum -c --strict --quiet -
  # Check the fixture's public input ABI against the pinned real kernel.
  grep -Eq '^#define[[:space:]]+SW_FRONT_PROXIMITY[[:space:]]+0x0b([[:space:]]|$)' "$kernel/include/uapi/linux/input-event-codes.h"
  for cc in gcc clang; do
   for sanitize in 0 1; do
    CC=$cc SANITIZE=$sanitize bash "$profile/tests/ssc-proximity-input.sh" "$kernel/$driver"
   done
  done
  bash "$profile/packaging/native/check-dual-light-delivery733.sh" "$kernel" "$out" source
  bash "$profile/tests/proximity-delivery-source.sh" "$kernel"
  printf 'Native proximity source inverse and four actual callback modes passed; original IIO/wire/DT retained.\n'
  ;;
 objects)
  test -s "$out/drivers/iio/common/uke-ssc/uke-ssc.o"
  llvm-nm "$out/drivers/iio/common/uke-ssc/uke-ssc.o" | awk '
   $2=="U" && $3=="input_register_device" || $1=="U" && $2=="input_register_device" {registration=1}
   $2=="U" && $3=="input_event" || $1=="U" && $2=="input_event" {event=1}
   END {if(!registration || !event)exit 1}'
  printf 'Actual AArch64 SSC composite includes proximity input; full module and physical acceptance remain separate.\n'
  ;;
 linked)
  module=$out/drivers/iio/common/uke-ssc/uke-ssc.ko
  test -s "$module"
  llvm-nm "$module" | awk '
   $2=="U" && $3=="input_register_device" || $1=="U" && $2=="input_register_device" {registration=1}
   $2=="U" && $3=="input_event" || $1=="U" && $2=="input_event" {event=1}
   END {if(!registration || !event)exit 1}'
  printf 'Native SSC proximity input is in the linked production module; physical parity remains unqualified.\n'
  ;;
 *) exit 2;;
esac

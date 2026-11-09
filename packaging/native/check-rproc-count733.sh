#!/usr/bin/bash
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
out=$(realpath -m "${2:?Native output}")
phase=${3:?source or objects}
profile=$kernel/native-profile
manifest=$profile/manifests/rproc-crash-count-20261109.json
driver=drivers/remoteproc/remoteproc_sysfs.c
printf '%s  %s\n' "$(jq -er .driver_after_sha256 "$manifest")" "$kernel/$driver" | sha256sum -c --strict --quiet -
sha256sum -c --strict --quiet "$kernel/native-generated/rproc-count-worker.sha256"
case $phase in
 source)
  work=$(mktemp -d)
  trap 'find "$work" -depth -delete' EXIT
  mkdir -p "$work/drivers/remoteproc"
  cp "$kernel/$driver" "$work/$driver"
  git -C "$work" apply --reverse --check --whitespace=error "$profile/src/health/rproc-crash-count.patch"
  git -C "$work" apply --reverse --whitespace=error "$profile/src/health/rproc-crash-count.patch"
  cmp "$work/$driver" "$kernel/native-generated/rproc-count-before.c"
  [[ $(grep -Fxc 'static DEVICE_ATTR_RO(crash_count);' "$kernel/$driver") == 1 ]]
  [[ $(grep -Fxc $'\t&dev_attr_crash_count.attr,' "$kernel/$driver") == 1 ]]
  bash "$profile/tests/rproc-crash-count.sh" "$kernel"
  printf 'Native read-only crash count source inverse and four callback modes passed; crash worker/recovery unchanged.\n'
  ;;
 objects)
  object=$out/drivers/remoteproc/remoteproc_sysfs.o
  llvm-readelf -h "$object" | grep -F AArch64
  llvm-nm "$object" | awk '$3=="crash_count_show"{show=1}$3=="dev_attr_crash_count"{attr=1}END{if(!show||!attr)exit 1}'
  printf 'Actual AArch64 remoteproc crash_count sysfs object passed; no physical fault/fallback acceptance.\n'
  ;;
 *) exit 2;;
esac

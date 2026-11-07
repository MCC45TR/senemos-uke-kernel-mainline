#!/usr/bin/env bash
# Preserve the complete existing config checks; report selected memory values on failure.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
out=$(realpath -m "${2:?Native output}")
set +e
bash "$kernel/native-profile/packaging/native/prepare-migration-manager731.sh" "$kernel" "$out"
status=$?
set -e
if [[ $status != 0 ]];then
 for role in native cdsp waydroid;do
  file=$kernel/native-generated/migration-manager-$role/.config
  [[ -e $file ]] || continue
  printf 'Failed memory config role:%s\n' "$role" >&2
  grep -E '^(CONFIG_(842_|LZ4HC_|ZSMALLOC|ZRAM|ZSWAP)|# CONFIG_(ZSMALLOC|ZRAM|ZSWAP))' "$file" >&2 || true
 done
 exit "$status"
fi

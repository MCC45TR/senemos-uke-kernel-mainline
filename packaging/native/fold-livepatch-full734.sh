#!/usr/bin/bash
# Data-only correction of the qualified source-check archive for full builds.
set -Eeuo pipefail
[[ $# == 2 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
profile=$(realpath "$1");boot=$(realpath "$2")
payload=$boot/src/boot/build-payload.sh
storage=$profile/packaging/native/prepare-storage-config-full733.sh
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cp "$payload" "$work/payload.before"
awk '
 $0=="bash \"$here/../../src/livepatch/configure734.sh\" \"$kernel\" \"$out/.config\" \"$kernel/native-profile\"" {removed++;next}
 {print}
 $0=="bash \"$kernel/native-profile/packaging/native/prepare-storage-config-full733.sh\" \"$kernel\" \"$out\" seed" {
  print "bash \"$kernel/native-profile/packaging/native/prepare-livepatch-full734.sh\" \"$kernel\" \"$out\"";added++
 }
 END{if(removed!=1||added!=1)exit 1}
' "$payload" > "$work/payload.after"
awk '
 $0=="bash \"$kernel/native-profile/packaging/native/prepare-livepatch-full734.sh\" \"$kernel\" \"$out\"" {next}
 {print}
 $0=="cp \"$here/../../packaging/native/native.config\" \"$out/.config\"" {
  print "bash \"$here/../../src/livepatch/configure734.sh\" \"$kernel\" \"$out/.config\" \"$kernel/native-profile\"";n++
 }END{if(n!=1)exit 1}
' "$work/payload.after" | cmp - "$work/payload.before"
cp "$storage" "$work/storage.before"
awk '{print}
 $0==" cp \"$profile/native.config\" \"$before/.config\"" {
  print " bash \"$profile/src/livepatch/configure734.sh\" \"$kernel\" \"$before/.config\" \"$profile\"";n++
 }END{if(n!=1)exit 1}
' "$storage" > "$work/storage.after"
sed '\|^ bash "$profile/src/livepatch/configure734.sh" "$kernel" "$before/.config" "$profile"$|d' "$work/storage.after" | cmp - "$work/storage.before"
bash -n "$work/payload.after" "$work/storage.after" "$owner/packaging/native/prepare-livepatch-full734.sh"
install -m644 "$work/payload.after" "$payload"
install -m644 "$work/storage.after" "$storage"
install -m644 "$owner/packaging/native/prepare-livepatch-full734.sh" "$profile/packaging/native/"
printf 'Full livepatch ordering: original seed checks run first; exact payload/storage recipe inverses retained.\n'

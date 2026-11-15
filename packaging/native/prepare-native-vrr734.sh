#!/usr/bin/bash
set -Eeuo pipefail
[[ $# == 2 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
for tree in "$1" "$2"; do
 [[ -d $tree && ! -e $tree/manifests/native-vrr734-20261115.json ]]
 printf '%s  %s\n' 3abc559e7a1d5bc70283a56b152b4670a84bcc6c57e9a79f51c5f1ebc261f97f "$tree/packaging/native/check-vrr-api731.sh" | sha256sum -c --strict --quiet -
 install -m644 "$owner/packaging/native/check-vrr-api731.sh" "$tree/packaging/native/"
 install -m644 "$owner/src/display/apply-native-vrr734.sh" "$owner/src/display/0076-uke-native-vrr734.patch" "$tree/src/display/"
 install -m644 "$owner/manifests/native-vrr734-20261115.json" "$tree/manifests/"
 install -m644 "$owner/tests/native-vrr734.sh" "$tree/tests/"
done

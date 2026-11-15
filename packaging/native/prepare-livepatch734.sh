#!/usr/bin/bash
# Source-only overlay; the private signing key never enters source or COPR.
set -Eeuo pipefail
[[ $# == 2 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
profile=$1; boot=$2
for tree in "$profile" "$boot"; do
 [[ -d $tree && ! -L $tree && ! -e $tree/src/livepatch ]]
 mkdir "$tree/src/livepatch"
 install -m644 "$owner/src/livepatch/configure734.sh" "$owner/src/livepatch/uke-livepatch-20261115.pem" "$tree/src/livepatch/"
 install -m644 "$owner/manifests/livepatch734-20261115.json" "$tree/manifests/"
 printf '%s  %s\n' 226e0f37b887624bbf6e8569eb06a926ac81e24f04d8d5d99332bfcb6f9e7eda "$tree/tests/kernel-hardening-config-contract.sh" | sha256sum -c --strict --quiet -
 install -m644 "$owner/tests/kernel-hardening-config-contract.sh" "$tree/tests/kernel-hardening-config-contract.sh"
 install -m644 "$owner/tests/livepatch-config734.sh" "$tree/tests/"
done
# Keep raw and historical reference configurations unchanged. Only the final
# payload/configuration receives the reviewed two-setting delta, after the
# complete parent configuration comparisons have run.
payload=$boot/src/boot/build-payload.sh
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cp "$payload" "$work/before.sh"
awk '{print} $0=="cp \"$here/../../packaging/native/native.config\" \"$out/.config\"" {
 print "bash \"$here/../../src/livepatch/configure734.sh\" \"$kernel\" \"$out/.config\" \"$kernel/native-profile\"";n++
} END{if(n!=1)exit 1}' "$payload" > "$work/after.sh"
sed '\|^bash "$here/../../src/livepatch/configure734.sh" "$kernel" "$out/.config" "$kernel/native-profile"$|d' "$work/after.sh" | cmp - "$work/before.sh"
bash -n "$work/after.sh"
install -m644 "$work/after.sh" "$payload"
printf 'Livepatch final-build configuration and pinned public certificate staged; raw parent configuration and signature enforcement retained.\n'

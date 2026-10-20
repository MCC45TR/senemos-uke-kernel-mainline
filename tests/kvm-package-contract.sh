#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
spec=$root/packaging/senemos-uke-linux-kernel-mainline.spec
expected=senemos-uke-linux-kernel-mainline-kvm
names=$(rpmspec -q --qf '%{NAME}\n' --target aarch64 "$spec")
[[ $names == "$expected"$'\n'"$expected-core"$'\n'"$expected-modules"$'\n'"$expected-dtbs"$'\n'"$expected-boot" ]]
parsed=$(rpmspec --parse --target aarch64 "$spec")
grep -Eq '^Provides: kernel-uname-r\([0-9]+\.[0-9]+\.[0-9]+-[1-9][0-9]*-kvm\)$' <<< "$parsed"
if grep -E '^Obsoletes:|^Conflicts:|^%(post|pre|preun|postun|posttrans|pretrans|trigger)($|[[:space:]])|^Requires:.*(python|pypy|uke-kernel-update)' <<< "$parsed"; then
    echo 'KVM candidates must coexist without automatic activation' >&2; exit 1
fi
for requirement in CONFIG_KVM=y CONFIG_F2FS_FS=y CONFIG_F2FS_FS_SECURITY=y; do
    grep -Fxq "$requirement" "$root/packaging/native/native.config"
done
grep -Fq '"$out/userdata.img"' "$root/src/boot/build-payload.sh"
bash "$root/tests/native-firewall-contract.sh"
echo 'Current KVM namespace, distinct module ABI, both roots and no activation scriptlets passed'

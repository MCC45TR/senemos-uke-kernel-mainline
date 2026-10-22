#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
spec=$root/packaging/senemos-uke-linux-kernel-mainline.spec
expected=senemos-uke-linux-kernel-mainline-kvm
names=$(rpmspec -q --qf '%{NAME}\n' --target aarch64 "$spec")
[[ $names == "$expected"$'\n'"$expected-core"$'\n'"$expected-modules"$'\n'"$expected-dtbs"$'\n'"$expected-boot"$'\n'"$expected-singleboot" ]]
parsed=$(rpmspec --parse --target aarch64 "$spec")
grep -Eq '^Provides: kernel-uname-r\([0-9]+\.[0-9]+\.[0-9]+-[1-9][0-9]*-kvm\)$' <<< "$parsed"
if grep -E '^Obsoletes:|^Conflicts:|^%(post|pre|preun|postun|posttrans|pretrans|trigger)($|[[:space:]])|^Requires:.*(python|pypy)' <<< "$parsed"; then
    echo 'KVM candidates must coexist without automatic activation' >&2; exit 1
fi
for requirement in CONFIG_KVM=y CONFIG_F2FS_FS=y CONFIG_F2FS_FS_SECURITY=y; do
    grep -Fxq "$requirement" "$root/packaging/native/native.config"
done
grep -Fq '"$out/userdata.img"' "$root/src/boot/build-payload.sh"
bash "$root/tests/native-firewall-contract.sh"
build_guard=$(sed -n '/^\[\[ \$release =~ /p' "$root/src/boot/build-payload.sh")
base_guard=$(sed -n '/^\[\[ \$# == 2 && \$2 =~ /p' "$root/src/boot/make-initramfs-base.sh")
release=7.2.12-3-kvm jobs=2
eval "$build_guard"
(set -- fixture "$release"; eval "$base_guard")
release=7x2y12-3-kvm
if (eval "$build_guard") || (set -- fixture "$release"; eval "$base_guard"); then
    echo 'Producer release separators must be literal dots' >&2; exit 1
fi
echo 'Current KVM namespace, distinct module ABI, both roots and no activation scriptlets passed'

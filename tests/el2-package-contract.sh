#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
spec=$root/packaging/senemos-uke-linux-kernel-mainline.spec
parsed=$(rpmspec --parse --target aarch64 "$spec")
expected=senemos-uke-linux-kernel-mainline-kvm
names=$(rpmspec -q --qf '%{NAME}\n' --target aarch64 "$spec")
[[ $names == "$expected"$'\n'"$expected-core"$'\n'"$expected-modules"$'\n'"$expected-dtbs"$'\n'"$expected-boot" ]]
grep -Eq '^Provides: kernel-uname-r\(7\.2\.11-[1-9][0-9]*-kvm\)$' <<< "$parsed"
[[ $(grep -Fxc 'Provides: installonlypkg(kernel)' <<< "$parsed") == 4 ]]
if grep -E '^Obsoletes:|^Conflicts:|^%(post|pre|preun|postun|posttrans|pretrans|trigger)($|[[:space:]])|^Requires:.*(python|pypy|uke-kernel-update)|uke-kernel-update apply' <<< "$parsed"; then
    echo 'The experiment must coexist without automatic boot writes' >&2
    exit 1
fi
grep -F 'native-profile/src/kvm/probe.cpp' <<< "$parsed" >/dev/null
grep -F 'CONFIG_KVM=y' "$root/packaging/native/native.config" >/dev/null
exit_parsed=$(rpmspec --parse --with gunyah_exit --target aarch64 "$spec")
grep -Fx 'Name: senemos-uke-linux-kernel-mainline-kvm-exit' <<< "$exit_parsed" >/dev/null
grep -Eq '^Provides: kernel-uname-r\(7\.2\.11-[1-9][0-9]*-kvm-exit\)$' <<< "$exit_parsed"
if grep -E '^%(post|pre|preun|postun|posttrans|pretrans|trigger)($|[[:space:]])|uke-kernel-update apply' <<< "$exit_parsed"; then exit 1; fi
echo 'Isolated KVM package, matching ABI and no automatic boot writer passed'

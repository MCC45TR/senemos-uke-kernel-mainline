#!/usr/bin/env bash
# Host metadata gate for the single public mainline source producer.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
spec=${1:-$root/packaging/senemos-uke-linux-kernel-mainline.spec}
command -v rpmspec >/dev/null
future=$(mktemp)
trap 'rm -f "$future"' EXIT
sed 's/^Version: .*/Version: 7.2.13/' "$spec" > "$future"
future_release=$(rpmspec -q --srpm --qf '%{RELEASE}' --target aarch64 "$future")
[[ $future_release == 1 || $future_release == 1.* ]]
expected=senemos-uke-linux-kernel-mainline-unstable
names=$(rpmspec -q --qf '%{NAME}\n' --target aarch64 "$spec")
[[ $names == "$expected"$'\n'"$expected-core"$'\n'"$expected-modules"$'\n'"$expected-dtbs"$'\n'"$expected-boot"$'\n'"$expected-singleboot" ]]
# Query expanded payload paths rather than retaining the old shared module ABI.
parsed=$(rpmspec --parse "$spec")
grep -Eq '^Provides: kernel-uname-r\(7\.3\.0-[1-9][0-9]*-unstable\)$' <<< "$parsed"
[[ $(grep -c '^Provides: installonlypkg(kernel)$' <<< "$parsed") == 4 ]]
if grep -E '^Obsoletes:|^Conflicts:|^%(pre|post|preun|postun|pretrans|posttrans|trigger[a-z]*)($|[[:space:]])|^Requires:.*(python|pypy|uke-kernel-update)' <<< "$parsed"; then
    echo 'Unstable packages must coexist without automatic activation' >&2
    exit 1
fi
grep -Fx 'Source4: senemos-native-profile-7.3.0.tar.xz' <<< "$parsed"
grep -F 'CONFIG_INITRAMFS_SOURCE=""' "$root/packaging/native/native.config"
bash "$root/tests/native-firewall-contract.sh"
if grep -Fq 'qcom_q6v5_pas' "$root/src/boot/early-modules.list"; then
    echo 'PAS must wait for OEM firmware on the real root' >&2
    exit 1
fi
grep -F 'git archive HEAD src/display src/boot src/usb src/audio patches/$(version) patches/display patches/boot tests' "$root/Makefile"
grep -Fx 'disabled' "$root/packaging/native/audio-profile"
grep -Fx 'native-v1' "$root/packaging/native/llcc-profile"
grep -F 'packaging/native/llcc-profile "$$assets/"' "$root/Makefile"
grep -Fx 'UKE_LLCC_PROFILE=$(cat "$profile/llcc-profile")' "$root/packaging/native/prepare.sh"
[[ ! -e $root/packaging/native/senemos-uke-linux-kernel-mainline-native.spec ]]
bash "$root/tests/unstable-boot-status-contract.sh"
echo 'Unstable namespace, isolated module ABI, matched boot and no activation passed'

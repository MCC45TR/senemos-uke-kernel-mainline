#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
cmp "$root/packaging/senemos-uke-linux-kernel-mainline.spec" "$root/configs/host/senemos-uke-linux-kernel-mainline.spec"
spec=$root/packaging/senemos-uke-linux-kernel-mainline.spec
grep -Fx '    /usr/bin/uke-kernel-update apply /usr/lib/senemos/kernel-updates/%{krel} || exit 1' "$spec"
if grep -F '/usr/sbin/uke-kernel-update' "$spec"; then exit 1; fi
grep -Fx '%global krel %{version}-senemos.%{senemos_build_release}' "$spec"
grep -Fx 'Requires: %{name}-boot = %{version}-%{release}' "$spec"
grep -Fx 'Requires: uke-kernel-update >= 0.1.0-12' "$spec"
echo 'Versioned boot tuple and updater executable contract passed'

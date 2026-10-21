#!/usr/bin/env bash
# RPM graph and payload selection only; no device writes.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
spec=$root/packaging/senemos-uke-linux-kernel-mainline.spec
base=$(rpmspec --target aarch64 -q --srpm --qf '%{NAME}' "$spec")
release=$(rpmspec --target aarch64 -q --srpm --qf '%{VERSION}-%{RELEASE}' "$spec")
names=$(rpmspec --target aarch64 -q --qf '%{NAME}\n' "$spec")
[[ $(wc -l <<< "$names") == 6 ]]
grep -Fxq "$base-singleboot" <<< "$names"
requirements=$(rpmspec --target aarch64 -q --qf '[%{=NAME}\t%{REQUIRENAME}\t%{REQUIREFLAGS:depflags}\t%{REQUIREVERSION}\n]' "$spec")
grep -Fxq "$base-singleboot"$'\t'"$base"$'\t=\t'"$release" <<< "$requirements"
grep -Fxq "$base-singleboot"$'\tuke-installation-profile\t>=\t1.1.4' <<< "$requirements"
parsed=$(rpmspec --target aarch64 --parse "$spec")
grep -Fq '"automatic_kernel_activation": false' <<< "$parsed"
grep -Fq 'ln -s kernel-updates/' <<< "$parsed"
if grep -E '^%(post|pre|preun|postun|posttrans|pretrans).*singleboot' <<< "$parsed"; then
    echo 'Singleboot metadata must not activate a boot image' >&2; exit 1
fi
printf '%s\n' 'One source family, six children, exact singleboot tuple and no activation scriptlet passed.'

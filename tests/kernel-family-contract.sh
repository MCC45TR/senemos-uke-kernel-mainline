#!/usr/bin/env bash
# RPM graph and payload selection only; no device writes.
set -Eeuo pipefail
trap 'printf "Kernel family metadata contract failed at line %s\n" "$LINENO" >&2' ERR
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
# Build only the real metadata install/files sections, without a kernel rebuild.
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work"/{SOURCES,SPECS}
cp "$root/packaging/SINGLEBOOT.md" "$work/SOURCES/SINGLEBOOT.md"
cp "$root/LICENSE" "$work/SOURCES/singleboot-LICENSE"
{
    printf '%%global debug_package %%{nil}\n%%global __os_install_post %%{nil}\n%%global krel fixture\nName: %s\nVersion: 1\nRelease: 1\nSummary: Host metadata fixture\nLicense: MIT\nSource7: SINGLEBOOT.md\nSource8: singleboot-LICENSE\n%%description\nHost metadata fixture; no kernel or hardware.\n%%package singleboot\nSummary: Host profile fixture\nLicense: MIT\n%%description singleboot\nHost profile fixture.\n%%prep\n%%build\n%%install\n' "$base"
    awk '/^%install$/{copy=1;next} copy&&/^export ARCH=/{exit} copy' "$spec"
    printf '\n%%files\n'
    awk '/^%files singleboot$/{copy=1} copy&&/^%changelog$/{exit} copy' "$spec"
} > "$work/SPECS/profile.spec"
if ! rpmbuild -bb --nodeps --define "_topdir $work" "$work/SPECS/profile.spec" > "$work/build.log" 2>&1; then
    cat "$work/build.log" >&2;exit 1
fi
packages=("$work/RPMS/"*/*-singleboot-*.rpm)
[[ ${#packages[@]} == 1 && -s ${packages[0]} ]]
rpm -qpl "${packages[0]}" > "$work/files"
grep -Fxq "/usr/share/doc/$base-singleboot/SINGLEBOOT.md" "$work/files"
grep -Fxq "/usr/share/licenses/$base-singleboot/LICENSE" "$work/files"
printf '%s\n' 'One source family, six children, exact singleboot tuple, installed documentation and no activation scriptlet passed.'

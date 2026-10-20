#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
spec=$root/packaging/senemos-uke-linux-kernel-mainline-kvm-singleboot.spec
name=$(rpmspec -q --srpm --qf '%{NAME}' "$spec")
version=$(rpmspec -q --srpm --qf '%{VERSION}' "$spec")
# Undefining COPR's empty override reveals the worker's underlying distro suffix.
release=$(rpmspec --define 'dist %{nil}' -q --srpm --qf '%{RELEASE}' "$spec")
evr=$(rpmspec -q --srpm --qf '%{VERSION}-%{RELEASE}' "$spec")
requires=$(rpmspec -q --requires "$spec")
[[ $name == senemos-uke-linux-kernel-mainline-kvm-singleboot ]]
for suffix in '' -core -modules -dtbs -boot; do
    grep -Fxq "senemos-uke-linux-kernel-mainline-kvm$suffix = $evr" <<< "$requires"
done
if grep -Eq '^%(pre|post|preun|postun|pretrans|posttrans|trigger[a-z]*)([[:space:]]|$)' "$spec"; then exit 1; fi
jq -e --arg name "$name" --arg abi "$version-$release-kvm" '
 .package==$name and .kernel_release==$abi and .root_partition=="userdata" and
 .root_filesystem=="f2fs" and .boot_selector=="senemos.root=userdata" and
 .boot_image==("/usr/lib/senemos/kernel-updates/"+$abi+"/userdata.img") and
 .automatic_kernel_activation==false' "$root/packaging/kvm-singleboot.json" >/dev/null
echo 'KVM userdata exact tuple, separate boot default and no scriptlets passed'

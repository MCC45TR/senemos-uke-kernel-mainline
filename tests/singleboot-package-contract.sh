#!/usr/bin/env bash
set -Eeuo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
spec=$repo/packaging/senemos-uke-linux-kernel-mainline-singleboot.spec
identity=$(rpmspec -q --srpm --target aarch64 --qf '%{NAME} %{VERSION}-%{RELEASE}' "$spec")
[[ $identity == 'senemos-uke-linux-kernel-mainline-singleboot 7.2.11-15' ||
   $identity == 'senemos-uke-linux-kernel-mainline-singleboot 7.2.11-15.'* ]]
requires=$(rpmspec -q --requires --target aarch64 "$spec")
for part in core modules dtbs boot; do
    grep -Eq "^senemos-uke-linux-kernel-mainline-$part = 7[.]2[.]11-15([.]|$)" <<< "$requires"
done
if grep -Eq '^%(pre|post|preun|postun|pretrans|posttrans|trigger[a-z]*)([[:space:]]|$)' "$spec"; then exit 1; fi
jq -e '.package=="senemos-uke-linux-kernel-mainline-singleboot" and
    .kernel_release=="7.2.11-15" and .root_partition=="userdata" and
    .root_filesystem=="f2fs" and .boot_selector=="senemos.root=userdata" and
    .boot_image=="/usr/lib/senemos/kernel-updates/7.2.11-15/userdata.img" and
    .automatic_kernel_activation==false' "$repo/packaging/singleboot.json" >/dev/null
echo 'Singleboot exact shared tuple, userdata selection and no scriptlets passed'

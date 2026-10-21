#!/usr/bin/env bash
set -Eeuo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
spec=$repo/packaging/senemos-uke-linux-kernel-mainline-unstable-singleboot.spec
identity=$(rpmspec -q --srpm --target aarch64 --qf '%{NAME} %{VERSION}-%{RELEASE}' "$spec")
[[ $identity == 'senemos-uke-linux-kernel-mainline-unstable-singleboot 7.3.0-1' ||
   $identity == 'senemos-uke-linux-kernel-mainline-unstable-singleboot 7.3.0-1.'* ]]
requires=$(rpmspec -q --requires --target aarch64 "$spec")
grep -Eq '^senemos-uke-linux-kernel-mainline-unstable = 7[.]3[.]0-1([.]|$)' <<< "$requires"
for part in core modules dtbs boot; do
    grep -Eq "^senemos-uke-linux-kernel-mainline-unstable-$part = 7[.]3[.]0-1([.]|$)" <<< "$requires"
done
if grep -Eq '^%(pre|post|preun|postun|pretrans|posttrans|trigger[a-z]*)([[:space:]]|$)' "$spec"; then exit 1; fi
grep -Fq '%{_datadir}/senemos/uke/unstable-singleboot.json' "$spec"
grep -Fq '%{_prefix}/lib/senemos/unstable-default-boot.img' "$spec"
if grep -Fq '%{_prefix}/lib/senemos/default-boot.img' "$spec"; then exit 1; fi
jq -e '.package=="senemos-uke-linux-kernel-mainline-unstable-singleboot" and
    .kernel_release=="7.3.0-1-unstable" and .root_partition=="userdata" and
    .root_filesystem=="f2fs" and .boot_selector=="senemos.root=userdata" and
    .boot_image=="/usr/lib/senemos/kernel-updates/7.3.0-1-unstable/userdata.img" and
    .automatic_kernel_activation==false' "$repo/packaging/singleboot.json" >/dev/null
echo 'Singleboot exact shared tuple, userdata selection and no scriptlets passed'

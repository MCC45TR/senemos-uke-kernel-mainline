#!/usr/bin/env bash
# COPR only: preserve cumulative12101/touch/geometry/GMU and compile CDSP SMMU.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
factory=$owner/packaging/native/copr-gmu-msm-object-check.sh
printf '%s  %s\n' dd75377d4dcfa1d601a982c92fd37def8930ecbf313ec71dc7e142f24ad032f7 "$factory" | sha256sum -c --strict -
[[ $(curl -q -fLsS --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11261342 | jq -er .state) == succeeded ]]
# Reuse the unchanged qualified factory with this independent fixture identity.
# Its namespace guard still runs, now against uke-cdsp-actlr-check7.3.1-1.
sed -e 's/^owner=.*/owner=${UKE_CDSP_FACTORY_OWNER:?}/' \
    -e 's/uke-o82-kms-check/uke-cdsp-actlr-check/g' \
    -e 's/7\.3\.1-16/7.3.1-1/g' -e 's/Release: 16%/Release: 1%/g' \
    "$factory" > "$stage/factory.sh"
UKE_CDSP_FACTORY_OWNER=$owner bash "$stage/factory.sh" "$output"
spec=$output/uke-cdsp-actlr-check.spec
[[ $(grep -c '^Source10:' "$spec") == 0 ]]
git -C "$owner" archive --prefix=cdsp-addon/ HEAD src/cdsp \
    patches/cdsp/0001-uke-cdsp-actlr.patch tests/cdsp-actlr-contract.sh \
    tests/cdsp-actlr-qualify.sh tests/fixtures/cdsp-actlr-check.c \
    tests/iris-smmu-contract.sh | tar -xf - -C "$stage"
tar --sort=name --mtime="@$(git -C "$owner" show -s --format=%ct HEAD)" \
    --owner=0 --group=0 --numeric-owner -cJf "$output/uke-cdsp-actlr-addon.tar.xz" \
    -C "$stage" cdsp-addon
awk '
 /^%description$/ {print "Source10: uke-cdsp-actlr-addon.tar.xz"; print ""}
 /^%build$/ {
     print "tar -xJf %{SOURCE10}"
     print ""
     print
     print "set -o pipefail"
     print "bash cdsp-addon/tests/cdsp-actlr-qualify.sh \"$PWD\" | tee %{_topdir}/cdsp-actlr-checks.txt"
     next
 }
 /^%install$/ {
     print "before_config=$(sha256sum native-object/.config)"
     print "make ARCH=arm64 LLVM=1 LLVM_IAS=1 O=\"$PWD/native-object\" LOCALVERSION=-12101-unstable KCFLAGS=-Werror -j4 drivers/iommu/arm/arm-smmu/arm-smmu-qcom.o"
     print "test \"$(sha256sum native-object/.config)\" = \"$before_config\""
     print "llvm-readelf -h native-object/drivers/iommu/arm/arm-smmu/arm-smmu-qcom.o | grep -E \"Machine:.*AArch64\""
     print "llvm-nm --defined-only native-object/drivers/iommu/arm/arm-smmu/arm-smmu-qcom.o | grep -E \"[[:space:]]qcom_uke_cdsp_init_context$\""
     print "sha256sum native-object/drivers/iommu/arm/arm-smmu/arm-smmu-qcom.o | tee -a %{_topdir}/cdsp-actlr-checks.txt"
     print ""
     print
     print "install -Dm644 %{_topdir}/cdsp-actlr-checks.txt %{buildroot}%{_docdir}/%{name}/cdsp-actlr-checks.txt"
     next
 }
 /^%changelog$/ {print "%{_docdir}/%{name}/cdsp-actlr-checks.txt"; print ""}
 {print}
' "$spec" > "$stage/check.spec"
install -m644 "$stage/check.spec" "$spec"
[[ $(rpmspec --target aarch64 --define 'dist %{nil}' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$spec") == uke-cdsp-actlr-check-7.3.1-1 ]]
printf 'Cumulative CDSP ACTLR fixture source prepared; no kernel delivery or device operation\n'

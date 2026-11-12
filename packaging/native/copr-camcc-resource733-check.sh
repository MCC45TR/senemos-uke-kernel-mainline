#!/usr/bin/bash
# COPR-only extension of accepted24 preparation; text-only source evidence.
set -Eeuo pipefail
[[ $# == 1 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "$1")
manifest=$owner/manifests/camera-crmc-owner-20261113.json
[[ ! -e $output && ! -L $output && -z $(git -C "$owner" status --porcelain) ]]
(cd "$owner"; jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
curl -qfsSL --retry 2 --max-time 600 --proto '=https' --proto-redir '=https' \
 "$(jq -er .parent_srpm_url "$manifest")" -o "$stage/parent.src.rpm"
printf '%s  %s\n' "$(jq -er .parent_srpm_sha256 "$manifest")" "$stage/parent.src.rpm" | sha256sum -c --strict -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.3-24 ]]
rpmkeys --checksig --nosignature --verbose "$stage/parent.src.rpm"
rpm2cpio "$stage/parent.src.rpm" > "$stage/parent.cpio"
cpio -t --quiet < "$stage/parent.cpio" > "$stage/entries"
awk '/^\/|(^|\/)\.\.($|\/)/{bad=1}END{exit bad}' "$stage/entries"
mkdir "$output"
(cd "$output"; cpio -idm --quiet --no-absolute-filenames < "$stage/parent.cpio")
parent=$output/senemos-uke-linux-kernel-mainline-unstable.spec
printf '%s  %s\n' "$(jq -er .parent_spec_sha256 "$manifest")" "$parent" | sha256sum -c --strict -
! grep -qE '^Source190:' "$parent"
find "$output" -maxdepth 1 -type f ! -name "${parent##*/}" -print0 | sort -z | xargs -0 sha256sum > "$stage/retained.sha256"
mapfile -t assets < <(jq -er '.archive_assets[]' "$manifest")
git -C "$owner" archive --prefix=camcc-resource/ HEAD "${assets[@]}" \
 manifests/camera-crmc-owner-20261113.json LICENSES/GPL-2.0-only.txt | tar -xf - -C "$stage"
git -C "$owner" rev-parse HEAD > "$stage/camcc-resource/source-commit"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
 -cJf "$output/uke-camcc-resource.tar.xz" -C "$stage" camcc-resource
spec=$output/uke-kernel-migration-check.spec
awk '
 /^%description/{exit}
 /^Name:/{$0="Name: uke-kernel-migration-check"}
 /^Release:/{$0="Release: 106%{?dist}"}
 /^Summary:/{$0="Summary: Native Uke CAMCC permanent resource qualification"}
 /^(Requires|Provides|Recommends|Conflicts|Obsoletes)(\([^)]*\))?:/{next}
 {print}
' "$parent" > "$spec"
cat >> "$spec" <<'SPEC'
Source190: uke-camcc-resource.tar.xz

%description
Retain byte-identical accepted24 source preparation and compile the actual
CAMCC provider with passive permanent CRMC ownership. Test actual DT/resource
callbacks, fault retention and all previous registration/refusal controls.
Only text evidence is packaged. No Image, module or camera activation.

SPEC
awk '/^%prep$/{emit=1}/^%build$/{exit}emit{print}' "$parent" >> "$spec"
cat >> "$spec" <<'SPEC'
tar -xJf %{SOURCE190}
bash camcc-resource/src/camera/provider/apply-native-crm733.sh "$PWD" "$PWD/camcc-resource"

%build
set -o pipefail
for compiler in gcc clang;do
 for sanitizer in plain address-undefined;do
  flags=
  if [ "$sanitizer" = address-undefined ];then
   flags='-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer'
  fi
  CC="$compiler" CAMCC_RESOURCE_TEST_FLAGS="$flags" bash camcc-resource/tests/camcc-crmc-resource-contract.sh | tee -a %{_topdir}/camcc-resource-checks.txt
  CC="$compiler" CAMCC_FDT_TEST_FLAGS="$flags" bash camcc-resource/tests/camcc-controller-fdt731-contract.sh | tee -a %{_topdir}/camcc-resource-checks.txt
  CC="$compiler" CAMCC_CRM_TEST_FLAGS="$flags" bash camcc-resource/tests/camcc-crm-guard731-contract.sh | tee -a %{_topdir}/camcc-resource-checks.txt
  CC="$compiler" CAMCC_NATIVE_TEST_FLAGS="$flags" CAMCC_NATIVE_MUTATIONS=1 bash camcc-resource/tests/camcc-native731-contract.sh "$PWD" | tee -a %{_topdir}/camcc-resource-checks.txt
 done
done
bash native-profile/tests/camcc-quarantine-sleep.sh | tee -a %{_topdir}/camcc-resource-checks.txt
for compiler in gcc clang;do
 CC="$compiler" CAMCC_CLOCKS_TEST=1 CAMCC_CRM_CLOCKS_TEST=1 CAMCC_CRM_MUTATIONS=1 bash camcc-resource/tests/camcc-provider-contract.sh "$PWD" | tee -a %{_topdir}/camcc-resource-checks.txt
 CC="$compiler" CAMCC_CLOCKS_TEST=1 CAMCC_CRM_CLOCKS_TEST=1 CAMCC_TEST_FLAGS='-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer' bash camcc-resource/tests/camcc-provider-contract.sh "$PWD" | tee -a %{_topdir}/camcc-resource-checks.txt
done
bash camcc-resource/tests/camcc-resource-object733.sh "$PWD" "$PWD/resource-object" native-profile/native.config | tee -a %{_topdir}/camcc-resource-checks.txt

%install
install -d %{buildroot}%{_datadir}/%{name}
install -m644 %{_topdir}/camcc-resource-checks.txt camcc-resource/source-commit camcc-resource/manifests/camera-crmc-owner-20261113.json %{buildroot}%{_datadir}/%{name}/

%check
test ! -e arch/arm64/boot/Image
test ! -e resource-object/arch/arm64/boot/Image
test ! -e resource-object/drivers/clk/qcom/camcc-sm7675.ko
test -s %{buildroot}%{_datadir}/%{name}/camcc-resource-checks.txt

%files
%license camcc-resource/LICENSES/GPL-2.0-only.txt
%{_datadir}/%{name}/*

%changelog
* Fri Nov 13 2026 Uke contributors - 7.3.3-106
- Own exact CRMC resources permanently before provider power or publication.
- Preserve firmware-enabled refusal and test clean unwind and fault retention.
SPEC
sha256sum -c --strict --quiet "$stage/retained.sha256"
unlink "$parent"

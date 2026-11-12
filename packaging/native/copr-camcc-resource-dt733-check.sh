#!/usr/bin/bash
# COPR-only actual FDT converter qualification; never operates the tablet.
set -Eeuo pipefail
[[ $# == 1 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "$1")
manifest=$owner/manifests/camera-crm-resource-dt-20261113.json
[[ ! -e $output && ! -L $output && -z $(git -C "$owner" status --porcelain) ]]
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
mkdir "$output"
install -m644 "$owner/src/camera/provider/uke-camcc-dt.h" "$output/uke-camcc-dt.h"
install -m644 "$owner/tests/fixtures/camcc-controller-fdt-check.c" "$output/camcc-controller-fdt-check.c"
install -m644 "$owner/tests/camcc-controller-fdt731-contract.sh" "$output/camcc-controller-fdt731-contract.sh"
jq --arg commit "$(git -C "$owner" rev-parse HEAD)" --arg tree "$(git -C "$owner" rev-parse HEAD^{tree})" \
    '.+{source_commit:$commit,source_tree:$tree}' "$manifest" > "$output/camera-crm-resource-dt-source.json"
cat > "$output/uke-kernel-migration-check.spec" <<'SPEC'
Name: uke-kernel-migration-check
Version: 7.3.3
Release: 103%{?dist}
Summary: Native Uke CAMCC Device Tree resource qualification
License: GPL-2.0-only
ExclusiveArch: aarch64
Source0: uke-camcc-dt.h
Source1: camcc-controller-fdt-check.c
Source2: camcc-controller-fdt731-contract.sh
Source3: camera-crm-resource-dt-source.json
BuildRequires: gcc clang compiler-rt libfdt-devel bash coreutils findutils jq

%description
Text-only evidence for the actual early FDT converter. No driver, firmware,
service or policy is installed or activated. Full kernel and physical gates
remain separate.

%prep
mkdir -p fixture/src/camera/provider fixture/tests/fixtures
cp %{SOURCE0} fixture/src/camera/provider/
cp %{SOURCE1} fixture/tests/fixtures/
cp %{SOURCE2} fixture/tests/

%build
for compiler in gcc clang;do
 for sanitizer in plain address-undefined;do
  flags=
  if [ "$sanitizer" = address-undefined ];then
   flags='-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer'
  fi
  CC="$compiler" CAMCC_FDT_TEST_FLAGS="$flags" bash fixture/tests/camcc-controller-fdt731-contract.sh
 done
done

%install
mkdir -p %{buildroot}%{_datadir}/%{name}
jq '.+{native_qualified:true,actual_converter_exercised:true,compiler_modes:4,device_changed:false,physical_camera_accepted:false,crm_activation_allowed:false}' %{SOURCE3} > %{buildroot}%{_datadir}/%{name}/camera-crm-resource-dt-source-qualification.json

%check
jq -e '.native_qualified and .compiler_modes==4 and .parent_full_build==11309609 and (.crm_activation_allowed|not) and (.device_changed|not)' %{buildroot}%{_datadir}/%{name}/camera-crm-resource-dt-source-qualification.json >/dev/null

%files
%{_datadir}/%{name}/camera-crm-resource-dt-source-qualification.json

%changelog
* Fri Nov 13 2026 Uke contributors - 7.3.3-103
- Qualify exact CAMCC CFG/CRMC and interrupt topology with the actual converter.
SPEC

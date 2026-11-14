#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# COPR source worker: extend exact full26 preparation, package text evidence.
set -Eeuo pipefail
[[ $# == 1 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "$1")
manifest=$owner/manifests/camera-crm-passive-20261114.json
[[ ! -e $output && -z $(git -C "$owner" status --porcelain) ]]
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
curl -qfsSL --retry 2 --max-time 600 "$(jq -er .parent_srpm_url "$manifest")" -o "$work/parent.src.rpm"
printf '%s  %s\n' "$(jq -er .parent_srpm_sha256 "$manifest")" "$work/parent.src.rpm" | sha256sum -c --strict --quiet -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{SOURCEPACKAGE}' "$work/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.3-26.1 ]]
rpm2cpio "$work/parent.src.rpm" > "$work/parent.cpio"
cpio -t --quiet < "$work/parent.cpio" > "$work/paths"
awk '/^\/|(^|\/)\.\.($|\/)/{bad=1}END{exit bad}' "$work/paths"
mkdir "$output"
(cd "$output";cpio -idm --quiet --no-absolute-filenames < "$work/parent.cpio")
parent=$output/senemos-uke-linux-kernel-mainline-unstable.spec
printf '%s  %s\n' "$(jq -er .parent_spec_sha256 "$manifest")" "$parent" | sha256sum -c --strict --quiet -
find "$output" -maxdepth 1 -type f ! -name "${parent##*/}" -print0 | sort -z | xargs -0 sha256sum > "$work/retained.sha256"
mapfile -t assets < <(jq -er '.archive_assets[]' "$manifest")
git -C "$owner" archive --prefix=crm-passive/ HEAD "${assets[@]}" \
 manifests/camera-crm-passive-20261114.json LICENSES/GPL-2.0-only.txt | tar -xf - -C "$work"
git -C "$owner" rev-parse HEAD > "$work/crm-passive/source-commit"
mkdir "$work/crm-passive/oracle"
curl -qfsSL --retry 2 --max-time 90 "$(jq -er .oem_url "$manifest")" -o "$work/crm-passive/oracle/camcc-cliffs.c"
printf '%s  %s\n' "$(jq -er .oem_sha256 "$manifest")" "$work/crm-passive/oracle/camcc-cliffs.c" | sha256sum -c --strict --quiet -
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/uke-crm-passive.tar.xz" -C "$work" crm-passive
spec=$output/uke-kernel-migration-check.spec
awk '
 /^%description/{exit}
 /^Name:/{$0="Name: uke-kernel-migration-check"}
 /^Release:/{$0="Release: 112%{?dist}"}
 /^Summary:/{$0="Summary: Exact Uke CRM passive clock qualification"}
 /^(Requires|Provides|Recommends|Conflicts|Obsoletes)(\([^)]*\))?:/{next}
 {print}
' "$parent" > "$spec"
cat >> "$spec" <<'SPEC'
Source200: uke-crm-passive.tar.xz

%description
Prepare the exact cumulative full26 source, then qualify the thirty passive
CRM PLL/divider/branch adapters and complete eight-RCG attachment. Firmware
CRM remains refused by the production probe. Only text evidence is packaged.

SPEC
awk '/^%prep$/{emit=1}/^%build$/{exit}emit{print}' "$parent" >> "$spec"
node - "$parent" "$spec" <<'JS'
const fs=require('fs'),[i,o]=process.argv.slice(2),s=fs.readFileSync(i,'utf8');
const begin='\n%build\n';
const end='bash ssc-time-reference-full/packaging/native/prepare-ssc-time-reference-full733.sh "$PWD" %{_uke_out} source\n';
if(s.split(begin).length!==2||s.split(end).length!==2)throw Error('Full26 source-phase anchors');
const phase=s.slice(s.indexOf(begin)+begin.length,s.indexOf(end)+end.length);
if(/^(make |.*\b(linked|install|sealed)\s*$)/m.test(phase))throw Error('Non-source phase');
fs.appendFileSync(o,phase);
JS
cat >> "$spec" <<'SPEC'
tar -xJf %{SOURCE200}
(cd crm-passive; jq -r '.source_assets[]|.sha256+"  "+.path' manifests/camera-crm-passive-20261114.json | sha256sum -c --strict --quiet -)
bash crm-passive/src/camera/provider/apply-crm-passive733.sh "$PWD" "$PWD/crm-passive"

%build
set -o pipefail
bash crm-passive/tests/camcc-crm-passive.sh crm-passive/oracle/camcc-cliffs.c | tee -a %{_topdir}/crm-passive-checks.txt
for compiler in gcc clang;do
 for sanitizer in plain address-undefined;do
  flags=
  if [ "$sanitizer" = address-undefined ];then
   flags='-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer'
  fi
  CC="$compiler" CAMCC_NATIVE_TEST_FLAGS="$flags" CAMCC_NATIVE_MUTATIONS=1 bash crm-passive/tests/camcc-native731-contract.sh "$PWD" | tee -a %{_topdir}/crm-passive-checks.txt
 done
done
bash native-profile/tests/camcc-quarantine-sleep.sh | tee -a %{_topdir}/crm-passive-checks.txt
bash crm-passive/tests/camcc-crm-passive-object.sh "$PWD" "$PWD/passive-object" native-profile/native.config | tee -a %{_topdir}/crm-passive-checks.txt

%install
install -d %{buildroot}%{_datadir}/%{name}
install -m644 %{_topdir}/crm-passive-checks.txt crm-passive/source-commit crm-passive/manifests/camera-crm-passive-20261114.json %{buildroot}%{_datadir}/%{name}/

%check
test ! -e arch/arm64/boot/Image
test ! -e passive-object/arch/arm64/boot/Image
test ! -e passive-object/passive-adapter/passive.ko
test -s %{buildroot}%{_datadir}/%{name}/crm-passive-checks.txt

%files
%license crm-passive/LICENSES/GPL-2.0-only.txt
%{_datadir}/%{name}/*

%changelog
* Sat Nov 14 2026 Uke contributors - 7.3.3-112
- Qualify exact CRM passive clock ownership over cumulative full26 sources.
- Preserve firmware admission, permanent resources and native system sleep.
SPEC
sha256sum -c --strict --quiet "$work/retained.sha256"
unlink "$parent"
printf 'Complete full26 preparation retained verbatim with all parent assets; only passive CRM source/object qualification appended\n'

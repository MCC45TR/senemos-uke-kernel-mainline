#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# COPR source worker only. Preserve every qualified cumulative28 source input.
set -Eeuo pipefail
[[ $# == 1 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "$1")
manifest=$owner/manifests/camera-crm-rom-20261115.json
[[ ! -e $output && ! -L $output && -z $(git -C "$owner" status --porcelain) ]]
(cd "$owner"; jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
curl -qfsSL --retry 2 --max-time 600 --max-filesize 314572800 "$(jq -er .parent_srpm_url "$manifest")" -o "$work/parent.src.rpm"
printf '%s  %s\n' "$(jq -er .parent_srpm_sha256 "$manifest")" "$work/parent.src.rpm" | sha256sum -c --strict --quiet -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{SOURCEPACKAGE}' "$work/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.3-28.1 ]]
rpm2cpio "$work/parent.src.rpm" > "$work/parent.cpio"
cpio -t --quiet < "$work/parent.cpio" > "$work/paths"
awk '/^\/|(^|\/)\.\.($|\/)/{bad=1}END{exit bad}' "$work/paths"
mkdir "$output"
(cd "$output"; cpio -idm --quiet --no-absolute-filenames < "$work/parent.cpio")
parent=$output/senemos-uke-linux-kernel-mainline-unstable.spec
printf '%s  %s\n' "$(jq -er .parent_spec_sha256 "$manifest")" "$parent" | sha256sum -c --strict --quiet -
! grep -Eq '^Source9115:' "$parent"
find "$output" -maxdepth 1 -type f ! -name "${parent##*/}" -print0 | sort -z | xargs -0 sha256sum > "$work/retained.sha256"
mapfile -t assets < <(jq -er '.source_assets[].path' "$manifest")
git -C "$owner" archive --prefix=crm-rom/ HEAD "${assets[@]}" manifests/camera-crm-rom-20261115.json | tar -xf - -C "$work"
git -C "$owner" rev-parse HEAD > "$work/crm-rom/source-commit"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/uke-crm-rom.tar.xz" -C "$work" crm-rom
spec=$output/uke-kernel-migration-check.spec
awk '/^%description/{exit}/^Name:/{$0="Name: uke-kernel-migration-check"}/^Release:/{$0="Release: 116%{?dist}"}/^Summary:/{$0="Summary: Exact cumulative28 camera CRM ROM source and object qualification"}/^(Requires|Provides|Recommends|Conflicts|Obsoletes)(\([^)]*\))?:/{next}{print}' "$parent" > "$spec"
cat >> "$spec" <<'SPEC'
Source9115: uke-crm-rom.tar.xz

%description
Retain exact cumulative28 preparation, then test the powered read-only CRM ROM
parent resolver and all38 managed adapters. No CRM admission or full Image.

SPEC
awk '/^%prep$/{emit=1}/^%build$/{exit}emit{print}' "$parent" >> "$spec"
# Keep the complete original source phase; stop before production boot/Image work.
node - "$parent" "$spec" "$manifest" <<'JS'
const fs=require('fs'),crypto=require('crypto'),[input,output,manifest]=process.argv.slice(2),s=fs.readFileSync(input,'utf8');
const begin='\n%build\n',end='\nbash boot-recipe/src/boot/build-payload.sh ';
if(s.split(begin).length!==2)throw Error('Exact cumulative28 build section');
const start=s.indexOf(begin)+begin.length,stop=s.indexOf(end,start);
if(stop<start)throw Error('Cumulative28 source phase terminator missing');
const phase=s.slice(start,stop+1);
const hash=crypto.createHash('sha256').update(phase).digest('hex');
if(hash!==JSON.parse(fs.readFileSync(manifest)).parent_source_phase_sha256)throw Error('Cumulative28 complete source phase identity');
const allowed='make -s O="$ref" ARCH=arm64 LLVM=1 LLVM_IAS=1 olddefconfig';
for(const line of phase.split('\n'))if(/^\s*make\b/.test(line)&&line.trim()!==allowed)throw Error('Production make in source phase');
if(/^\s*%(install|check)\b/m.test(phase))throw Error('Production section in source phase');
fs.appendFileSync(output,phase);
JS
cat >> "$spec" <<'SPEC'
tar -xJf %{SOURCE9115}
(cd crm-rom; jq -r '.source_assets[]|.sha256+"  "+.path' manifests/camera-crm-rom-20261115.json | sha256sum -c --strict --quiet -)
bash crm-rom/src/camera/provider/apply-crm-rom733.sh "$PWD" "$PWD/crm-rom"

%build
set -o pipefail
bash crm-rom/tests/camcc-crm-rom.sh | tee %{_topdir}/crm-rom-checks.txt
bash crm-rom/tests/camcc-crm-rom-object.sh "$PWD" "$PWD/crm-rom-objects" | tee -a %{_topdir}/crm-rom-checks.txt

%install
install -d %{buildroot}%{_datadir}/%{name}
install -m644 %{_topdir}/crm-rom-checks.txt crm-rom/source-commit \
 crm-rom/manifests/camera-crm-rom-20261115.json %{buildroot}%{_datadir}/%{name}/

%check
test ! -e arch/arm64/boot/Image
test ! -e crm-rom-objects/arch/arm64/boot/Image
test ! -e crm-rom-objects/rom-adapter/rom.ko
test -s %{buildroot}%{_datadir}/%{name}/crm-rom-checks.txt

%files
%license crm-rom/LICENSES/GPL-2.0-only.txt
%{_datadir}/%{name}/*

%changelog
* Sun Nov 15 2026 Uke contributors - 7.3.3-116
- Qualify actual ROM source resolution, PLL math and read-fault refusal over unchanged cumulative28.
SPEC
sha256sum -c --strict --quiet "$work/retained.sha256"
unlink "$parent"
printf 'Complete cumulative28 source preparation retained; native ROM115 text-only qualification appended\n'

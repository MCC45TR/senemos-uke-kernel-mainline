#!/usr/bin/bash
# COPR source worker for diagnostic fixture11; independent of full release2.
set -Eeuo pipefail
[[ $# == 1 && ${UKE_COPR_SOURCE_WORKER:-} == 1 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
result=$(realpath -m "$1")
[[ ! -e $result && ! -L $result ]]
mkdir "$result"
curl -qfsSL --max-time 600 --max-filesize 314572800 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11330530/senemos-uke-linux-kernel-mainline-unstable-7.3.3-28.src.rpm -o "$result/full28.src.rpm"
curl -qfsSL --max-time 600 --max-filesize 314572800 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11331776/senemos-uke-linux-kernel-mainline-unstable-7.3.4-2.src.rpm -o "$result/full7342c.src.rpm"
printf '%s  %s\n' 74f878d9d0258893262b95252d864405fac38860e95a062434c8e688505a37e5 "$result/full28.src.rpm" \
 3d3be44a3dc0d0a7e11bb640c751e0f7c416a33685a0e085b514bb78f7ef78e2 "$result/full7342c.src.rpm" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
rpm2cpio "$result/full28.src.rpm" | cpio -i --to-stdout --quiet ./senemos-uke-linux-kernel-mainline-unstable.spec > "$work/parent.spec"
printf '%s  %s\n' f21757f6b329114b8727846afb6f495d517a8c09b0d52e856cf9713226f48631 "$work/parent.spec" | sha256sum -c --strict --quiet -
install -m644 "$owner/tests/paired-config-reference734.sh" "$result/"
cat > "$result/uke-kernel-migration-check.spec" <<'SPEC'
%global debug_package %{nil}
%global _build_id_links none
Name: uke-kernel-migration-check
Version: 7.3.4
Release: 11%{?dist}
Summary: Native paired historical configuration observations for Uke
License: GPL-2.0-only AND MIT
ExclusiveArch: aarch64
Source0: full28.src.rpm
Source1: full7342c.src.rpm
Source2: paired-config-reference734.sh
BuildRequires: rpm-build cpio
SPEC
grep '^BuildRequires:' "$work/parent.spec" >> "$result/uke-kernel-migration-check.spec"
cat >> "$result/uke-kernel-migration-check.spec" <<'SPEC'

%description
Build-only diagnostic observations from the exact successful full28 source and
failed full7342 source. Replays source preparation and resolves reference
configs without creating an Image. Historical guard failures are captured
for review and are not production, device or hardware qualification.

%prep
mkdir paired-source-work

%build
bash %{SOURCE2} %{SOURCE0} %{SOURCE1} "$PWD/paired-source-work/receipt"

%check
cd paired-source-work/receipt
sha256sum -c --strict --quiet SHA256SUMS
jq -e '.schema_version==1 and (.full_image_produced|not) and (.source_native_qualification_claimed|not) and .observations.parent.source_preparation_completed and .observations.candidate.source_preparation_completed' paired-observation.json

%install
install -d %{buildroot}%{_datadir}/uke-kernel-migration-check/paired-reference
cp -a paired-source-work/receipt/. %{buildroot}%{_datadir}/uke-kernel-migration-check/paired-reference/

%files
%{_datadir}/uke-kernel-migration-check
SPEC
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$result/uke-kernel-migration-check.spec") == uke-kernel-migration-check-7.3.4-11.fc46 ]]
printf 'Paired native config diagnostic11 source ready; full release2 remains unchanged and unqualified.\n'

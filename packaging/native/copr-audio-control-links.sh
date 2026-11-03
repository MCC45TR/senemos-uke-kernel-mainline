#!/usr/bin/env bash
# COPR-only source validation. Produces no kernel, driver, tuning or calibration.
set -Eeuo pipefail
[[ $(rpm --eval '%{_host_cpu}') == aarch64 ]]
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
mkdir -p "$stage/source/referances/audio-protection-20261103/upstream731" "$output"
cd "$owner"
git archive HEAD src/audio/acdb-graph-audit.cpp src/audio/audioreach-control-links.h \
 src/audio/prepare-control-links.sh tests/audio-acdb-contract.sh tests/audio-control-links.c \
 tests/audio-control-links-contract.sh tests/audio-control-links-integration.sh \
 patches/boot/0072-audioreach-control-links.patch LICENSE | tar -xf - -C "$stage/source"
reference=$stage/source/referances/audio-protection-20261103/upstream731
for name in audioreach.c audioreach.h topology.c; do
 curl -fLsS --max-time 45 "https://raw.githubusercontent.com/gregkh/linux/79a907609d53d5cd645b42c11550d295d43abf99/sound/soc/qcom/qdsp6/$name" -o "$reference/$name"
done
curl -fLsS --max-time 45 'https://raw.githubusercontent.com/gregkh/linux/79a907609d53d5cd645b42c11550d295d43abf99/include/uapi/sound/snd_ar_tokens.h' -o "$reference/snd_ar_tokens.h"
# Exact generic OEM file, analyzed as data in the source worker and excluded
# from the source RPM. No per-unit calibration is acquired or generated.
clang++ -std=c++20 -Wall -Wextra -Werror -fsanitize=address,undefined \
 "$stage/source/src/audio/acdb-graph-audit.cpp" -o "$stage/audit"
"$stage/audit" --self-test
curl -fLsS --max-time 45 'https://raw.githubusercontent.com/delano-git/android_vendor_xiaomi_uke/87f59fc5c2ef1ee04e494e5258853d36a3346059/proprietary/odm/etc/acdbdata/Forte/Forte_acdb_cal.acdb' -o "$stage/stock.acdb"
printf '%s  %s\n' bd3f9b8834b80c23f86241756e263e36ddf92b2b8993ed83ff71c310af952f3e "$stage/stock.acdb" | sha256sum -c -
"$stage/audit" "$stage/stock.acdb" > "$stage/metadata.txt"
awk '/^Graph|control-link/ { print }' "$stage/metadata.txt"
grep -Fq 'first=0x4040:0x80000000 second=0x49fd:0x80000000 intent=0x8001231 heap=1' "$stage/metadata.txt"
tar --sort=name --mtime=@1793664000 --owner=0 --group=0 --numeric-owner -czf \
 "$output/uke-audio-source-check-0.1.tar.gz" -C "$stage/source" .
cat > "$output/uke-audio-source-check.spec" <<'SPEC'
Name: uke-audio-source-check
Version: 0.1
Release: 2%{?dist}
Summary: Uke AudioReach source fixtures without a hardware payload
License: GPL-2.0-only
BuildArch: noarch
Source0: %{name}-%{version}.tar.gz
BuildRequires: gcc
BuildRequires: gcc-c++
BuildRequires: clang
BuildRequires: compiler-rt
BuildRequires: git
%description
Source-only AudioReach IMCL and ACDB metadata fixtures. This package installs
only a validation notice. It contains no kernel module, tuning or calibration.
%prep
%setup -q -c
%build
mkdir -p slice/sound/soc/qcom/qdsp6 slice/include/uapi/sound
cp referances/audio-protection-20261103/upstream731/{audioreach.c,audioreach.h,topology.c} slice/sound/soc/qcom/qdsp6/
cp referances/audio-protection-20261103/upstream731/snd_ar_tokens.h slice/include/uapi/sound/
bash src/audio/prepare-control-links.sh "$PWD/slice"
%check
CC=gcc bash tests/audio-control-links-contract.sh
CC=gcc bash tests/audio-control-links-integration.sh "$PWD/slice"
CXX=g++ bash tests/audio-acdb-contract.sh
%install
mkdir -p %{buildroot}%{_datadir}/doc/%{name}
printf 'COPR source fixtures only. No kernel or physical speaker protection qualification.\n' > %{buildroot}%{_datadir}/doc/%{name}/VALIDATION
%files
%doc %{_datadir}/doc/%{name}/VALIDATION
SPEC
rpmbuild -bs --define "_sourcedir $output" --define "_srcrpmdir $output" \
 "$output/uke-audio-source-check.spec"

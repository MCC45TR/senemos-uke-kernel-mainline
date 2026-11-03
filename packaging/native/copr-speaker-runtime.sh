#!/usr/bin/env bash
# COPR-only producer. Never acquires per-unit calibration or runs OEM binaries.
set -Eeuo pipefail
[[ $(rpm --eval '%{_host_cpu}') == aarch64 ]]
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
mkdir -p "$stage/source/src/audio" "$stage/source/tests" "$output"
cd "$owner"
git archive HEAD src/audio/uke-speaker-runtime.cpp src/audio/uke-fs19xx-acdb.hpp \
 src/audio/uke-speaker-calibration.hpp src/audio/uke-speaker-persist.hpp \
 src/audio/uke-fs19xx-protocol.h tests/audio-speaker-runtime.cpp \
 tests/audio-speaker-runtime-contract.sh LICENSE | tar -xf - -C "$stage/source"
# The generic OEM blob is checked in the worker, then excluded from all RPMs.
# Dependencies are supplied through COPR --script-builddeps and BuildRequires.
curl -fLsS --max-time 45 'https://raw.githubusercontent.com/delano-git/android_vendor_xiaomi_uke/87f59fc5c2ef1ee04e494e5258853d36a3346059/proprietary/odm/etc/acdbdata/Forte/Forte_acdb_cal.acdb' -o "$stage/generic.acdb"
printf '%s  %s\n' bd3f9b8834b80c23f86241756e263e36ddf92b2b8993ed83ff71c310af952f3e "$stage/generic.acdb" | sha256sum -c -
CXX=clang++ bash "$stage/source/tests/audio-speaker-runtime-contract.sh" "$stage/generic.acdb"
tar --sort=name --mtime=@1793664000 --owner=0 --group=0 --numeric-owner -czf \
 "$output/uke-speaker-runtime-0.1.tar.gz" -C "$stage/source" .
cat > "$output/uke-speaker-runtime.spec" <<'SPEC'
Name: uke-speaker-runtime
Version: 0.1
Release: 2%{?dist}
Summary: Read-only Uke speaker calibration reader and guarded DSP provisioner
License: GPL-2.0-only
Source0: %{name}-%{version}.tar.gz
BuildRequires: gcc-c++
BuildRequires: clang
BuildRequires: compiler-rt
BuildRequires: openssl-devel
BuildRequires: alsa-lib-devel
%description
Reads device-specific calibration directly from a read-only persist filesystem.
It never writes calibration files. The default check mode does not access audio
hardware. Explicit loading requires the matching protected kernel control and
separately supplied, hash-verified generic OEM DSP data. No service is enabled.
%prep
%setup -q -c
%build
%{__cxx} %{build_cxxflags} -std=c++20 src/audio/uke-speaker-runtime.cpp \
 %{build_ldflags} -lasound -lcrypto -o uke-speaker-runtime
%check
CXX=g++ bash tests/audio-speaker-runtime-contract.sh
CXX=clang++ bash tests/audio-speaker-runtime-contract.sh
%install
install -Dm755 uke-speaker-runtime %{buildroot}%{_bindir}/uke-speaker-runtime
%files
%license LICENSE
%{_bindir}/uke-speaker-runtime
SPEC
rpmbuild -bs --define "_sourcedir $output" --define "_srcrpmdir $output" \
 "$output/uke-speaker-runtime.spec"

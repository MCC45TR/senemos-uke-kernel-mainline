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
 tests/audio-speaker-runtime-contract.sh tests/audio-speaker-service-contract.sh \
 tests/audio-speaker-control-mock.cpp src/audio/systemd/uke-speaker-provision@.service \
 src/audio/udev/70-uke-speaker-provision.rules src/audio/prepare-generic-speaker-data.sh \
 src/audio/speaker-gain-preflight.sh LICENSE | tar -xf - -C "$stage/source"
# The generic OEM blob is checked in the worker, then excluded from all RPMs.
# Dependencies are supplied through COPR --script-builddeps and BuildRequires.
curl -fLsS --max-time 45 'https://raw.githubusercontent.com/delano-git/android_vendor_xiaomi_uke/87f59fc5c2ef1ee04e494e5258853d36a3346059/proprietary/odm/etc/acdbdata/Forte/Forte_acdb_cal.acdb' -o "$stage/generic.acdb"
printf '%s  %s\n' bd3f9b8834b80c23f86241756e263e36ddf92b2b8993ed83ff71c310af952f3e "$stage/generic.acdb" | sha256sum -c -
CXX=clang++ bash "$stage/source/tests/audio-speaker-runtime-contract.sh" "$stage/generic.acdb"
tar --sort=name --mtime=@1793664000 --owner=0 --group=0 --numeric-owner -czf \
 "$output/uke-speaker-runtime-0.4.tar.gz" -C "$stage/source" .
cat > "$output/uke-speaker-runtime.spec" <<'SPEC'
Name: uke-speaker-runtime
Version: 0.4
Release: 1%{?dist}
Summary: Read-only Uke speaker calibration reader and guarded DSP provisioner
License: GPL-2.0-only
Source0: %{name}-%{version}.tar.gz
BuildRequires: gcc-c++
BuildRequires: clang
BuildRequires: compiler-rt
BuildRequires: openssl-devel
BuildRequires: alsa-lib-devel
BuildRequires: jq systemd systemd-rpm-macros
Requires: systemd systemd-udev curl coreutils jq alsa-utils util-linux rpm
Provides: uke-speaker-runtime(gain-readiness-v1) = 1
%description
Reads device-specific calibration directly from a read-only persist filesystem.
It never writes calibration files. The default check mode does not access audio
hardware. Provisioning is bound to the matching board sound-card lifecycle.
The helper never starts playback. Generic OEM DSP data is acquired separately
by an explicit one-time command; no network request runs in the boot service.
%prep
%setup -q -c
%build
%{__cxx} %{build_cxxflags} -std=c++20 src/audio/uke-speaker-runtime.cpp \
 %{build_ldflags} -lasound -lcrypto -o uke-speaker-runtime
%check
CXX=g++ bash tests/audio-speaker-runtime-contract.sh
CXX=clang++ bash tests/audio-speaker-runtime-contract.sh
CXX=g++ bash tests/audio-speaker-service-contract.sh
CXX=clang++ bash tests/audio-speaker-service-contract.sh
bash -n src/audio/speaker-gain-preflight.sh
%install
install -Dm755 uke-speaker-runtime %{buildroot}%{_bindir}/uke-speaker-runtime
install -Dm755 src/audio/prepare-generic-speaker-data.sh %{buildroot}%{_libexecdir}/uke-speaker-prepare-data
install -Dm755 src/audio/speaker-gain-preflight.sh %{buildroot}%{_bindir}/uke-speaker-gain-preflight
install -Dm644 src/audio/systemd/uke-speaker-provision@.service %{buildroot}%{_unitdir}/uke-speaker-provision@.service
install -Dm644 src/audio/udev/70-uke-speaker-provision.rules %{buildroot}%{_udevrulesdir}/70-uke-speaker-provision.rules
%post
%systemd_post uke-speaker-provision@.service
%udev_rules_update
%preun
%systemd_preun uke-speaker-provision@.service
%postun
%systemd_postun uke-speaker-provision@.service
%udev_rules_update
%files
%{_libexecdir}/uke-speaker-prepare-data
%{_unitdir}/uke-speaker-provision@.service
%{_udevrulesdir}/70-uke-speaker-provision.rules
%license LICENSE
%{_bindir}/uke-speaker-runtime
%{_bindir}/uke-speaker-gain-preflight
SPEC
rpmbuild -bs --define "_sourcedir $output" --define "_srcrpmdir $output" \
 "$output/uke-speaker-runtime.spec"

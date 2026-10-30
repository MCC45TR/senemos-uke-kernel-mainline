Name: uke-control-kernel-check
Version: 2.4.0
Release: 0.2%{?dist}
Summary: Isolated source validation for Uke Control and torch ownership
License: MIT AND Apache-2.0 AND GPL-2.0-only AND (GPL-2.0-only WITH Linux-syscall-note)
Source0: %{name}-%{version}.tar.gz
ExclusiveArch: aarch64
BuildRequires: gcc-c++ make pkgconfig(libdrm) pkgconfig(libsystemd) >= 257
BuildRequires: pkgconfig(wayland-client) wayland-devel wayland-protocols-devel
BuildRequires: pkgconfig(libselinux) systemd-rpm-macros
BuildRequires: libdnf5-devel >= 5.4.6.0 pkgconfig(rpm)
BuildRequires: dbus-daemon jq selinux-policy-devel
BuildRequires: pkgconfig(jsoncpp) pkgconfig(blkid) pkgconfig(openssl)
BuildRequires: xfsprogs-devel e2fsprogs dosfstools f2fs-tools
BuildRequires: kernel-devel elfutils-libelf-devel openssl-devel libubsan
BuildRequires: util-linux coreutils diffutils
%description
Build-only validation of kernel torch ownership and Control request transport.
Contains a text receipt only. No runtime application or module is installed.
%prep
%setup -q
%build
%set_build_flags
make -j2 -C hardware/uke-control all
mkdir module
cp kernel/src/leds/leds-uke-torch.c kernel/src/leds/uke-torch-uapi.h module/
printf 'obj-m += leds-uke-torch.o\n' > module/Makefile
kbuild=$(find /usr/src/kernels -mindepth 1 -maxdepth 1 -type d | sort -V | tail -1)
test -n "$kbuild"
printf 'Official Fedora kernel headers: %s\n' "${kbuild##*/}" > kernel-build.txt
make -j2 -C "$kbuild" M="$PWD/module" modules
%check
make -j2 -C hardware/uke-control check
bash hardware/uke-control/tests/kernel-lights-source.sh
bash kernel/tests/torch-lifetime.sh
bash kernel/tests/torch-supplier.sh
cmp hardware/uke-control/shared/uke-torch.h kernel/src/leds/uke-torch-uapi.h
printf 'Native Control checks and simulated kernel fixtures passed. Module compiled against the recorded Fedora headers. No full Uke kernel, installation or physical acceptance.\n' > CHECK-RESULT.txt
%install
install -Dm644 CHECK-RESULT.txt %{buildroot}%{_datadir}/doc/%{name}/CHECK-RESULT.txt
install -m644 kernel-build.txt %{buildroot}%{_datadir}/doc/%{name}/
%files
%{_datadir}/doc/%{name}/

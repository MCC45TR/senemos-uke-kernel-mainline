%global debug_package %{nil}
Name: senemos-uke-linux-kernel-mainline-singleboot
Version: 7.2.12
Release: 1%{?dist}
Summary: Uke userdata boot profile for the matched mainline kernel
License: MIT
URL: https://github.com/MCC45TR/senemos-uke-kernel-mainline
Source0: singleboot.json
Source1: SINGLEBOOT.md
Source2: LICENSE
ExclusiveArch: aarch64
Requires: senemos-uke-linux-kernel-mainline-core = %{version}-%{release}
Requires: senemos-uke-linux-kernel-mainline-modules = %{version}-%{release}
Requires: senemos-uke-linux-kernel-mainline-dtbs = %{version}-%{release}
Requires: senemos-uke-linux-kernel-mainline-boot = %{version}-%{release}
Requires: uke-installation-profile >= 0.1.0-30
Provides: senemos-uke-linux-kernel-mainline = %{version}-%{release}
Conflicts: senemos-uke-linux-kernel-mainline < %{version}-%{release}
Conflicts: senemos-uke-linux-kernel-mainline > %{version}-%{release}

%description
Selects the userdata boot container from the same signed mainline kernel tuple.
The common Image, modules and DTBs are shared with the linux partition profile;
they are not rebuilt or duplicated. The image composer consumes the selection.
Installation performs no partition write or reboot. Automatic userdata slot
updates and fallback remain unqualified and must stay disabled.

%prep
%build
%install
install -Dm644 %{SOURCE0} %{buildroot}%{_datadir}/senemos/uke/singleboot.json
install -Dm644 %{SOURCE1} %{buildroot}%{_datadir}/doc/%{name}/SINGLEBOOT.md
install -Dm644 %{SOURCE2} %{buildroot}%{_datadir}/licenses/%{name}/LICENSE
install -d %{buildroot}%{_prefix}/lib/senemos
ln -s kernel-updates/%{version}-1/userdata.img %{buildroot}%{_prefix}/lib/senemos/default-boot.img

%check
test "$(readlink %{buildroot}%{_prefix}/lib/senemos/default-boot.img)" = kernel-updates/%{version}-1/userdata.img

%files
%doc %{_datadir}/doc/%{name}/SINGLEBOOT.md
%license %{_datadir}/licenses/%{name}/LICENSE
%{_datadir}/senemos/uke/singleboot.json
%{_prefix}/lib/senemos/default-boot.img

%changelog
* Wed Oct 21 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-17
- Select the shared release-17 bundle with the guarded updater contract.
- Retain metadata-only installation and explicit physical activation.

* Tue Oct 20 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-16
- Select the exact shared release-16 firewall and root-policy bundle.
- Preserve explicit activation and matched rollback requirements.

* Tue Oct 20 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-15
- Select the exact shared release-15 bundle without rebuilding the kernel.
- Match the metadata package license to its supplied MIT license file.

* Tue Oct 20 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-14
- Select userdata with the exact shared mainline kernel tuple; perform no boot writes.

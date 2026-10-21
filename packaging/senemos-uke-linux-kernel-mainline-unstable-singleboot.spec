%global debug_package %{nil}
Name: senemos-uke-linux-kernel-mainline-unstable-singleboot
Version: 7.3.0
Release: 1%{?dist}
Summary: Uke userdata profile for the matched unstable Linux 7.3 kernel
License: MIT
URL: https://github.com/MCC45TR/senemos-uke-kernel-mainline
Source0: singleboot.json
Source1: SINGLEBOOT.md
Source2: LICENSE
ExclusiveArch: aarch64
Requires: senemos-uke-linux-kernel-mainline-unstable = %{version}-%{release}
Requires: senemos-uke-linux-kernel-mainline-unstable-core = %{version}-%{release}
Requires: senemos-uke-linux-kernel-mainline-unstable-modules = %{version}-%{release}
Requires: senemos-uke-linux-kernel-mainline-unstable-dtbs = %{version}-%{release}
Requires: senemos-uke-linux-kernel-mainline-unstable-boot = %{version}-%{release}

%description
Selects the userdata boot container from the same signed mainline kernel tuple.
The common Image, modules and DTBs are shared with the unstable linux profile.
The separate descriptor and boot symlink preserve the ordinary profile default.
Installation performs no partition write or reboot. Automatic userdata slot
updates and fallback remain unqualified and must stay disabled.

%prep
%build
%install
install -Dm644 %{SOURCE0} %{buildroot}%{_datadir}/senemos/uke/unstable-singleboot.json
install -Dm644 %{SOURCE1} %{buildroot}%{_datadir}/doc/%{name}/SINGLEBOOT.md
install -Dm644 %{SOURCE2} %{buildroot}%{_datadir}/licenses/%{name}/LICENSE
install -d %{buildroot}%{_prefix}/lib/senemos
ln -s kernel-updates/%{version}-1-unstable/userdata.img %{buildroot}%{_prefix}/lib/senemos/unstable-default-boot.img

%check
test "$(readlink %{buildroot}%{_prefix}/lib/senemos/unstable-default-boot.img)" = kernel-updates/%{version}-1-unstable/userdata.img

%files
%doc %{_datadir}/doc/%{name}/SINGLEBOOT.md
%license %{_datadir}/licenses/%{name}/LICENSE
%{_datadir}/senemos/uke/unstable-singleboot.json
%{_prefix}/lib/senemos/unstable-default-boot.img

%changelog
* Wed Oct 21 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-1
- Select the exact unstable userdata image through a separate descriptor.
- Preserve the ordinary boot default and perform no activation.

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

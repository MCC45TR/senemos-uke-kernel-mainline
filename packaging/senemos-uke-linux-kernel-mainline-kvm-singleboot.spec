%global debug_package %{nil}
%global kernel_abi %{version}-%{senemos_build_release}-kvm
Name: senemos-uke-linux-kernel-mainline-kvm-singleboot
Version: 7.2.12
%if "%{version}" == "7.2.11"
%global senemos_build_release 1
%else
%global senemos_build_release 1
%endif
Release: %{senemos_build_release}%{?dist}
Summary: Matched Uke KVM userdata profile metadata
License: MIT
URL: https://github.com/MCC45TR/senemos-uke-kernel-mainline
Source0: kvm-singleboot.json
Source1: KVM-SINGLEBOOT.md
Source2: LICENSE
ExclusiveArch: aarch64
Requires: senemos-uke-linux-kernel-mainline-kvm = %{version}-%{release}
Requires: senemos-uke-linux-kernel-mainline-kvm-core = %{version}-%{release}
Requires: senemos-uke-linux-kernel-mainline-kvm-modules = %{version}-%{release}
Requires: senemos-uke-linux-kernel-mainline-kvm-dtbs = %{version}-%{release}
Requires: senemos-uke-linux-kernel-mainline-kvm-boot = %{version}-%{release}

%description
Selects the matching KVM F2FS userdata container through an auditable descriptor.
The ordinary boot default remains separate. Installation performs no activation.

%prep
%build
%install
install -Dm644 %{SOURCE0} %{buildroot}%{_datadir}/senemos/uke/kvm-singleboot.json
install -Dm644 %{SOURCE1} %{buildroot}%{_datadir}/doc/%{name}/KVM-SINGLEBOOT.md
install -Dm644 %{SOURCE2} %{buildroot}%{_datadir}/licenses/%{name}/LICENSE
install -d %{buildroot}%{_prefix}/lib/senemos
ln -s kernel-updates/%{kernel_abi}/userdata.img %{buildroot}%{_prefix}/lib/senemos/kvm-default-boot.img
%check
test "$(readlink %{buildroot}%{_prefix}/lib/senemos/kvm-default-boot.img)" = kernel-updates/%{kernel_abi}/userdata.img
%files
%doc %{_datadir}/doc/%{name}/KVM-SINGLEBOOT.md
%license %{_datadir}/licenses/%{name}/LICENSE
%{_datadir}/senemos/uke/kvm-singleboot.json
%{_prefix}/lib/senemos/kvm-default-boot.img

Name: uke-super-root-source-check
Version: 0.1
Release: 3%{?dist}
Summary: Native source qualification for an explicit Uke rescue root role
License: GPL-2.0-only AND MIT
URL: https://github.com/MCC45TR/senemos-uke-kernel-mainline
Source0: uke-super-root-source.tar.xz
Source1: senemos-uke-boot-recipe.tar.xz
Source2: uke-super-tools.tar.xz
Source3: measure-initrd.sh
ExclusiveArch: aarch64
BuildRequires: gcc-c++ clang compiler-rt libasan libubsan binutils coreutils
BuildRequires: android-tools dracut systemd systemd-udev f2fs-tools kmod
BuildRequires: util-linux findutils gawk grep sed gzip cpio xz jq rpm ripgrep
%global debug_package %{nil}
%global __os_install_post %{nil}

%description
Text-only native compiler and sanitizer receipts. No kernel Image, runtime
module, device activation, root mapping, key release or resume operation.

%prep
%setup -q -n super-root
sha256sum -c --strict --quiet SHA256SUMS
test "$(uname -m)" = aarch64
test ! -e /etc/senemos/kernel-update.conf

%build
ulimit -c 0
mkdir -p work/legacy/tests work/legacy/src/boot work/headers
cp parent-root-selector.h work/legacy/src/boot/uke-root-selector.h
cp parent-root-selector-test.cpp work/legacy/tests/root-selector-contract.cpp
cp parent-root-selector.h work/headers/uke-root-selector.h
cp uke-super-root-selector.h work/headers/
: > native-results.txt
for compiler in g++ clang++;do
 for mode in plain sanitized;do
  flags=''
  test "$mode" != sanitized || flags='-fsanitize=address,undefined -fno-omit-frame-pointer'
  "$compiler" -std=c++20 -O2 -g -UNDEBUG -Wall -Wextra -Werror $flags \
   work/legacy/tests/root-selector-contract.cpp -o work/legacy-check
  readelf -h work/legacy-check | grep -F AArch64
  timeout 15s work/legacy-check
  "$compiler" -std=c++20 -O2 -g -UNDEBUG -Wall -Wextra -Werror $flags \
   -Iwork/headers super-root734.cpp -o work/rescue-check
  readelf -h work/rescue-check | grep -F AArch64
  timeout 15s work/rescue-check >> native-results.txt
 done
done
cat native-results.txt
mkdir initrd-inputs
tar -xJf %{SOURCE1} -C initrd-inputs
tar -xJf %{SOURCE2} -C initrd-inputs
bash %{SOURCE3} "$PWD/initrd-inputs/boot-recipe" "$PWD/initrd-inputs/super-tools" "$PWD/initrd-measurement"

%install
install -d %{buildroot}%{_datadir}/%{name}
install -m644 native-results.txt SHA256SUMS source-commit %{buildroot}%{_datadir}/%{name}/
install -m644 initrd-measurement/measurement.json %{buildroot}%{_datadir}/%{name}/
install -Dm644 initrd-inputs/super-tools/LICENSE %{buildroot}%{_licensedir}/%{name}/super-tools-MIT

%check
test "$(grep -c '^PASS: super root' native-results.txt)" = 4
test ! -e arch/arm64/boot/Image

%files
%license LICENSE
%{_licensedir}/%{name}/super-tools-MIT
%{_datadir}/%{name}/

%changelog
* Mon Nov 16 2026 Uke contributors - 0.1-3
- Supply the original initramfs privacy audit's required ripgrep build tool.

* Mon Nov 16 2026 Uke contributors - 0.1-2
- Retain all parser modes and measure the original Fedora super-tool initramfs closure; no new boot hooks.

* Mon Nov 16 2026 Uke contributors - 0.1-1
- Check the retained normal parser and bounded read-only rescue role; no hardware acceptance.

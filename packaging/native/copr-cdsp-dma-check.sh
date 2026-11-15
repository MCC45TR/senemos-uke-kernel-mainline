#!/usr/bin/bash
# Independent source/real AArch64 object qualification, never a kernel delivery.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
[[ ! -e $output || (-d $output && -z $(find "$output" -mindepth 1 -maxdepth 1 -print -quit)) ]]
mkdir -p "$output"
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
assets=(src/cdsp/0002-fastrpc-dma-before-session.patch src/cdsp/apply-dma-admission.sh
 src/cdsp/fastrpc-cb-probe731-fixed.h tests/fixtures/fastrpc-cb-probe731-original.h
 tests/fixtures/fastrpc-cb-dma.c tests/fastrpc-cb-dma-contract.sh tests/fastrpc-cb-dma-qualify.sh
 patches/boot/0023-fastrpc-own-coherent-dma-handle.patch tests/fastrpc-buffer-lifetime-contract.sh
 docs/CDSP-KERNEL-DMA-ADMISSION.md)
git -C "$owner" archive --prefix=cdsp-addon/ HEAD "${assets[@]}" | tar -xf - -C "$stage"
printf '%s\n' "$(git -C "$owner" rev-parse HEAD)" > "$stage/cdsp-addon/source-commit"
tar --sort=name --mtime="@$(git -C "$owner" show -s --format=%ct HEAD)" --owner=0 --group=0 --numeric-owner \
 -cJf "$output/uke-cdsp-dma-addon.tar.xz" -C "$stage" cdsp-addon
curl -q -fLsS --retry 2 --max-time 600 https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.3.1.tar.xz -o "$output/linux-7.3.1.tar.xz"
printf '%s  %s\n' fa595aad93734f829c963c2a90ef7c3673224fd7fdae7b49406e397cde2de231 "$output/linux-7.3.1.tar.xz" | sha256sum -c --strict -
cat > "$output/uke-cdsp-kernel-check.spec" <<'SPEC'
Name: uke-cdsp-kernel-check
Version: 7.3.1
Release: 2%{?dist}
Summary: Native source and object evidence for FastRPC DMA admission
License: GPL-2.0-only
Source0: linux-7.3.1.tar.xz
Source1: uke-cdsp-dma-addon.tar.xz
BuildRequires: gcc gcc-c++ clang compiler-rt llvm lld make bc flex bison openssl-devel elfutils-libelf-devel perl git-core
ExclusiveArch: aarch64
%global debug_package %{nil}

%description
Text evidence only. Compiles the actual Linux FastRPC callbacks and a complete
AArch64 translation unit with the retained coherent-buffer lifetime patch.
Not a full cumulative kernel, runtime package, firmware or physical compute result.

%prep
echo 'fa595aad93734f829c963c2a90ef7c3673224fd7fdae7b49406e397cde2de231  %{SOURCE0}' | sha256sum -c -
%setup -q -n linux-7.3.1
tar -xJf %{SOURCE1}
git init --quiet
git apply --check cdsp-addon/patches/boot/0023-fastrpc-own-coherent-dma-handle.patch
git apply cdsp-addon/patches/boot/0023-fastrpc-own-coherent-dma-handle.patch
bash cdsp-addon/src/cdsp/apply-dma-admission.sh "$PWD"
sha256sum drivers/misc/fastrpc.c > before-repeat.sha256
bash cdsp-addon/src/cdsp/apply-dma-admission.sh "$PWD"
sha256sum -c before-repeat.sha256

%build
set -o pipefail
bash cdsp-addon/tests/fastrpc-cb-dma-qualify.sh "$PWD/drivers/misc/fastrpc.c" | tee checks.txt
CXX=clang++ bash cdsp-addon/tests/fastrpc-buffer-lifetime-contract.sh "$PWD/drivers/misc/fastrpc.c" | tee -a checks.txt
make ARCH=arm64 LLVM=1 defconfig
scripts/config --module QCOM_FASTRPC
make ARCH=arm64 LLVM=1 olddefconfig
grep -Fx 'CONFIG_QCOM_FASTRPC=m' .config
make ARCH=arm64 LLVM=1 KCFLAGS=-Werror -j4 drivers/misc/fastrpc.o
llvm-readelf -h drivers/misc/fastrpc.o | tee -a checks.txt
llvm-readelf -h drivers/misc/fastrpc.o | grep -E 'Machine:.*AArch64'
llvm-nm --defined-only drivers/misc/fastrpc.o | grep -E '[[:space:]]fastrpc_cb_probe$'
sha256sum drivers/misc/fastrpc.c drivers/misc/fastrpc.o .config | tee -a checks.txt
printf 'Independent defconfig object only; no cumulative Image or target acceptance\n' | tee -a checks.txt

%install
install -Dm644 checks.txt %{buildroot}%{_docdir}/%{name}/checks.txt
install -Dm644 cdsp-addon/source-commit %{buildroot}%{_docdir}/%{name}/source-commit
install -Dm644 cdsp-addon/docs/CDSP-KERNEL-DMA-ADMISSION.md %{buildroot}%{_docdir}/%{name}/scope.md

%files
%doc %{_docdir}/%{name}/checks.txt
%doc %{_docdir}/%{name}/source-commit
%doc %{_docdir}/%{name}/scope.md

%changelog
* Fri Nov 06 2026 Uke Linux contributors <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-2
- Include the Clang sanitizer runtime in the native source check.
- Preserve actual callback, fault/mutant and complete AArch64 object gates.
SPEC
rpmbuild -bs --define "_sourcedir $output" --define "_srcrpmdir $output" "$output/uke-cdsp-kernel-check.spec"

#!/usr/bin/env bash
# COPR-only actual-code fixtures and AArch64 translation units.
set -Eeuo pipefail
[[ $(rpm --eval '%{_host_cpu}') == aarch64 ]]
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
mkdir -p "$output" "$stage/receipt"
for compiler in gcc clang; do
    CC=$compiler bash "$owner/tests/fm19511-contract.sh"
    CC=$compiler bash "$owner/tests/fm19511-pm-contract.sh"
    CC=$compiler bash "$owner/tests/ir-spi-contract.sh" "$owner/src/infrared/ir-spi-uke.c"
done
CC=clang CFLAGS='-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer' \
    bash "$owner/tests/fm19511-contract.sh"
CC=clang CFLAGS='-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer' \
    bash "$owner/tests/fm19511-pm-contract.sh"
CC=clang CFLAGS='-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer' \
    bash "$owner/tests/ir-spi-contract.sh" "$owner/src/infrared/ir-spi-uke.c"
curl -fLsS --retry 2 --max-time 300 \
    https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.3.1.tar.xz -o "$stage/linux.tar.xz"
printf '%s  %s\n' fa595aad93734f829c963c2a90ef7c3673224fd7fdae7b49406e397cde2de231 "$stage/linux.tar.xz" | sha256sum -c -
tar -xJf "$stage/linux.tar.xz" -C "$stage"
kernel=$stage/linux-7.3.1
git -C "$kernel" init -q
bash "$owner/src/nfc/prepare-source.sh" "$kernel"
mkdir -p "$stage/objects"
cp "$owner/packaging/native/native.config" "$stage/objects/.config"
make -s -C "$kernel" O="$stage/objects" ARCH=arm64 LLVM=1 olddefconfig prepare modules_prepare
make -s -C "$kernel" O="$stage/objects" ARCH=arm64 LLVM=1 -j4 \
    drivers/misc/fm19511-uke.o drivers/media/rc/ir-spi.o
llvm-readelf -h "$stage/objects/drivers/misc/fm19511-uke.o" | grep -F AArch64
llvm-readelf -h "$stage/objects/drivers/media/rc/ir-spi.o" | grep -F AArch64
printf 'Actual-code GCC/Clang and ASan/UBSan fixtures and AArch64 kernel objects pass. No full kernel or RF/optical acceptance.\n' > "$stage/receipt/VALIDATION"
git -C "$owner" rev-parse HEAD > "$stage/receipt/SOURCE-COMMIT"
tar -czf "$output/uke-nfc-ir-kernel-check-0.1.tar.gz" -C "$stage/receipt" .
cat > "$output/uke-nfc-ir-kernel-check.spec" <<'SPEC'
Name: uke-nfc-ir-kernel-check
Version: 0.1
Release: 1%{?dist}
Summary: Source receipt for Uke NFC tag and infrared kernel checks
License: GPL-2.0-only
BuildArch: noarch
Source0: %{name}-%{version}.tar.gz
%description
Targeted source validation receipt. Contains no device payload or activation.
%prep
%setup -q -c
%install
mkdir -p %{buildroot}%{_datadir}/doc/%{name}
install -m644 VALIDATION SOURCE-COMMIT %{buildroot}%{_datadir}/doc/%{name}/
%files
%doc %{_datadir}/doc/%{name}/VALIDATION
%doc %{_datadir}/doc/%{name}/SOURCE-COMMIT
SPEC
rpmbuild -bs --define "_sourcedir $output" --define "_srcrpmdir $output" \
    "$output/uke-nfc-ir-kernel-check.spec"

#!/usr/bin/env bash
# Compile only on COPR. No native compiler or fixture runs on the tablet.
set -Eeuo pipefail
[[ $(rpm --eval '%{_host_cpu}') == aarch64 ]]
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
mkdir -p "$output" "$stage/receipt"
curl -fLsS --retry 2 --max-time 300 \
    https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.3.1.tar.xz -o "$stage/linux.tar.xz"
printf '%s  %s\n' fa595aad93734f829c963c2a90ef7c3673224fd7fdae7b49406e397cde2de231 "$stage/linux.tar.xz" | sha256sum -c -
tar -xJf "$stage/linux.tar.xz" -C "$stage"
kernel=$stage/linux-7.3.1
git -C "$kernel" init -q
for patch in "$owner/patches/7.3.0/0014-cliffs-wpss-proxy-regulators.patch" \
    "$owner/patches/7.3.0/0020-cliffs-adsp-pas.patch" \
    "$owner/patches/boot/0026-cliffs-proxy-and-pas-stop-ownership.patch" \
    "$owner/patches/boot/0027-remoteproc-early-stop.patch" \
    "$owner/patches/boot/0028-cliffs-proxy-per-rail-ownership.patch" \
    "$owner/patches/boot/0041-rproc-retain-failed-startup.patch" \
    "$owner/patches/boot/0060-cliffs-cdsp-start-ownership.patch"; do
    git -C "$kernel" apply --check "$patch"
    git -C "$kernel" apply "$patch"
done
bash "$owner/src/pogo/prepare-source.sh" "$kernel"
for compiler in g++ clang++; do
    CXX=$compiler bash "$owner/tests/cdsp-start-ownership-contract.sh" "$kernel/drivers/remoteproc/qcom_q6v5_pas.c"
    CXX=$compiler bash "$owner/tests/pas-stop-ownership-contract.sh" "$kernel/drivers/remoteproc/qcom_q6v5_pas.c"
    CXX=$compiler bash "$owner/tests/rproc-early-stop-contract.sh" "$kernel/drivers/remoteproc/remoteproc_core.c"
    CXX=$compiler bash "$owner/tests/rproc-start-stop-retention-contract.sh" "$kernel/drivers/remoteproc/remoteproc_core.c"
done
bash "$owner/tests/wpss-proxy-contract.sh" "$kernel/drivers/remoteproc/qcom_q6v5_pas.c"
for compiler in gcc clang; do
    CC=$compiler CFLAGS= bash "$owner/tests/nanosic-protocol-contract.sh"
done
CC=clang CFLAGS='-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer' \
    bash "$owner/tests/nanosic-protocol-contract.sh"
mkdir "$stage/objects"
cp "$owner/packaging/native/native.config" "$stage/objects/.config"
cat "$owner/configs/cdsp-pogo.config" >> "$stage/objects/.config"
make -s -C "$kernel" O="$stage/objects" ARCH=arm64 LLVM=1 olddefconfig prepare modules_prepare
make -s -C "$kernel" O="$stage/objects" ARCH=arm64 LLVM=1 -j4 KCFLAGS=-Werror \
    drivers/remoteproc/qcom_q6v5_pas.o drivers/remoteproc/remoteproc_core.o drivers/hid/hid-nanosic-uke.o
for path in drivers/remoteproc/qcom_q6v5_pas.o drivers/remoteproc/remoteproc_core.o drivers/hid/hid-nanosic-uke.o; do
    llvm-readelf -h "$stage/objects/$path" | grep -F AArch64
done
printf 'Actual-code ownership and protocol fixtures plus AArch64 kernel objects pass. No full kernel, device activation, firmware or accessory acceptance.\n' > "$stage/receipt/VALIDATION"
git -C "$owner" rev-parse HEAD > "$stage/receipt/SOURCE-COMMIT"
tar -czf "$output/uke-cdsp-pogo-check-0.1.tar.gz" -C "$stage/receipt" .
cat > "$output/uke-cdsp-pogo-check.spec" <<'SPEC'
Name: uke-cdsp-pogo-check
Version: 0.1
Release: 1%{?dist}
Summary: Uke CDSP and pogo kernel source validation receipt
License: GPL-2.0-only
BuildArch: noarch
Source0: %{name}-%{version}.tar.gz
%description
Source validation receipt; contains no hardware payload or firmware.
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
    "$output/uke-cdsp-pogo-check.spec"

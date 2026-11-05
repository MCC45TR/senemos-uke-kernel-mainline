#!/usr/bin/env bash
# COPR only: isolated driver callbacks and real7.3.1 object; no kernel candidate.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
out=$(realpath -m "${1:?COPR result directory}")
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
mkdir -p "$out" "$stage/receipt"
bash "$owner/packaging/native/refuse-published-release.sh" uke-pogo-kernel-check 0.1-2
curl -q -fLsS --retry 2 --max-time 600 https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.3.1.tar.xz -o "$stage/linux.tar.xz"
printf '%s  %s\n' fa595aad93734f829c963c2a90ef7c3673224fd7fdae7b49406e397cde2de231 "$stage/linux.tar.xz" | sha256sum -c --strict -
tar -xJf "$stage/linux.tar.xz" -C "$stage"
kernel=$stage/linux-7.3.1
bash "$owner/src/pogo/prepare-source.sh" "$kernel"
for compiler in gcc clang; do
 for test in nanosic-protocol nanosic-lifecycle nanosic-backlight nanosic-power nanosic-hid; do
  CC=$compiler CFLAGS= bash "$owner/tests/$test-contract.sh" | tee -a "$stage/receipt/checks.txt"
  CC=$compiler CFLAGS='-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer' \
    bash "$owner/tests/$test-contract.sh" | tee -a "$stage/receipt/checks.txt"
 done
done
mkdir "$stage/objects"
cp "$owner/packaging/native/native.config" "$stage/objects/.config"
printf '\nCONFIG_HID_NANOSIC_UKE=m\n' >> "$stage/objects/.config"
bash "$kernel/scripts/config" --file "$stage/objects/.config" --set-str INITRAMFS_SOURCE ''
make -s -C "$kernel" O="$stage/objects" ARCH=arm64 LLVM=1 olddefconfig prepare modules_prepare
make -s -C "$kernel" O="$stage/objects" ARCH=arm64 LLVM=1 KCFLAGS=-Werror -j4 drivers/hid/hid-nanosic-uke.o
llvm-readelf -h "$stage/objects/drivers/hid/hid-nanosic-uke.o" | grep -E 'Machine:.*AArch64'
llvm-nm --defined-only "$stage/objects/drivers/hid/hid-nanosic-uke.o" | grep -E '[[:space:]]uke_nano_backlight_work$'
sha256sum "$kernel/drivers/hid/hid-nanosic-uke.c" "$stage/objects/drivers/hid/hid-nanosic-uke.o" >> "$stage/receipt/checks.txt"
git -C "$owner" rev-parse HEAD > "$stage/receipt/source-commit"
tar -czf "$out/uke-pogo-kernel-check-0.1.tar.gz" -C "$stage/receipt" .
cat > "$out/uke-pogo-kernel-check.spec" <<'SPEC'
Name: uke-pogo-kernel-check
Version: 0.1
Release: 2%{?dist}
Summary: Uke pogo HID, LED and power callback/object qualification receipt
License: GPL-2.0-only
BuildArch: noarch
Source0: %{name}-%{version}.tar.gz
%description
Text-only native callback and AArch64 driver-object qualification. No Image,
module, OEM firmware, kernel revision or device operation is produced.
%prep
%setup -q -c
%install
install -Dm644 checks.txt %{buildroot}%{_docdir}/%{name}/checks.txt
install -m644 source-commit %{buildroot}%{_docdir}/%{name}/source-commit
%files
%{_docdir}/%{name}/checks.txt
%{_docdir}/%{name}/source-commit
%changelog
* Thu Nov 05 2026 Uke contributors - 0.1-2
- Validate exact OEM touchpad geometry and hybrid contact capacity as well.
SPEC
rpmbuild -bs --define "_sourcedir $out" --define "_srcrpmdir $out" "$out/uke-pogo-kernel-check.spec"

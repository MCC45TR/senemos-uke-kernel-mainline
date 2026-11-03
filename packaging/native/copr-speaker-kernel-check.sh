#!/usr/bin/env bash
# COPR-only kernel translation-unit check. Installs no kernel or driver.
set -Eeuo pipefail
[[ $(rpm --eval '%{_host_cpu}') == aarch64 ]]
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
mkdir -p "$output" "$stage/receipt"
curl -fLsS --retry 2 --max-time 300 'https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.3.1.tar.xz' -o "$stage/linux.tar.xz"
printf '%s  %s\n' fa595aad93734f829c963c2a90ef7c3673224fd7fdae7b49406e397cde2de231 "$stage/linux.tar.xz" | sha256sum -c -
tar -xJf "$stage/linux.tar.xz" -C "$stage"
kernel=$stage/linux-7.3.1
git -C "$kernel" init -q
while IFS= read -r patch; do
    git -C "$kernel" apply --check "$owner/$patch"
    git -C "$kernel" apply "$owner/$patch"
done < <(jq -r '.patches[].path' "$owner/manifests/native-linux-7.3.1.json")
git -C "$kernel" apply "$owner/patches/boot/0058-fs19xx-current-workqueue.patch"
bash "$owner/src/audio/prepare-control-links.sh" "$kernel"
bash "$owner/src/audio/prepare-fs19xx-runtime.sh" "$kernel"
mkdir -p "$stage/objects"
cp "$owner/packaging/native/native.config" "$stage/objects/.config"
make -s -C "$kernel" O="$stage/objects" ARCH=arm64 LLVM=1 olddefconfig prepare modules_prepare
make -s -C "$kernel" O="$stage/objects" ARCH=arm64 LLVM=1 -j"$(nproc)" \
 sound/soc/qcom/qdsp6/q6apm.o sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o \
 sound/soc/qcom/qdsp6/audioreach.o sound/soc/qcom/qdsp6/topology.o \
 sound/soc/qcom/qdsp6/q6apm-lpass-dais.o sound/soc/codecs/fs19xx.o
bash "$owner/src/audio/build-protected-topology.sh" "$stage/protected.conf"
alsatplg -c "$stage/protected.conf" -o "$stage/protected.bin"
alsatplg -d "$stage/protected.bin" -o "$stage/decoded.conf"
grep -Fq 'spk.fs.rx' "$stage/decoded.conf"
grep -Fq 'spk.fs.tx' "$stage/decoded.conf"
grep -Fq 'spk.vi.source' "$stage/decoded.conf"
printf 'Targeted kernel objects and protected ALSA topology compile. No full kernel, device or physical protection acceptance.\n' > "$stage/receipt/VALIDATION"
git -C "$owner" rev-parse HEAD > "$stage/receipt/SOURCE-COMMIT"
tar -czf "$output/uke-speaker-kernel-check-0.1.tar.gz" -C "$stage/receipt" .
cat > "$output/uke-speaker-kernel-check.spec" <<'SPEC'
Name: uke-speaker-kernel-check
Version: 0.1
Release: 1%{?dist}
Summary: Source receipt for the Uke protected speaker kernel objects
License: GPL-2.0-only
BuildArch: noarch
Source0: %{name}-%{version}.tar.gz
%description
Receipt for targeted COPR kernel compilation. Contains no kernel, modules,
topology, tuning, per-unit calibration or automatic activation mechanism.
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
 "$output/uke-speaker-kernel-check.spec"

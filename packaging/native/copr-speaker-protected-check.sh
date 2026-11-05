#!/usr/bin/env bash
# Source/object rehearsal on complete12204; never emits a kernel or target action.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
revision=${2:-1}
[[ $revision =~ ^[1-9][0-9]*$ ]]
bash "$owner/packaging/native/refuse-published-release.sh" uke-speaker-protected-check "7.3.1-$revision"
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
mkdir -p "$output" "$stage/unpacked"
[[ $(curl -fLsS --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11263248 | jq -er .state) == succeeded ]]
curl -fLsS --retry 2 --max-time 600 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11263248/senemos-uke-linux-kernel-mainline-unstable-7.3.1-12204.src.rpm -o "$stage/parent.rpm"
printf '%s  %s\n' e54174d1c281ec3b90bfc2ad8a1d11566bcdb1f197208df441b7bf89802247c3 "$stage/parent.rpm" | sha256sum -c -
rpmkeys --checksig --nosignature --verbose "$stage/parent.rpm"
rpm2cpio "$stage/parent.rpm" > "$stage/parent.cpio"
cpio -t --quiet < "$stage/parent.cpio" | awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}'
(cd "$output"; cpio -idm --quiet --no-absolute-filenames < "$stage/parent.cpio")
parent=$output/senemos-uke-linux-kernel-mainline-unstable.spec
native=senemos-native-profile-7.3.1.tar.xz
find "$output" -maxdepth 1 -type f ! -name "$native" -print0 | sort -z | xargs -0 sha256sum > "$stage/retained"
tar -xJf "$output/$native" -C "$stage/unpacked"
profile=$stage/unpacked/native-profile
jq -e '.kernel_release=="7.3.1-12204-unstable" and .source_commit=="de1bdf9ab531d772a8c02847c51b01ed4ffcd42f"' "$profile/source-composition.json" >/dev/null
git -C "$owner" fetch -q --depth 1 origin 33a5dc574401b67472e9bea65e5ff7084635f601
commit=$(git -C "$owner" rev-parse HEAD)
bash "$owner/packaging/native/overlay-speaker-protected-layer.sh" "$profile" "$commit"
sha256sum "$profile/SHA256SUMS" "$profile/prepare.sh" "$profile/source-composition.json" > "$stage/repeat"
bash "$owner/packaging/native/overlay-speaker-protected-layer.sh" "$profile" "$commit"
sha256sum -c --strict "$stage/repeat"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$native" -C "$stage/unpacked" native-profile
cp "$parent" "$output/production-spec.txt"
printf '%s\n' "$commit" > "$output/speaker-protected-source-commit.txt"
awk '/^%check$/ {inside=1;next} /^%[a-z]/ {inside=0}
 inside && /bash native-profile\/tests\/(audio-|microphone-gain-contract|kernel-audio-policy-contract)/ {print}' "$parent" > "$output/inherited-audio-checks.sh"
[[ $(wc -l < "$output/inherited-audio-checks.sh") == 24 ]]
! grep -Eq '^Source9[0-2]:' "$parent"
spec=$output/uke-speaker-protected-check.spec
cat > "$spec" <<SPEC
%global debug_package %{nil}
%global _build_id_links none
%global krel 7.3.1-12204-unstable
%global _uke_out %{_topdir}/native-kernel-out
Name: uke-speaker-protected-check
Version: 7.3.1
Release: $revision%{?dist}
Summary: Protected223 audio source and native objects on complete cumulative12204
License: GPL-2.0-only AND MIT AND BSD-3-Clause
SourceLicense: GPL-2.0-only AND MIT AND BSD-3-Clause AND GPL-3.0-or-later AND Apache-2.0
ExclusiveArch: aarch64
SPEC
awk '/^Source[0-9]+:|^BuildRequires:/ {print}' "$parent" >> "$spec"
cat >> "$spec" <<'SPEC'
Source90: production-spec.txt
Source91: speaker-protected-source-commit.txt
Source92: inherited-audio-checks.sh
%description
Retains the complete12204 baseline and all peer contributions. Adds only the
missing codec protection hunk, exact protected graph and both supplier DT flags.
Authenticates the existing observer and223 writer, and compiles real AArch64
objects. Synthetic fault checks do not establish physical transducer limits.
Text receipts only. No Image, final module, calibration, playback or boot change.
SPEC
awk '/^%prep$/ {inside=1} /^%build$/ {exit} inside {print}' "$parent" >> "$spec"
cat >> "$spec" <<'SPEC'
%build
export CC=clang CXX=clang++ ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-12204-unstable
ulimit -c 0
bash native-profile/packaging/native/check-speaker-inclusion.sh "$PWD" prepared-protected
bash -euo pipefail %{SOURCE92}
sed 's/CC=clang /CC=gcc /g; s/CXX=clang++ /CXX=g++ /g' %{SOURCE92} > %{_topdir}/inherited-gcc.sh
CC=gcc CXX=g++ bash -euo pipefail %{_topdir}/inherited-gcc.sh
for compiler in gcc clang; do
 CC=$compiler bash native-profile/tests/audio-speaker-safety-contract.sh "$PWD"
 CC=$compiler bash native-profile/tests/audio-pcm-formats-contract.sh "$PWD"
 CC=$compiler bash native-profile/tests/audio-speaker-state-store-contract.sh "$PWD"
done
cp sound/soc/codecs/fs19xx.c %{_topdir}/protected-codec.c
sed -i 's/if (volume > FS19XX_VOL_MAX)/if (volume > 255)/' sound/soc/codecs/fs19xx.c
if CC=clang bash native-profile/tests/audio-speaker-safety-contract.sh "$PWD" > %{_topdir}/gain-mutant.log 2>&1; then exit 1; fi
grep -Fq 'Assertion' %{_topdir}/gain-mutant.log
cp %{_topdir}/protected-codec.c sound/soc/codecs/fs19xx.c
sed -i 's/fs19xx->require_protection \&\& !q6apm_fs19xx_running()/(q6apm_fs19xx_running(), false)/' sound/soc/codecs/fs19xx.c
if CC=clang bash native-profile/tests/audio-speaker-safety-contract.sh "$PWD" > %{_topdir}/guard-mutant.log 2>&1; then exit 1; fi
grep -Fq 'Assertion' %{_topdir}/guard-mutant.log
cp %{_topdir}/protected-codec.c sound/soc/codecs/fs19xx.c
bash native-profile/packaging/native/check-speaker-inclusion.sh "$PWD" prepared-protected
mkdir -p %{_uke_out}
sha256sum native-profile/native.config sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c > %{_topdir}/retained-inputs.sha256
cp native-profile/native.config %{_uke_out}/.config
make -s O=%{_uke_out} olddefconfig prepare modules_prepare
make -s O=%{_uke_out} KCFLAGS=-Werror -j4 sound/soc/codecs/fs19xx.o sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o sound/soc/qcom/qdsp6/audioreach.o sound/soc/qcom/qdsp6/q6apm-dai.o
ld.lld -r %{_uke_out}/sound/soc/codecs/fs19xx.o -o %{_topdir}/linked-codec.o
ld.lld -r %{_uke_out}/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o -o %{_topdir}/linked-runtime.o
for symbol in fs19xx_unmute_work fs19xx_volume_put fs19xx_protection_event; do
 bash native-profile/tests/audio-speaker-observer-code.sh %{_uke_out}/sound/soc/codecs/fs19xx.o %{_topdir}/linked-codec.o "$symbol"
done
bash native-profile/tests/audio-speaker-observer-code.sh %{_uke_out}/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o %{_topdir}/linked-runtime.o
strings %{_uke_out}/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o | grep -Fx 'xiaomi,fs19xx-protected'
sha256sum -c --strict %{_topdir}/retained-inputs.sha256
sha256sum %{_uke_out}/sound/soc/codecs/fs19xx.o %{_uke_out}/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o %{_uke_out}/sound/soc/qcom/qdsp6/audioreach.o %{_uke_out}/sound/soc/qcom/qdsp6/q6apm-dai.o > %{_topdir}/speaker-protected-objects.sha256
printf 'Complete12204 peer source/config retained. Protected223 DT for both suppliers, exact calibrated DSP/VI graph, raw capture, observer and actual codec safeguards checked. All24 inherited calls, GCC/Clang safety/PCM/state tests and gain/guard mutants pass. Four native objects and partial-link instruction comparisons pass. No Image/final module or target operation; physical protection and243 remain unqualified.\n' > %{_topdir}/speaker-protected-checks.txt
%install
mkdir -p %{buildroot}%{_datadir}/doc/%{name}
install -m644 %{_topdir}/speaker-protected-checks.txt %{_topdir}/speaker-protected-objects.sha256 %{SOURCE90} %{SOURCE91} native-profile/source-composition.json %{buildroot}%{_datadir}/doc/%{name}/
%files
%{_datadir}/doc/%{name}/
SPEC
sha256sum -c --strict --quiet "$stage/retained"
unlink "$parent"
[[ $(rpmspec --target aarch64 -q --srpm --qf '%{NAME}' "$spec") == uke-speaker-protected-check ]]
printf '%s\n' 'Protected223 source/object rehearsal prepared; no full kernel revision reserved.'

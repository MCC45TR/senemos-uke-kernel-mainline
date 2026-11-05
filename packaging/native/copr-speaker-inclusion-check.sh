#!/usr/bin/env bash
# Independent source/object receipt on exact12203. Never builds a full kernel.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
revision=${2:-1}
[[ $revision =~ ^[1-9][0-9]*$ ]]
bash "$owner/packaging/native/refuse-published-release.sh" uke-speaker-inclusion-check "7.3.1-$revision"
stage=$(mktemp -d)
cleanup() {
 if [[ -d $stage/observer ]]; then git -C "$owner" worktree remove --force "$stage/observer"; fi
 find "$stage" -depth -delete
}
trap cleanup EXIT
mkdir -p "$output" "$stage/unpacked" "$stage/negative"
[[ $(curl -fLsS --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11262313 | jq -er .state) == succeeded ]]
# Exact raw source-worker SRPM, unsigned, pinned by the qualified12203 audit.
curl -fLsS --retry 2 --max-time 600 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11262313/senemos-uke-linux-kernel-mainline-unstable-7.3.1-12203.src.rpm -o "$stage/parent.rpm"
printf '%s  %s\n' db31b8a612b3caf5aedbfb681eb1140688072cb6dffaa104946877c65d341b57 "$stage/parent.rpm" | sha256sum -c -
rpmkeys --checksig --nosignature --verbose "$stage/parent.rpm"
rpm2cpio "$stage/parent.rpm" > "$stage/parent.cpio"
cpio -t --quiet < "$stage/parent.cpio" | awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}'
(cd "$output"; cpio -idm --quiet --no-absolute-filenames < "$stage/parent.cpio")
parent=$output/senemos-uke-linux-kernel-mainline-unstable.spec
native=senemos-native-profile-7.3.1.tar.xz
find "$output" -maxdepth 1 -type f ! -name "$native" -print0 | sort -z | xargs -0 sha256sum > "$stage/retained"
tar -xJf "$output/$native" -C "$stage/unpacked"
profile=$stage/unpacked/native-profile
jq -e '.kernel_release=="7.3.1-12203-unstable" and .source_commit=="45d8355e366e6b75e43f441ca99b517302adf522" and
 .speaker_legacy_fixture_layer_commit=="f05c32a879b9c56abe3531365f95b85684af4510" and
 .speaker_state_observer_layer_commit==null' "$profile/source-composition.json" >/dev/null
cp -a "$profile" "$stage/negative/native-profile"
negative=$stage/negative/native-profile
install -Dm644 "$owner/manifests/speaker-required-inputs-20261105.json" "$negative/manifests/speaker-required-inputs-20261105.json"
if bash "$owner/packaging/native/check-speaker-inclusion.sh" "$stage/negative" prepared > "$stage/negative.log" 2>&1; then exit 1; fi
grep -Fq 'required observer contribution is missing or changed' "$stage/negative.log"
# A forged label with the original runtime still fails its actual source digest.
jq '. + {speaker_state_observer_layer_commit:"13fb0ff522531924c0e96f81cef59d7c64b93eb8",speaker_running_state_requires_guard:true}' "$negative/source-composition.json" > "$stage/forged"
cat "$stage/forged" > "$negative/source-composition.json"
(cd "$negative"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
if bash "$owner/packaging/native/check-speaker-inclusion.sh" "$stage/negative" prepared > "$stage/negative.log" 2>&1; then exit 1; fi
grep -Fq 'declared contribution does not match its source bytes' "$stage/negative.log"
cp "$profile/src/audio/uke-fs19xx-runtime.c" "$output/previous-speaker-runtime.c"
git -C "$owner" fetch -q --depth 1 origin 13fb0ff522531924c0e96f81cef59d7c64b93eb8
git -C "$owner" worktree add -q --detach "$stage/observer" 13fb0ff522531924c0e96f81cef59d7c64b93eb8
bash "$stage/observer/packaging/native/overlay-speaker-state-observer.sh" "$profile" 13fb0ff522531924c0e96f81cef59d7c64b93eb8
commit=$(git -C "$owner" rev-parse HEAD)
bash "$owner/packaging/native/overlay-speaker-inclusion-gate.sh" "$profile" "$commit"
sha256sum "$profile/SHA256SUMS" "$profile/prepare.sh" "$profile/source-composition.json" > "$stage/repeat"
bash "$owner/packaging/native/overlay-speaker-inclusion-gate.sh" "$profile" "$commit"
sha256sum -c --strict "$stage/repeat"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$native" -C "$stage/unpacked" native-profile
cp "$parent" "$output/production-spec.txt"
printf '%s\n' "$commit" > "$output/speaker-inclusion-source-commit.txt"
awk '/^%check$/ {inside=1;next} /^%[a-z]/ {inside=0}
 inside && /bash native-profile\/tests\/(audio-|microphone-gain-contract|kernel-audio-policy-contract)/ {print}' "$parent" > "$output/inherited-audio-checks.sh"
[[ $(wc -l < "$output/inherited-audio-checks.sh") == 24 ]]
! grep -Eq '^Source9[0-3]:' "$parent"
spec=$output/uke-speaker-inclusion-check.spec
cat > "$spec" <<SPEC
%global debug_package %{nil}
%global _build_id_links none
%global krel 7.3.1-12203-unstable
%global _uke_out %{_topdir}/native-kernel-out
Name: uke-speaker-inclusion-check
Version: 7.3.1
Release: $revision%{?dist}
Summary: Required speaker source and linked-observer inclusion on cumulative12203
License: GPL-2.0-only AND MIT AND BSD-3-Clause
SourceLicense: GPL-2.0-only AND MIT AND BSD-3-Clause AND GPL-3.0-or-later AND Apache-2.0
ExclusiveArch: aarch64
SPEC
awk '/^Source[0-9]+:|^BuildRequires:/ {print}' "$parent" >> "$spec"
cat >> "$spec" <<'SPEC'
Source90: production-spec.txt
Source91: speaker-inclusion-source-commit.txt
Source92: previous-speaker-runtime.c
Source93: inherited-audio-checks.sh
%description
Retain exact complete12203 source/config/boot/DT and every peer layer. Add the
qualified read-only observer and a mandatory pre-Image inclusion check. Missing
or falsely declared contributions are refused. Actual observer instruction
comparison detects an old linked body; no object/module is loaded or executed.
Text receipts only; no full kernel, final module, boot change or private data.
SPEC
awk '/^%prep$/ {inside=1} /^%build$/ {exit} inside {print}' "$parent" >> "$spec"
cat >> "$spec" <<'SPEC'
%build
export CC=clang CXX=clang++ ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-12203-unstable
ulimit -c 0
cp sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c %{_topdir}/new-runtime.c
cp %{SOURCE92} sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c
if bash native-profile/packaging/native/check-speaker-inclusion.sh "$PWD" prepared > %{_topdir}/stale-prepared.log 2>&1; then exit 1; fi
grep -Fq 'prepared runtime does not match the qualified source' %{_topdir}/stale-prepared.log
cp %{_topdir}/new-runtime.c sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c
bash native-profile/packaging/native/check-speaker-inclusion.sh "$PWD" prepared
bash -euo pipefail %{SOURCE93}
sed 's/CC=clang /CC=gcc /g; s/CXX=clang++ /CXX=g++ /g' %{SOURCE93} > %{_topdir}/inherited-gcc.sh
CC=gcc CXX=g++ bash -euo pipefail %{_topdir}/inherited-gcc.sh
CC=gcc UKE_AUDIO_TEST_MUTANTS=1 bash native-profile/tests/audio-controls-only-contract.sh sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c
CC=clang bash native-profile/tests/audio-controls-only-contract.sh sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c
mkdir -p %{_uke_out}
sha256sum native-profile/native.config sound/soc/codecs/fs19xx.c > %{_topdir}/retained-audio.sha256
cp native-profile/native.config %{_uke_out}/.config
make -s O=%{_uke_out} olddefconfig prepare modules_prepare
make -s O=%{_uke_out} KCFLAGS=-Werror -j4 sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o
cp %{_uke_out}/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o %{_topdir}/new-runtime.o
ld.lld -r %{_topdir}/new-runtime.o -o %{_topdir}/new-linked.o
bash native-profile/tests/audio-speaker-observer-code.sh %{_topdir}/new-runtime.o %{_topdir}/new-linked.o
sha256sum %{_topdir}/new-runtime.o %{_topdir}/new-linked.o > %{_topdir}/compared-inputs.sha256
cp %{SOURCE92} sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c
make -s O=%{_uke_out} KCFLAGS=-Werror -j4 sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o
ld.lld -r %{_uke_out}/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o -o %{_topdir}/old-linked.o
if bash native-profile/tests/audio-speaker-observer-code.sh %{_topdir}/new-runtime.o %{_topdir}/old-linked.o > %{_topdir}/old-linked.log 2>&1; then exit 1; fi
grep -Fq 'linked observer differs from the freshly compiled runtime object' %{_topdir}/old-linked.log
cp %{_topdir}/new-runtime.c sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c
make -s O=%{_uke_out} KCFLAGS=-Werror -j4 sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o
bash native-profile/tests/audio-speaker-observer-code.sh %{_uke_out}/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o %{_topdir}/new-linked.o
sha256sum -c --strict %{_topdir}/compared-inputs.sha256
sha256sum -c --strict %{_topdir}/retained-audio.sha256
printf 'Exact12203 retained. Required89/f05/13 observer verified before Image; missing, falsely labeled and stale prepared contributions refused. Both288-case read callbacks, all24 inherited audio calls and actual inactive runtime/mutants pass. Native AArch64 object/partial-link observer matches; old linked observer refused and compared inputs unchanged. Graph inactive, ABI1, gain223; no full kernel or physical qualification.\n' > %{_topdir}/speaker-inclusion-checks.txt
%install
mkdir -p %{buildroot}%{_datadir}/doc/%{name}
install -m644 %{_topdir}/speaker-inclusion-checks.txt %{SOURCE90} %{SOURCE91} native-profile/source-composition.json native-profile/manifests/speaker-required-inputs-20261105.json %{buildroot}%{_datadir}/doc/%{name}/
%files
%{_datadir}/doc/%{name}/
SPEC
sha256sum -c --strict --quiet "$stage/retained"
unlink "$parent"
[[ $(rpmspec --target aarch64 -q --srpm --qf '%{NAME}' "$spec") == uke-speaker-inclusion-check ]]
printf '%s\n' 'Exact12203 observer inclusion check prepared; no kernel revision or target action.'

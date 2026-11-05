#!/usr/bin/env bash
# COPR-only replay of every audio check from the exact failed cumulative source.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
revision=${2:-1}
mode=${3:-fixtures}
case "$mode" in
 fixtures) check_name=uke-speaker-fixtures-check;;
 state) check_name=uke-speaker-state-check;;
 *) exit 2;;
esac
[[ $revision =~ ^[1-9][0-9]*$ ]]
bash "$owner/packaging/native/refuse-published-release.sh" "$check_name" "7.3.1-$revision"
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
mkdir -p "$output" "$stage/unpacked"
[[ $(curl -fLsS --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11262085 | jq -er .state) == failed ]]
# Pin the raw unsigned source-worker SRPM on the remote worker. It has no signature.
# Never download this complete archive to the tablet.
curl -fLsS --retry 2 --max-time 600 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11262085/senemos-uke-linux-kernel-mainline-unstable-7.3.1-12202.src.rpm -o "$stage/parent.rpm"
printf '%s  %s\n' b0ca5002c0a99c750e514a5ee18ee403ce51c69a82ac0adcd2c2f0bc97d8317a "$stage/parent.rpm" | sha256sum -c -
[[ $(rpm -qp --qf '%{SHA256HEADER}' "$stage/parent.rpm") == 86c2c5570807f4e9983928bee628e7d35672648e41b83d57419ea1a970b2ef3a ]]
[[ $(rpm -qp --qf '%{PAYLOADSHA256}' "$stage/parent.rpm") == 26af7066f2b5624c45d0f4e959e792f75fd898ffde4f6d3de9741dab373155f0 ]]
rpmkeys --checksig --nosignature --verbose "$stage/parent.rpm"
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/parent.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.1-12202 ]]
rpm2cpio "$stage/parent.rpm" > "$stage/parent.cpio"
cpio -t --quiet < "$stage/parent.cpio" | awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}'
(cd "$output"; cpio -idm --quiet --no-absolute-filenames < "$stage/parent.cpio")
parent=$output/senemos-uke-linux-kernel-mainline-unstable.spec
native=senemos-native-profile-7.3.1.tar.xz
[[ -f $parent ]]
find "$output" -maxdepth 1 -type f ! -name "$native" -print0 | sort -z | xargs -0 sha256sum > "$stage/retained-sources"
tar -xJf "$output/$native" -C "$stage/unpacked"
profile=$stage/unpacked/native-profile
jq -e '.kernel_release=="7.3.1-12202-unstable"' "$profile/source-composition.json" >/dev/null
mkdir -p "$stage/old/tests"
for name in audio-graph-lifetime-contract.sh audio-readiness-contract.sh; do
 cp "$profile/tests/$name" "$stage/old/tests/$name"
done
commit=$(git -C "$owner" rev-parse HEAD)
# Wrong input, unsafe admission metadata and incomplete ledger must refuse without mutation.
cp "$profile/SHA256SUMS" "$stage/original-ledger"
cp "$profile/source-composition.json" "$stage/original-composition"
cp "$profile/native.config" "$stage/native.config"
printf '\n' >> "$profile/native.config"
if bash "$owner/packaging/native/overlay-speaker-legacy-fixtures.sh" "$profile" "$commit" > "$stage/refusal" 2>&1; then exit 1; fi
cat "$stage/native.config" > "$profile/native.config"
jq '.speaker_protection_graph_admitted=true' "$stage/original-composition" > "$profile/source-composition.json"
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
if bash "$owner/packaging/native/overlay-speaker-legacy-fixtures.sh" "$profile" "$commit" > "$stage/refusal" 2>&1; then exit 1; fi
cat "$stage/original-composition" > "$profile/source-composition.json"
printf '\n' >> "$profile/tests/audio-graph-lifetime-contract.sh"
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
if bash "$owner/packaging/native/overlay-speaker-legacy-fixtures.sh" "$profile" "$commit" > "$stage/refusal" 2>&1; then exit 1; fi
cat "$stage/old/tests/audio-graph-lifetime-contract.sh" > "$profile/tests/audio-graph-lifetime-contract.sh"
cat "$stage/original-ledger" > "$profile/SHA256SUMS"
bash "$owner/packaging/native/overlay-speaker-legacy-fixtures.sh" "$profile" "$commit"
sha256sum "$profile/SHA256SUMS" "$profile/source-composition.json" > "$stage/repeat"
bash "$owner/packaging/native/overlay-speaker-legacy-fixtures.sh" "$profile" "$commit"
sha256sum -c --strict "$stage/repeat"
if [[ $mode == state ]]; then
 cp "$profile/src/audio/uke-fs19xx-runtime.c" "$output/previous-speaker-runtime.c"
 for compiler in gcc clang; do
  CC=$compiler bash "$owner/tests/audio-speaker-state-read-contract.sh"
  if CC=$compiler bash "$owner/tests/audio-speaker-state-read-contract.sh" "$output/previous-speaker-runtime.c" > "$stage/baseline.log" 2>&1; then exit 1; fi
  grep -Fq 'Status overstates RUNNING after the actual guard is closed' "$stage/baseline.log"
  grep -Fq 'Assertion' "$stage/baseline.log"
 done
 cp "$profile/SHA256SUMS" "$stage/state-ledger"
 cp "$profile/source-composition.json" "$stage/state-composition"
 printf '\n' >> "$profile/src/audio/uke-fs19xx-runtime.c"
 if bash "$owner/packaging/native/overlay-speaker-state-observer.sh" "$profile" "$commit" > "$stage/state-refusal" 2>&1; then exit 1; fi
 (cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
 if bash "$owner/packaging/native/overlay-speaker-state-observer.sh" "$profile" "$commit" > "$stage/state-refusal" 2>&1; then exit 1; fi
 cat "$output/previous-speaker-runtime.c" > "$profile/src/audio/uke-fs19xx-runtime.c"
 jq '.speaker_protection_graph_admitted=true' "$stage/state-composition" > "$profile/source-composition.json"
 (cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
 if bash "$owner/packaging/native/overlay-speaker-state-observer.sh" "$profile" "$commit" > "$stage/state-refusal" 2>&1; then exit 1; fi
 cat "$stage/state-composition" > "$profile/source-composition.json"
 cat "$stage/state-ledger" > "$profile/SHA256SUMS"
 bash "$owner/packaging/native/overlay-speaker-state-observer.sh" "$profile" "$commit"
 sha256sum "$profile/SHA256SUMS" "$profile/source-composition.json" > "$stage/state-repeat"
 bash "$owner/packaging/native/overlay-speaker-state-observer.sh" "$profile" "$commit"
 sha256sum -c --strict "$stage/state-repeat"
fi
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$native" -C "$stage/unpacked" native-profile
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/old-audio-fixtures.tar.xz" -C "$stage/old" .
cp "$parent" "$output/production-spec.txt"
printf '%s\n' "$commit" > "$output/speaker-fixtures-source-commit.txt"
# These are the actual inherited calls, including argument lists, rather than a substitute inventory.
awk '/^%check$/ {inside=1;next} /^%[a-z]/ {inside=0}
 inside && /bash native-profile\/tests\/(audio-|microphone-gain-contract|kernel-audio-policy-contract)/ {print}' "$parent" > "$output/inherited-audio-checks.sh"
[[ $(wc -l < "$output/inherited-audio-checks.sh") == 24 ]]
awk '/^%prep$/ {inside=1} /^%build$/ {exit} inside {print}' "$parent" > "$stage/production-prep"
[[ $(grep -c '^%prep$' "$stage/production-prep") == 1 ]]
! grep -Eq '^Source9[0-4]:' "$parent"
spec=$output/$check_name.spec
cat > "$spec" <<SPEC
%global debug_package %{nil}
%global _build_id_links none
%global krel 7.3.1-12202-unstable
%global _uke_out %{_topdir}/native-kernel-out
Name: $check_name
Version: 7.3.1
Release: $revision%{?dist}
Summary: All inherited audio fixtures on the exact cumulative Uke source
License: GPL-2.0-only AND MIT AND BSD-3-Clause
SourceLicense: GPL-2.0-only AND MIT AND BSD-3-Clause AND GPL-3.0-or-later AND Apache-2.0
ExclusiveArch: aarch64
SPEC
awk '/^Source[0-9]+:|^BuildRequires:/ {print}' "$parent" >> "$spec"
cat >> "$spec" <<'SPEC'
Source90: production-spec.txt
Source91: speaker-fixtures-source-commit.txt
Source92: inherited-audio-checks.sh
Source93: old-audio-fixtures.tar.xz
SPEC
if [[ $mode == state ]]; then
 cat >> "$spec" <<'SPEC'
Source94: previous-speaker-runtime.c
%description
Replay exact cumulative12202 preparation and all inherited audio fixtures.
Correct only the read-only status callback: a closed guard cannot report
RUNNING from cached graph state. The old callback is a failing assertion control.
ABI1, graph admission disabled, gain223 and every other production function stay
unchanged. Text receipts only; no Image, modules, calibration or target action.
SPEC
else
 cat >> "$spec" <<'SPEC'
%description
Replays every inherited audio check after exact cumulative12202 preparation.
Only two test harnesses and their common dependency mock change. Production
kernel, preparation hooks, DT, topology, boot inputs and gain223 are retained.
Contains text receipts only; no Image, modules, boot selection or calibration.
SPEC
fi
cat "$stage/production-prep" >> "$spec"
cat >> "$spec" <<'SPEC'
%build
export CC=clang CXX=clang++
ulimit -c 0
jq -e '.speaker_protection_graph_admitted==false and .speaker_gain_ceiling==223 and .speaker_physical_protection_qualified==false' native-profile/source-composition.json
cmp native-profile/src/audio/uke-fs19xx-runtime.c sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c
grep -Fx 'CFLAGS_uke-fs19xx-runtime.o += -DUKE_FS19XX_CONTROLS_ONLY' sound/soc/qcom/qdsp6/Makefile
bash -euo pipefail %{SOURCE92}
sed 's/CC=clang /CC=gcc /g; s/CXX=clang++ /CXX=g++ /g' %{SOURCE92} > %{_topdir}/inherited-audio-gcc.sh
CC=gcc CXX=g++ bash -euo pipefail %{_topdir}/inherited-audio-gcc.sh
mkdir -p %{_topdir}/old-audio-fixtures
tar -xJf %{SOURCE93} -C %{_topdir}/old-audio-fixtures
for fixture in audio-graph-lifetime-contract audio-readiness-contract; do
 if CC=clang CXX=clang++ bash %{_topdir}/old-audio-fixtures/tests/$fixture.sh "$PWD" > %{_topdir}/$fixture-original.log 2>&1; then
  echo "Original inherited fixture unexpectedly accepted new dependencies" >&2; exit 1
 fi
 grep -Eq "(undeclared|not declared).*q6apm_fs19xx_|q6apm_fs19xx_.*(undeclared|not declared)" %{_topdir}/$fixture-original.log
done
# A real old failing harness inside the complete dispatcher must stop the job.
# This catches a wrapper that accidentally returns only the last fixture status.
sed 's#native-profile/tests/audio-graph-lifetime-contract.sh#%{_topdir}/old-audio-fixtures/tests/audio-graph-lifetime-contract.sh#' %{SOURCE92} > %{_topdir}/inherited-audio-negative.sh
if CC=clang CXX=clang++ bash -euo pipefail %{_topdir}/inherited-audio-negative.sh "$PWD" > %{_topdir}/inherited-audio-negative.log 2>&1; then
 echo 'Complete audio dispatcher ignored the original graph fixture failure' >&2; exit 1
fi
grep -Eq "(undeclared|not declared).*q6apm_fs19xx_|q6apm_fs19xx_.*(undeclared|not declared)" %{_topdir}/inherited-audio-negative.log
CC=gcc UKE_AUDIO_TEST_MUTANTS=1 bash native-profile/tests/audio-controls-only-contract.sh sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c
CC=clang bash native-profile/tests/audio-controls-only-contract.sh sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c
CC=gcc bash native-profile/tests/audio-speaker-state-store-contract.sh .
CC=clang bash native-profile/tests/audio-speaker-state-store-contract.sh .
printf 'Complete cumulative12202 preparation retained. All24 original audio check calls pass with GCC/Clang, both old harnesses reproduce missing dependencies, actual inactive runtime/admission/mutants and state-store pass. Production source and gain223 unchanged. No kernel/target/physical qualification.\n' > %{_topdir}/speaker-fixtures-checks.txt
%install
mkdir -p %{buildroot}%{_datadir}/doc/%{name}
install -m644 %{_topdir}/speaker-fixtures-checks.txt %{SOURCE90} %{SOURCE91} %{SOURCE92} native-profile/source-composition.json %{buildroot}%{_datadir}/doc/%{name}/
%files
%{_datadir}/doc/%{name}/
SPEC
if [[ $mode == state ]]; then
 awk '
 /^Summary:/ {$0="Summary: Read-only speaker state bound to its actual guard"}
 /^%build$/ {
  print
  print "for compiler in gcc clang; do"
  print " CC=$compiler bash native-profile/tests/audio-speaker-state-read-contract.sh sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c"
  print " if CC=$compiler bash native-profile/tests/audio-speaker-state-read-contract.sh %{SOURCE94} > %{_topdir}/previous-speaker-state.log 2>&1; then exit 1; fi"
  print " grep -Fq '\''Status overstates RUNNING after the actual guard is closed'\'' %{_topdir}/previous-speaker-state.log"
  print " grep -Fq Assertion %{_topdir}/previous-speaker-state.log"
  print "done"
  next
 }
 /^printf '\''Complete cumulative12202/ {next}
 /^%install$/ {
  print "export ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-12202-unstable"
  print "mkdir -p %{_uke_out}"
  print "sha256sum native-profile/native.config sound/soc/codecs/fs19xx.c > %{_topdir}/state-observer-retained.sha256"
  print "cp native-profile/native.config %{_uke_out}/.config"
  print "make -s O=%{_uke_out} olddefconfig prepare modules_prepare"
  print "make -s O=%{_uke_out} KCFLAGS=-Werror -j4 sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o"
  print "llvm-readelf -h %{_uke_out}/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o | grep AArch64"
  print "sha256sum -c --strict %{_topdir}/state-observer-retained.sha256"
  print "printf '\''Actual observer: close interleaving and288 guard/cache cases pass GCC/Clang; old callback rejected by assertions. All24 inherited audio calls, inactive runtime/mutants/state-store and native AArch64 runtime object pass. Only read-only getter changes; graph false, ABI1, gain223. No kernel/target/physical protection qualification.\\n'\'' > %{_topdir}/speaker-fixtures-checks.txt"
 }
 {print}
 ' "$spec" > "$stage/state.spec"
 cat "$stage/state.spec" > "$spec"
fi
sha256sum -c --strict --quiet "$stage/retained-sources"
unlink "$parent"
[[ $(rpmspec --target aarch64 -q --srpm --qf '%{NAME}' "$spec") == "$check_name" ]]
printf '%s\n' 'Independent exact cumulative audio fixture replay prepared; no full kernel or target action.'

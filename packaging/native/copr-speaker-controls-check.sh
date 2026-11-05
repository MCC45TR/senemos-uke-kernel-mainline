#!/usr/bin/env bash
# Independent cumulative source/object receipt. Never produces a kernel package.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
revision=${2:-1}
[[ $revision =~ ^[1-9][0-9]*$ ]]
bash "$owner/packaging/native/refuse-published-release.sh" uke-speaker-controls-check "7.3.1-$revision"
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
mkdir -p "$output" "$stage/unpacked"
CC=gcc UKE_AUDIO_TEST_MUTANTS=1 bash "$owner/tests/audio-controls-only-contract.sh"
CC=clang bash "$owner/tests/audio-controls-only-contract.sh"
[[ $(curl -fLsS --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11261868 | jq -er .state) == succeeded ]]
curl -fLsS --retry 2 --max-time 600 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11261868/uke-ssc-transaction-check-7.3.1-1.src.rpm -o "$stage/parent.rpm"
[[ $(rpm -qp --qf '%{SHA256HEADER}' "$stage/parent.rpm") == ec88f94b2f52c0ad4582aee48b5509da2c390de65b265a20e4b10c44074ab39e ]]
[[ $(rpm -qp --qf '%{PAYLOADSHA256}' "$stage/parent.rpm") == 566e2096f0cb9fc2c046b8478f53d39a6eaaa47c45faec101028432f5660f9c1 ]]
rpmkeys --checksig --nosignature --verbose "$stage/parent.rpm"
rpm2cpio "$stage/parent.rpm" > "$stage/parent.cpio"
cpio -t --quiet < "$stage/parent.cpio" | awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}'
(cd "$output";cpio -idm --quiet --no-absolute-filenames < "$stage/parent.cpio")
parent=$output/uke-ssc-transaction-check.spec
native=senemos-native-profile-7.3.1.tar.xz
boot=senemos-uke-boot-recipe.tar.xz
find "$output" -maxdepth 1 -type f ! -name "${parent##*/}" ! -name "$native" -print0 | sort -z | xargs -0 sha256sum > "$stage/retained-sources"
tar -xJf "$output/$native" -C "$stage/unpacked"
profile=$stage/unpacked/native-profile
jq -e '.kernel_release=="7.3.1-12101-unstable" and .queued_kernel_layer==1 and
 .o82_memory_layer==1 and .gmu_irq_owned_acknowledgement and
 .camera_geometry_three_argument_pad_api and .ssc_qmi_transaction_id_returns_id' "$profile/source-composition.json" >/dev/null
commit=$(git -C "$owner" rev-parse HEAD)
# Test refusal before mutation, then exact application/repeat on real cumulative data.
cp "$profile/SHA256SUMS" "$stage/ledger"
printf '\n' >> "$profile/native.config"
if bash "$owner/packaging/native/overlay-speaker-controls-only.sh" "$profile" "$commit" > "$stage/refusal.log" 2>&1; then exit 1; fi
truncate -s -1 "$profile/native.config"
cmp "$stage/ledger" "$profile/SHA256SUMS"
bash "$owner/packaging/native/overlay-speaker-controls-only.sh" "$profile" "$commit"
sha256sum "$profile/SHA256SUMS" "$profile/prepare.sh" "$profile/source-composition.json" > "$stage/repeat"
bash "$owner/packaging/native/overlay-speaker-controls-only.sh" "$profile" "$commit"
sha256sum -c --strict "$stage/repeat"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$native" -C "$stage/unpacked" native-profile
printf '%s\n' "$commit" > "$output/speaker-controls-source-commit.txt"
[[ $(grep -c '^Source12:' "$parent") == 0 ]]
spec=$output/uke-speaker-controls-check.spec
awk -v revision="$revision" '
 /^Name:/ {$0="Name: uke-speaker-controls-check"}
 /^Release:/ {$0="Release: "revision"%{?dist}"}
 /^Summary:/ {$0="Summary: Cumulative Uke speaker controls with inactive protection admission"}
 /^%description$/ {
  print "Source12: speaker-controls-source-commit.txt\n\n%description"
  print "Retain complete12101 plus qualified touch, geometry, GMU, memory/v5 and SSC."
  print "Add Uke provisioning controls with compile-time-disabled graph admission."
  print "Legacy amplifier source, DT, topology, UCM, config and boot inputs stay exact."
  print "Only text receipts are packaged; no kernel, module or boot selection."
  skip=1;next
 }
 /^%prep$/ {skip=0}
 skip {next}
 /^%install$/ {
  print "bash native-profile/tests/audio-controls-only-contract.sh sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c"
  print "CC=gcc UKE_AUDIO_TEST_MUTANTS=1 bash native-profile/tests/audio-controls-only-contract.sh sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c"
  print "CC=clang bash native-profile/tests/audio-controls-only-contract.sh sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c"
  print "CC=gcc bash native-profile/tests/audio-speaker-state-store-contract.sh ."
  print "CC=clang bash native-profile/tests/audio-speaker-state-store-contract.sh ."
  print "sha256sum %{_uke_out}/.config sound/soc/codecs/fs19xx.c > %{_topdir}/audio-retained-effective.sha256"
  print "export LOCALVERSION=-12101-unstable"
  print "make -s ARCH=arm64 LLVM=1 LLVM_IAS=1 O=%{_uke_out} KCFLAGS=-Werror -j4 sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o sound/soc/qcom/qdsp6/q6apm.o sound/soc/qcom/qdsp6/audioreach.o sound/soc/qcom/qdsp6/topology.o sound/soc/qcom/qdsp6/q6apm-dai.o"
  print "sha256sum -c --strict %{_topdir}/audio-retained-effective.sha256"
  print "llvm-readelf -h %{_uke_out}/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o | grep AArch64"
  print "! strings %{_uke_out}/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o | grep -F xiaomi,fs19xx-protected"
  print "printf '\''Speaker controls: full12101/touch/geometry/GMU/memory-v5/SSC retained; inactive callbacks, config, amplifier source and native AArch64 objects pass; no DT/topology/UCM change.\\n'\'' >> %{_topdir}/o82-memory-cumulative-checks.txt"
 }
 /^install -m644 %{SOURCE11} / {sub(/%{SOURCE11}/,"%{SOURCE12}")}
 {print}
' "$parent" > "$spec"
sha256sum -c --strict --quiet "$stage/retained-sources"
unlink "$parent"
[[ $(rpmspec --target aarch64 -q --srpm --qf '%{NAME}' "$spec") == uke-speaker-controls-check ]]
printf '%s\n' 'Independent cumulative audio control/object check prepared; no kernel revision or target operation.'

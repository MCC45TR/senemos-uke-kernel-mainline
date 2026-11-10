#!/usr/bin/bash
# Focused COPR-only proof over the admitted full12 source; no runtime package.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 1 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "$1")
manifest=$owner/manifests/pcm-surround-20261110.json
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
curl -qfsSL --retry 2 --max-time 240 "$(jq -er .parent_srpm_url "$manifest")" -o "$work/parent.rpm"
printf '%s  %s\n' "$(jq -er .parent_srpm_sha256 "$manifest")" "$work/parent.rpm" | sha256sum -c --strict --quiet -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$work/parent.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.3-12 ]]
rpm2cpio "$work/parent.rpm" | cpio -t --quiet > "$work/paths"
awk '/^\/|(^|\/)\.\.($|\/)/{bad=1}END{exit bad}' "$work/paths"
mkdir "$output"
rpm2cpio "$work/parent.rpm" | (cd "$output";cpio -idm --quiet --no-absolute-filenames)
full=$output/senemos-uke-linux-kernel-mainline-unstable.spec
printf '%s  %s\n' "$(jq -er .parent_spec_sha256 "$manifest")" "$full" | sha256sum -c --strict --quiet -
tar -xJf "$output/senemos-native-profile-7.3.3.tar.xz" -C "$work"
profile=$work/native-profile
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
jq -e '.source_commit=="b14c66405258832ccf92ba9a46cfceb03f635755" and .kernel_release=="7.3.3-12-unstable" and .speaker_gain_ceiling==223' "$profile/source-composition.json" >/dev/null
printf '%s  %s\n' "$(jq -er .parent_format_fixture_sha256 "$manifest")" "$profile/tests/audio-pcm-formats-contract.sh" | sha256sum -c --strict --quiet -
install -m644 "$profile/source-composition.json" "$profile/pcm-parent-source-composition.json"
while IFS= read -r file;do install -Dm644 "$owner/$file" "$profile/$file";done < <(jq -r '.payload_assets[]' "$manifest")
commit=$(git -C "$owner" rev-parse HEAD)
tree=$(git -C "$owner" rev-parse HEAD^{tree})
jq --arg commit "$commit" --arg tree "$tree" '.+{source_commit:$commit,source_tree:$tree}' "$manifest" > "$profile/pcm-surround-qualification.json"
(cd "$profile";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/senemos-native-profile-7.3.3.tar.xz" -C "$work" native-profile
release=$(jq -er .source_check_release "$manifest")
{
 cat <<'SPEC'
%global debug_package %{nil}
%global _uke_out %{_topdir}/native-kernel-out
%global senemos_build_release 12
%global krel %{version}-%{senemos_build_release}-unstable
Name: uke-kernel-migration-check
Version: 7.3.3
SPEC
 printf 'Release: %s%%{?dist}\n' "$release"
 cat <<'SPEC'
Summary: Actual Uke AudioReach PCM surround transport qualification
License: GPL-2.0-only AND MIT AND BSD-3-Clause
URL: https://github.com/MCC45TR/senemos-uke-kernel-mainline
SPEC
 sed -n '/^Source0:/,/^BuildRequires: rsync/p' "$full"
 # Additional inherited host tools used by the unchanged preparation scripts.
 cat <<'SPEC'
BuildRequires: libfdt-devel nodejs ripgrep gzip cpio

%description
Text-only source and AArch64 object qualification of actual PCM encoders.
No kernel installation, runtime helper or hardware acceptance is provided.

SPEC
 awk '$0=="%prep"{emit=1} $0=="%build"{exit} emit{print}' "$full"
 cat <<'SPEC'
%build
export ARCH=arm64 LLVM=1 LLVM_IAS=1
mkdir -p %{_uke_out}
SPEC
 # Preserve every cumulative source transformation in this parent build span.
 awk '/^bash native-profile\/tests\/mainline-boot-status-contract.sh$/{emit=1} emit{print} emit&&/^bash native-profile\/packaging\/native\/prepare-surround-full733.sh .* source$/{found++;exit}END{if(found!=1)exit 1}' "$full"
 cat <<'SPEC'
bash native-profile/src/audio/prepare-pcm-surround733.sh "$PWD"
bash native-profile/packaging/native/check-pcm-surround733.sh "$PWD"
# Existing four-channel bit-depth contract is retained alongside the new test.
CC=gcc bash native-profile/tests/audio-pcm-formats-contract.sh "$PWD"
CC=clang bash native-profile/tests/audio-pcm-formats-contract.sh "$PWD"
cmp native-profile/native.config boot-recipe/packaging/native/native.config
cp native-profile/native.config %{_uke_out}/.config
make O=%{_uke_out} ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-12-unstable olddefconfig
make O=%{_uke_out} ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-12-unstable -j4 modules_prepare
make O=%{_uke_out} ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-12-unstable KCFLAGS=-Werror W=1 -j4 sound/soc/qcom/qdsp6/snd-q6apm.o sound/soc/qcom/qdsp6/q6apm-dai.o sound/soc/qcom/qdsp6/q6apm-lpass-dais.o
for object in snd-q6apm q6apm-dai q6apm-lpass-dais;do
 llvm-readelf -h %{_uke_out}/sound/soc/qcom/qdsp6/$object.o | grep -F AArch64
 llvm-nm %{_uke_out}/sound/soc/qcom/qdsp6/$object.o > native-generated/pcm-surround733/$object.symbols
done
for symbol in audioreach_uke_quad_matrix audioreach_uke_surround_matrix;do
 grep -E "[[:space:]]T[[:space:]]+$symbol$" native-generated/pcm-surround733/snd-q6apm.symbols
 grep -E "[[:space:]]U[[:space:]]+$symbol$" native-generated/pcm-surround733/q6apm-lpass-dais.symbols
done
grep -E '[[:space:]]U[[:space:]]+snd_pcm_add_chmap_ctls$' native-generated/pcm-surround733/q6apm-dai.symbols
sha256sum -c --strict --quiet native-generated/pcm-surround733/applied.sha256
printf 'Actual fresh AArch64 PCM composite/FE/LPASS qualification passed; source-only, not firmware/physical acceptance.\n'

%install
install -Dm644 native-profile/pcm-surround-qualification.json %{buildroot}%{_docdir}/%{name}/pcm-surround-qualification.json
install -Dm644 native-profile/pcm-parent-source-composition.json %{buildroot}%{_docdir}/%{name}/pcm-parent-source-composition.json
install -Dm644 native-generated/pcm-surround733/applied.sha256 %{buildroot}%{_docdir}/%{name}/actual-source.sha256
install -Dm644 native-profile/SHA256SUMS %{buildroot}%{_docdir}/%{name}/source-assets.sha256
install -Dm644 COPYING %{buildroot}%{_licensedir}/%{name}/COPYING

%files
%{_docdir}/%{name}
%{_licensedir}/%{name}

%changelog
SPEC
 printf '* Tue Nov 10 2026 Uke contributors - 7.3.3-%s\n- Qualify bounded eight-channel PCM transport and exact media payload lengths.\n- Preserve physical quad routing, gain223 and the admitted full12 source.\n' "$release"
} > "$output/uke-kernel-migration-check.spec"
rm "$full"
printf 'Focused PCM source prepared over admitted full12; no full kernel/runtime producer added.\n'

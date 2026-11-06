#!/usr/bin/env bash
# COPR source worker only: text-receipt check of exact cumulative inputs.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?Remote source result directory}")
revision=${2:-1}
[[ $revision =~ ^[1-9][0-9]*$ ]]
manifest=$owner/manifests/governor-options-layer-20261105.json
[[ ! -e $output || (-d $output && -z $(find "$output" -mindepth 1 -maxdepth 1 -print -quit)) ]]
bash "$owner/packaging/native/refuse-published-release.sh" uke-governor-cumulative-check "7.3.1-$revision"
(cd "$owner"; jq -r '.assets[],.check_inputs[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
stage=$(mktemp -d)
cleanup()
{
    if [[ -d $stage/audio-source ]]; then git -C "$owner" worktree remove "$stage/audio-source"; fi
    find "$stage" -depth -delete
}
trap cleanup EXIT
curl -q -fLsS --retry 2 --max-time 600 --proto '=https' --proto-redir '=https' \
    "$(jq -er .parent.url "$manifest")" -o "$stage/parent.src.rpm"
printf '%s  %s\n' "$(jq -er .parent.sha256 "$manifest")" "$stage/parent.src.rpm" | sha256sum -c --strict -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.1-12203* ]]
rpmkeys --checksig --nosignature --verbose "$stage/parent.src.rpm"
rpm2cpio "$stage/parent.src.rpm" > "$stage/parent.cpio"
cpio -t --quiet < "$stage/parent.cpio" > "$stage/entries"
awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/entries"
mkdir -p "$output" "$stage/unpacked"
(cd "$output"; cpio -idm --quiet --no-absolute-filenames < "$stage/parent.cpio")
parent=$output/senemos-uke-linux-kernel-mainline-unstable.spec
native_archive=senemos-native-profile-7.3.1.tar.xz
boot_archive=senemos-uke-boot-recipe.tar.xz
find "$output" -maxdepth 1 -type f ! -name "${parent##*/}" ! -name "$native_archive" \
    ! -name "$boot_archive" ! -name boot-payload.json -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > "$stage/retained.sha256"
for archive in "$native_archive" "$boot_archive"; do
    tar -tJf "$output/$archive" > "$stage/entries"
    awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/entries"
    tar -xJf "$output/$archive" -C "$stage/unpacked"
done
profile=$stage/unpacked/native-profile
boot=$stage/unpacked/boot-recipe
cmp "$boot/lock.json" "$output/boot-payload.json"
# Reproduce the camera factory's qualified audio fixture layer and early replay.
# These are independent inputs, not governor changes or a new kernel candidate.
audio_source=$(jq -er .preintegration.audio_source "$manifest")
camera_source=$(jq -er .preintegration.camera_source "$manifest")
for commit in "$audio_source" "$camera_source"; do
    [[ $commit =~ ^[a-f0-9]{40}$ ]]
    git -C "$owner" cat-file -e "$commit^{commit}" 2>/dev/null || git -C "$owner" fetch --depth=1 origin "$commit"
done
git -C "$owner" worktree add --detach "$stage/audio-source" "$audio_source"
bash "$stage/audio-source/packaging/native/overlay-speaker-legacy-fixtures.sh" "$profile" "$audio_source"
jq -e '.source_commit=="45d8355e366e6b75e43f441ca99b517302adf522" and
 .kernel_release=="7.3.1-12203-unstable"' "$profile/source-composition.json" >/dev/null
# The current frozen SRPM already contains both qualified inputs. Verify their
# exact bytes instead of approximating the production factory with another merge.
while IFS=$'\t' read -r path digest before; do
    [[ $path =~ ^(packaging|tests)/[a-zA-Z0-9_.,/-]+$ && $path != *..* ]]
    git -C "$owner" show "$camera_source:$path" > "$stage/camera-asset"
    printf '%s  %s\n' "$digest" "$stage/camera-asset" | sha256sum -c --strict --quiet -
    for tree in "$profile" "$boot"; do
        cmp "$stage/camera-asset" "$tree/$path"
    done
    jq -e --arg path "$path" --arg sha "$digest" \
        'any(.source_assets[];.path==$path and .sha256==$sha)' "$boot/lock.json" >/dev/null
done < <(jq -r '.preintegration.camera_assets[]|[.path,.sha256,(.before_sha256 // "null")]|@tsv' "$manifest")
awk '/^%check$/ {inside=1;next} /^%[a-z]/ {inside=0}
 inside && /bash native-profile\/tests\/(audio-|microphone-gain-contract|kernel-audio-policy-contract)/ {print}' \
 "$parent" > "$stage/inherited-audio-checks.sh"
[[ $(wc -l < "$stage/inherited-audio-checks.sh") == 24 ]]
cmp "$stage/inherited-audio-checks.sh" "$profile/tests/fixtures/inherited-audio-checks731.sh"
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
bash "$owner/tests/governor-layer-contract.sh" "$profile" "$boot" | tee "$output/governor-source-checks.txt"
bash "$owner/tests/governor-spec-contract.sh" "$parent" | tee -a "$output/governor-source-checks.txt"
bash "$owner/packaging/native/overlay-governor-options731.sh" "$profile" "$boot"
bash "$owner/packaging/native/overlay-governor-spec731.sh" "$parent"
install -m644 "$parent.before-governor-options.txt" "$output/governor-production-spec-before.txt"
unlink "$parent.before-governor-options.txt"
install -m644 "$boot/lock.json" "$output/boot-payload.json"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
for tree in native-profile boot-recipe; do
    archive=$native_archive
    [[ $tree != boot-recipe ]] || archive=$boot_archive
    tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
        -cJf "$output/$archive" -C "$stage/unpacked" "$tree"
done
mkdir -p "$stage/addon/governor-addon"
mapfile -t assets < <(jq -r '.assets[].path,.check_inputs[].path' "$manifest"; printf '%s\n' manifests/governor-options-layer-20261105.json LICENSE LICENSES/GPL-2.0-only.txt)
git -C "$owner" archive HEAD "${assets[@]}" | tar -xf - -C "$stage/addon/governor-addon"
git -C "$owner" rev-parse HEAD > "$stage/addon/governor-addon/source-commit"
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
    -cJf "$output/governor-cumulative-addon.tar.xz" -C "$stage/addon" governor-addon
install -m644 "$parent" "$output/governor-production-spec.txt"
spec=$output/uke-governor-cumulative-check.spec
awk -v revision="$revision" '
 /^%description/ {exit}
 /^Name:/ {$0="Name: uke-governor-cumulative-check"}
 /^Release:/ {$0="Release: "revision"%{?dist}"}
 /^Summary:/ {$0="Summary: Cumulative governor configuration and AArch64 object check"}
 /^(Requires|Provides|Recommends|Conflicts|Obsoletes|Supplements|Suggests|Enhances)(\([^)]*\))?:/ {next}
 {print}
' "$parent" > "$spec"
cat >> "$spec" <<'SPEC'
Source9: governor-cumulative-addon.tar.xz
Source10: governor-production-spec.txt
Source11: governor-source-checks.txt
Source12: governor-production-spec-before.txt

%description
Exact optional-governor source layer over the frozen cumulative12203 inputs.
The parent is a current source candidate, not a delivered or physically
qualified baseline. Preserve all source layers, hardware gates
and independent full-config comparisons. Build only the four governor objects;
package text receipts only. No Image, final module or target state operation.

SPEC
awk '/^%prep$/ {emit=1} /^%build$/ {exit} emit {print}' "$parent" >> "$spec"
cat >> "$spec" <<'SPEC'
tar -xJf %{SOURCE9}

%build
set -o pipefail
bash governor-addon/packaging/native/check-governor-cumulative731.sh "$PWD" %{_uke_out} \
    | tee %{_topdir}/governor-cumulative-checks.txt

%install
install -Dm644 %{_topdir}/governor-cumulative-checks.txt %{buildroot}%{_docdir}/%{name}/checks.txt
install -m644 %{SOURCE10} %{buildroot}%{_docdir}/%{name}/production-spec.txt
install -m644 %{SOURCE11} %{buildroot}%{_docdir}/%{name}/source-checks.txt
install -m644 %{SOURCE12} %{buildroot}%{_docdir}/%{name}/production-spec-before.txt
install -m644 governor-addon/source-commit %{buildroot}%{_docdir}/%{name}/source-commit
install -m644 native-profile/source-composition.json %{buildroot}%{_docdir}/%{name}/check-view-composition.json

%check
test -s %{buildroot}%{_docdir}/%{name}/checks.txt
test ! -e %{_uke_out}/arch/arm64/boot/Image
test -z "$(find %{_uke_out} -type f -name '*.ko' -print -quit)"

%files
%license governor-addon/LICENSE governor-addon/LICENSES/GPL-2.0-only.txt
%{_docdir}/%{name}/*

%changelog
SPEC
day=$(date -u --date="@$epoch" '+%a %b %d %Y')
printf '* %s Uke contributors - 7.3.1-%s\n- Check exact cumulative governor config retention and native objects.\n' "$day" "$revision" >> "$spec"
sha256sum -c --strict --quiet "$stage/retained.sha256"
unlink "$parent"
[[ $(rpmspec --target aarch64 -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$spec") == uke-governor-cumulative-check-7.3.1-$revision* ]]
printf '%s\n' 'Cumulative governor source check prepared; no kernel revision or full build submitted'

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
trap 'find "$stage" -depth -delete' EXIT
curl -q -fLsS --retry 2 --max-time 600 --proto '=https' --proto-redir '=https' \
    "$(jq -er .parent.url "$manifest")" -o "$stage/parent.src.rpm"
printf '%s  %s\n' "$(jq -er .parent.sha256 "$manifest")" "$stage/parent.src.rpm" | sha256sum -c --strict -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.1-12202* ]]
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
bash "$owner/tests/governor-layer-contract.sh" "$profile" "$boot" | tee "$output/governor-source-checks.txt"
bash "$owner/packaging/native/overlay-governor-options731.sh" "$profile" "$boot"
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
BuildRequires: python3-lxml kernel-headers

%description
Exact optional-governor source layer over the frozen cumulative12202 inputs.
The parent full candidate failed later audio fixtures and is not a delivered
or physically qualified baseline. Preserve all source layers, hardware gates
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

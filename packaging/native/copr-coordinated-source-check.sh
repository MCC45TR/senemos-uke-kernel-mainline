#!/usr/bin/env bash
# COPR only: qualify the touch layer on complete12101 sources, no kernel RPM.
set -Eeuo pipefail
trap 'status=$?; printf "Cumulative source check preparation failed at line %s (exit %s)\n" "$LINENO" "$status" >&2; exit "$status"' ERR
export LC_ALL=C
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
manifest=manifests/qualified-touch-layer-20261105.json
bash "$owner/packaging/native/refuse-published-release.sh" uke-coordinated-source-check 7.3.1-1
for build in 11260781 11260818; do
    [[ $(curl -q -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$build" | jq -er .state) == succeeded ]]
done
curl -q -fLsS --max-time 45 https://copr.fedorainfracloud.org/api_3/build/source-build-config/11260818 | \
    jq -e '.source_dict.script|contains("27471abc9cf4ed25011fb26383ccf35f8505aa43")' >/dev/null
[[ ! -e $output || (-d $output && -z $(find "$output" -mindepth 1 -maxdepth 1 -print -quit)) ]]
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
parent_url=$(jq -er .parent.url "$owner/$manifest")
parent_hash=$(jq -er .parent.sha256 "$owner/$manifest")
curl -q -fLsS --retry 2 --max-time 600 --proto '=https' --proto-redir '=https' \
    "$parent_url" -o "$stage/parent.src.rpm"
printf '%s  %s\n' "$parent_hash" "$stage/parent.src.rpm" | sha256sum -c --strict -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.1-12101.fc46 ]]
rpmkeys --checksig --nosignature --verbose "$stage/parent.src.rpm"
rpm2cpio "$stage/parent.src.rpm" > "$stage/parent.cpio"
cpio -t --quiet < "$stage/parent.cpio" > "$stage/entries"
awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/entries"
mkdir -p "$output" "$stage/unpacked" "$stage/addon"
(cd "$output"; cpio -idm --quiet --no-absolute-filenames < "$stage/parent.cpio")
parent=$output/senemos-uke-linux-kernel-mainline-unstable.spec
native_archive=senemos-native-profile-7.3.1.tar.xz
boot_archive=senemos-uke-boot-recipe.tar.xz
find "$output" -maxdepth 1 -type f ! -name "${parent##*/}" \
    ! -name "$native_archive" ! -name "$boot_archive" ! -name boot-payload.json \
    -print0 | sort -z | xargs -0 sha256sum > "$stage/retained-sources.sha256"
for archive in "$native_archive" "$boot_archive"; do
    tar -tJf "$output/$archive" > "$stage/entries"
    awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/entries"
    tar -xJf "$output/$archive" -C "$stage/unpacked"
done
profile=$stage/unpacked/native-profile
boot=$stage/unpacked/boot-recipe
cmp "$boot/lock.json" "$output/boot-payload.json"
jq -e '.source_commit=="bba194e74ab97dcb848887fa62430c20f9d755d9" and
 .kernel_release=="7.3.1-12101-unstable" and .camcc_probe_observation_check==11260755 and
 .qualified_ssc_observation_check==11260554 and .camcc_probe_observation_cached_only' \
    "$profile/source-composition.json" >/dev/null
bash "$owner/packaging/native/overlay-qualified-touch731.sh" "$profile" "$boot"
# Repeated layer admission must verify the exact source, never append twice.
sha256sum "$profile/SHA256SUMS" "$profile/source-composition.json" "$boot/lock.json" > "$stage/applied.sha256"
bash "$owner/packaging/native/overlay-qualified-touch731.sh" "$profile" "$boot"
sha256sum -c --strict "$stage/applied.sha256"
jq '. + {source_check_view_only:true,source_check_package:"uke-coordinated-source-check-7.3.1-1"}' \
    "$profile/source-composition.json" > "$stage/check-composition.json"
install -m644 "$stage/check-composition.json" "$profile/source-composition.json"
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
install -m644 "$boot/lock.json" "$output/boot-payload.json"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
for tree in native-profile boot-recipe; do
    archive=$native_archive
    [[ $tree != boot-recipe ]] || archive=$boot_archive
    tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
        -cJf "$output/$archive" -C "$stage/unpacked" "$tree"
done
[[ $(grep -c '^Source9:' "$parent") == 0 ]]
git -C "$owner" archive --prefix=native-addon/ HEAD \
    tests/o82-touch-integrated731-contract.sh \
    packaging/native/overlay-qualified-touch731.sh \
    manifests/qualified-touch-layer-20261105.json \
    patches/display/0074-o82-touch-retain-before-off.patch \
    patches/display/0074-o82-touch-retain-test.patch \
    src/input/nt36532-uke-protocol.c docs/O82-TOUCH-BLANK-ORDER.md \
    docs/NT36532-PROTOCOL.md LICENSE LICENSES/GPL-2.0-only.txt | tar -xf - -C "$stage/addon"
git -C "$owner" rev-parse HEAD > "$stage/addon/native-addon/source-commit"
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
    -cJf "$output/uke-coordinated-source-addon.tar.xz" -C "$stage/addon" native-addon
spec=$output/uke-coordinated-source-check.spec
awk '
 /^%description/ {exit}
 /^Name:/ {$0="Name: uke-coordinated-source-check"}
 /^Release:/ {$0="Release: 1%{?dist}"}
 /^Summary:/ {$0="Summary: Retained12101 source composition and touch callback check"}
 /^(Requires|Provides|Recommends):/ {next}
 {print}
' "$parent" > "$spec"
cat >> "$spec" <<'SPEC'
Source9: uke-coordinated-source-addon.tar.xz

%description
Verify precise source layering on the complete qualified12101 camera/SSC/NFC
baseline, then execute actual retained touch/panel callbacks and negative
controls. Only text receipts are packaged. No kernel, module or boot image is
produced, no new kernel NVR is reserved and no device operation is performed.

SPEC
awk '/^%prep$/ {emit=1} /^%build$/ {exit} emit {print}' "$parent" >> "$spec"
cat >> "$spec" <<'SPEC'
tar -xJf %{SOURCE9}

%build
set -o pipefail
bash native-addon/tests/o82-touch-integrated731-contract.sh "$PWD" \
 | tee %{_topdir}/coordinated-source-checks.txt

%install
install -Dm644 %{_topdir}/coordinated-source-checks.txt \
 %{buildroot}%{_docdir}/%{name}/checks.txt
install -m644 native-addon/source-commit %{buildroot}%{_docdir}/%{name}/source-commit
install -m644 native-profile/source-composition.json %{buildroot}%{_docdir}/%{name}/check-view-composition.json

%check
test -s %{buildroot}%{_docdir}/%{name}/checks.txt
test ! -e arch/arm64/boot/Image

%files
%license native-addon/LICENSE native-addon/LICENSES/GPL-2.0-only.txt
%{_docdir}/%{name}/checks.txt
%{_docdir}/%{name}/source-commit
%{_docdir}/%{name}/check-view-composition.json

%changelog
* Thu Nov 05 2026 Uke contributors - 7.3.1-1
- Preserve the complete qualified12101 sources while adding exact touch patches.
- Keep camera/SSC observations, all original config and firmware/admission fields.
- Check source-layer idempotence, actual callback error paths and original failure.
SPEC
sha256sum -c --strict --quiet "$stage/retained-sources.sha256"
unlink "$parent"
[[ $(rpmspec --target aarch64 --define 'dist %{nil}' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$spec") == uke-coordinated-source-check-7.3.1-1 ]]
printf 'Cumulative source-only check prepared; no full kernel candidate or device change\n'

#!/usr/bin/env bash
# COPR only: complete source preparation and linked MSM object, no kernel RPM.
set -Eeuo pipefail
trap 'status=$?; printf "Cumulative source check preparation failed at line %s (exit %s)\n" "$LINENO" "$status" >&2; exit "$status"' ERR
export LC_ALL=C
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
manifest=manifests/qualified-touch-layer-20261105.json
bash "$owner/packaging/native/refuse-published-release.sh" uke-o82-kms-check 7.3.1-16
for build in 11260781 11260818 11261165 11261228; do
    [[ $(curl -q -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$build" | jq -er .state) == succeeded ]]
done
curl -q -fLsS --max-time 45 https://copr.fedorainfracloud.org/api_3/build/source-build-config/11261228 | \
    jq -e '.source_dict.script|contains("a85f0f660dd947d2737dca18ce043674ce55a45e")' >/dev/null
[[ $(curl -q -fLsS --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11261044 | jq -er .state) == succeeded ]]
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
# Geometry/GPU assets are new; no existing profile/boot source is replaced here.
(cd "$profile"; find . -type f ! -name SHA256SUMS ! -name source-composition.json -print0 | sort -z | xargs -0 sha256sum) > "$stage/retained-profile.sha256"
geometry_assets=(src/camera/sensors/0005-ov08d10-selection731.patch
    tests/camera-geometry731-contract.sh tests/camera-geometry731-object.sh
    tests/fixtures/camera-geometry731.c docs/OV08D10-GEOMETRY731.md
    manifests/camera-geometry731-20261105.json)
gmu_assets=(patches/gpu/0075-gmu-hfi-irq-owned-status.patch
    tests/gmu-hfi-irq-contract.sh tests/fixtures/gmu-hfi-irq-check.c
    tests/gmu-msm-object731-contract.sh docs/GMU-HFI-IRQ-OWNERSHIP.md
    docs/GMU-MSM-OBJECT731.md manifests/gmu-msm-object731-20261105.json)
while IFS=$'\t' read -r asset_path asset_sha; do
    printf '%s  %s\n' "$asset_sha" "$owner/$asset_path" | sha256sum -c --strict -
done < <(jq -r '.inputs[]|[.path,.sha256]|@tsv' "$owner/manifests/camera-geometry731-20261105.json")
while IFS=$'\t' read -r asset_path asset_sha; do
    printf '%s  %s\n' "$asset_sha" "$owner/$asset_path" | sha256sum -c --strict -
done < <(jq -r '.qualified_inputs[]|[.path,.sha256]|@tsv' "$owner/manifests/gmu-msm-object731-20261105.json")
for asset in "${geometry_assets[@]}" "${gmu_assets[@]}"; do
    test ! -e "$profile/$asset"
    install -Dm644 "$owner/$asset" "$profile/$asset"
done
jq --arg source "$(git -C "$owner" rev-parse HEAD)" '. + {
 source_check_view_only:true,source_check_package:"uke-o82-kms-check-7.3.1-16",
 camera_geometry_source:$source,camera_geometry_three_argument_pad_api:true,
 camera_geometry_private_mutex_and_per_file_try:true,
 camera_geometry_physical_acceptance:false,
 gmu_irq_reference_source:"a85f0f660dd947d2737dca18ce043674ce55a45e",
 gmu_irq_reference_check:11261228,gmu_irq_owned_acknowledgement:true,
 gmu_msm_real_object_check_required:true,gmu_msm_physical_acceptance:false}' \
    "$profile/source-composition.json" > "$stage/check-composition.json"
install -m644 "$stage/check-composition.json" "$profile/source-composition.json"
(cd "$profile"; sha256sum -c --strict --quiet "$stage/retained-profile.sha256")
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
    docs/NT36532-PROTOCOL.md "${geometry_assets[@]}" "${gmu_assets[@]}" \
    LICENSE LICENSES/GPL-2.0-only.txt | tar -xf - -C "$stage/addon"
git -C "$owner" rev-parse HEAD > "$stage/addon/native-addon/source-commit"
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
    -cJf "$output/uke-coordinated-source-addon.tar.xz" -C "$stage/addon" native-addon
spec=$output/uke-o82-kms-check.spec
awk '
 /^%description/ {exit}
 /^Name:/ {$0="Name: uke-o82-kms-check"}
 /^Release:/ {$0="Release: 16%{?dist}"}
 /^Summary:/ {$0="Summary: Retained cumulative sources and actual AArch64 MSM object check"}
 /^(Requires|Provides|Recommends):/ {next}
 {print}
' "$parent" > "$spec"
cat >> "$spec" <<'SPEC'
Source9: uke-coordinated-source-addon.tar.xz
BuildRequires: kernel-headers

%description
Prepare the complete qualified12101 camera/SSC/NFC baseline with qualified
touch and geometry, then check actual GMU IRQ/waiter controls and compile/link
the real AArch64 MSM composite object. Only text receipts are packaged.
No Image, final kernel module, kernel RPM or new kernel NVR is produced.
No device operation occurs. Other post12101 contributions still require the
coordinator's final cumulative integration and physical acceptance.

SPEC
awk '/^%prep$/ {emit=1} /^%build$/ {exit} emit {print}' "$parent" >> "$spec"
cat >> "$spec" <<'SPEC'
tar -xJf %{SOURCE9}
printf '%s  %s\n' 96aad491915796d54e2a8cd20c90a9a8c4e58515c64f7ad4d5faae39caa4d31c drivers/media/i2c/ov08d10.c | sha256sum -c --strict -
cp drivers/media/i2c/ov08d10.c native-generated/geometry-before.c
git apply --check native-profile/src/camera/sensors/0005-ov08d10-selection731.patch
git apply native-profile/src/camera/sensors/0005-ov08d10-selection731.patch
printf '%s  %s\n' df7ce54741d6a08c09ff607b86ce33c2057bb05c52b4d1a21d98b5be3395700e drivers/media/i2c/ov08d10.c | sha256sum -c --strict -

%build
set -o pipefail
bash native-addon/tests/o82-touch-integrated731-contract.sh "$PWD" \
 | tee %{_topdir}/coordinated-source-checks.txt
bash native-addon/tests/camera-geometry731-contract.sh "$PWD" native-generated/geometry-before.c \
 | tee -a %{_topdir}/coordinated-source-checks.txt
bash native-addon/tests/camera-geometry731-object.sh "$PWD" "$PWD/native-object" native-profile/native.config \
 | tee -a %{_topdir}/coordinated-source-checks.txt
bash native-addon/tests/gmu-hfi-irq-contract.sh "$PWD" \
 | tee -a %{_topdir}/coordinated-source-checks.txt
bash native-addon/tests/gmu-msm-object731-contract.sh "$PWD" "$PWD/native-object" native-profile/native.config \
 | tee -a %{_topdir}/coordinated-source-checks.txt

%install
install -Dm644 %{_topdir}/coordinated-source-checks.txt \
 %{buildroot}%{_docdir}/%{name}/checks.txt
install -m644 native-addon/source-commit %{buildroot}%{_docdir}/%{name}/source-commit
install -m644 native-profile/source-composition.json %{buildroot}%{_docdir}/%{name}/check-view-composition.json

%check
test -s %{buildroot}%{_docdir}/%{name}/checks.txt
test ! -e arch/arm64/boot/Image
test ! -e native-object/arch/arm64/boot/Image
test ! -e native-object/drivers/gpu/drm/msm/msm.ko

%files
%license native-addon/LICENSE native-addon/LICENSES/GPL-2.0-only.txt
%{_docdir}/%{name}/checks.txt
%{_docdir}/%{name}/source-commit
%{_docdir}/%{name}/check-view-composition.json

%changelog
* Thu Nov 05 2026 Uke contributors - 7.3.1-16
- Preserve the complete qualified12101 sources while adding exact touch patches.
- Keep camera/SSC observations, all original config and firmware/admission fields.
- Check source-layer idempotence, actual callback error paths and original failure.
- Qualify exact front geometry callbacks, mutants and the real AArch64 object.
- Check the exact GMU IRQ control and link the actual cumulative MSM object.
SPEC
sha256sum -c --strict --quiet "$stage/retained-sources.sha256"
unlink "$parent"
[[ $(rpmspec --target aarch64 --define 'dist %{nil}' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$spec") == uke-o82-kms-check-7.3.1-16 ]]
printf 'Cumulative source/MSM object check prepared; no full kernel candidate or device change\n'

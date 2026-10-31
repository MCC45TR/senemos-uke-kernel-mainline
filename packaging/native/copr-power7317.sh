#!/usr/bin/env bash
# COPR-only isolated power candidate; retain the verified release-4 composition.
set -Eeuo pipefail
export LC_ALL=C
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
bash "$owner/packaging/native/refuse-published-release.sh" senemos-uke-linux-kernel-mainline 7.3.1-7
make -C "$owner" validate
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
curl --fail --location --silent --show-error --retry 3 --proto '=https' --proto-redir '=https' \
 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11233851/senemos-uke-linux-kernel-mainline-7.3.1-4.src.rpm -o "$stage/base.src.rpm"
printf '%s  %s\n' 9352f9906a315bdcc1be596f8318d5097cfda191c1f6544e8e38df9fca9e1f5b "$stage/base.src.rpm" | sha256sum -c -
rpm2cpio "$stage/base.src.rpm" > "$stage/base.cpio"
cpio -t --quiet < "$stage/base.cpio" > "$stage/entries"
awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/entries"
mkdir -p "$output" "$stage/unpacked"
(cd "$output"; cpio -idm --quiet --no-absolute-filenames < "$stage/base.cpio")
spec=senemos-uke-linux-kernel-mainline.spec
test "$(rpmspec --target aarch64 --define 'dist %{nil}' -q --srpm --qf '%{VERSION}-%{RELEASE}' "$output/$spec")" = 7.3.1-4
find "$output" -maxdepth 1 -type f ! -name "$spec" ! -name senemos-native-profile-7.3.1.tar.xz \
 ! -name senemos-uke-boot-recipe.tar.xz ! -name boot-payload.json -print0 | sort -z | xargs -0 sha256sum > "$stage/retained.sha256"
for archive in senemos-native-profile-7.3.1.tar.xz senemos-uke-boot-recipe.tar.xz; do
    tar -tJf "$output/$archive" > "$stage/archive.entries"
    awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/archive.entries"
    tar -xJf "$output/$archive" -C "$stage/unpacked"
done
profile=$stage/unpacked/native-profile
boot=$stage/unpacked/boot-recipe
(cd "$profile"; sha256sum --check --strict --quiet SHA256SUMS)
grep -Fx 668b927536eda3758ae6599167c8ed66aaf9b2ee "$profile/source-commit"
grep -Fx speakers "$profile/audio-profile"
printf '%s  %s\n' d744290e1d9c19684f274d44ba9f0f093a3ac983adca2271bb54cf3dfccfd2c8 "$profile/native.config" | sha256sum -c -
cp "$profile/SHA256SUMS" "$stage/parent-profile.sha256"
cp "$profile/source-composition.json" "$profile/source-composition-parent7314.json"
overlays=(
 packaging/native/native.config src/boot/prepare-abl-source.sh src/boot/uke-abl.c
 src/boot/uke-clock-debug.h src/power/prepare-cpucp-observe.sh src/power/uke-cpucp-observe.c
 patches/boot/0051-cpufreq-preserve-boost-state-on-error.patch
 tests/clock-debug-fdt-contract.sh tests/cpufreq-boost-error-contract.sh
 tests/memlat-scmi-probe-contract.sh tests/mainline-package-contract.sh
)
: > "$stage/overlays"
for relative in "${overlays[@]}"; do
    destination=$relative
    [[ $relative != packaging/native/* ]] || destination=${relative##*/}
    install -Dm644 "$owner/$relative" "$profile/$destination"
    printf '%s\n' "$destination" >> "$stage/overlays"
    if jq -e --arg path "$relative" '.source_assets[]|select(.path==$path)' "$owner/manifests/boot-payload.json" >/dev/null; then
        install -Dm644 "$owner/$relative" "$boot/$relative"
    fi
done
while read -r expected relative; do
    relative=${relative#./}
    case $relative in source-commit|source-composition.json) continue;; esac
    if ! grep -Fxq -- "$relative" "$stage/overlays"; then
        printf '%s  %s\n' "$expected" "$profile/$relative" | sha256sum -c -
    fi
done < "$stage/parent-profile.sha256"
# Run the real new wire operations and core rollback before source RPM emission.
bash "$owner/tests/memlat-scmi-probe-contract.sh" "$owner/src/power/uke-cpucp-observe.c"
mkdir -p "$stage/fixture"
tar -xJf "$output/linux-7.3.1.tar.xz" --strip-components=1 -C "$stage/fixture" linux-7.3.1/drivers/cpufreq/cpufreq.c
git -C "$stage/fixture" apply "$owner/patches/boot/0051-cpufreq-preserve-boost-state-on-error.patch"
bash "$owner/tests/cpufreq-boost-error-contract.sh" "$stage/fixture/drivers/cpufreq/cpufreq.c"
commit=$(git -C "$owner" rev-parse HEAD)
printf '%s\n' "$commit" > "$profile/source-commit"
jq -Rn '[inputs]' < "$stage/overlays" > "$stage/overlays.json"
jq -n --arg commit "$commit" --slurpfile overlays "$stage/overlays.json" \
 '{schema_version:1,source_mode:"retained-stable-profile-with-power-ownership-candidate",source_commit:$commit,upstream_version:"7.3.1",upstream_commit:"79a907609d53d5cd645b42c11550d295d43abf99",upstream_sha256:"fa595aad93734f829c963c2a90ef7c3673224fd7fdae7b49406e397cde2de231",patch_series:"7.3.0",adaptation_patch_count:122,parent_copr_build:11233851,parent_srpm_sha256:"9352f9906a315bdcc1be596f8318d5097cfda191c1f6544e8e38df9fca9e1f5b",parent_composition:"source-composition-parent7314.json",adaptation_patches_unchanged:true,overlays:$overlays[0],audio_profile:"speakers",cpucp_observer:"manual-get-only",boost_default_changed:false,ignore_unused_removed:[],pm_debug_messages:true,physical_acceptance:false}' > "$profile/source-composition.json"
install -m644 "$owner/manifests/boot-payload.json" "$boot/lock.json"
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c -)
for tree in native-profile boot-recipe; do
    case $tree in native-profile) archive=senemos-native-profile-7.3.1.tar.xz;; boot-recipe) archive=senemos-uke-boot-recipe.tar.xz;; esac
    tar --sort=name --mtime=@1793362198 --owner=0 --group=0 --numeric-owner -cJf "$output/$archive" -C "$stage/unpacked" "$tree"
done
install -m644 "$boot/lock.json" "$output/boot-payload.json"
install -m644 "$owner/packaging/$spec" "$output/$spec"
sha256sum -c "$stage/retained.sha256"
test "$(rpmspec --target aarch64 --define 'dist %{nil}' -q --srpm --qf '%{VERSION}-%{RELEASE}' "$output/$spec")" = 7.3.1-7

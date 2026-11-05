#!/usr/bin/env bash
# COPR only: one full unstable kernel, complete12101 and every frozen layer.
set -Eeuo pipefail
trap 'status=$?; printf "Cumulative camera source preparation failed at line %s (exit %s)\n" "$LINENO" "$status" >&2; exit "$status"' ERR
export LC_ALL=C
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 2 && $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "$1")
revision=$2
[[ $revision =~ ^[1-9][0-9]{4}$ && $revision -gt 12101 ]]
manifest=manifests/cumulative-camera731-20261105.json
(cd "$owner"; jq -r '.source_inputs[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
bash "$owner/packaging/native/refuse-published-release.sh" \
 senemos-uke-linux-kernel-mainline-unstable "7.3.1-$revision"
while read -r build; do
    [[ $(curl -q -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$build" | jq -er .state) == succeeded ]]
done < <(jq -r '.required_checks[].copr_build' "$owner/$manifest")
[[ ! -e $output || (-d $output && -z $(find "$output" -mindepth 1 -maxdepth 1 -print -quit)) ]]
stage=$(mktemp -d)
cleanup()
{
    if [[ -d $stage/audio-source ]]; then git -C "$owner" worktree remove "$stage/audio-source"; fi
    find "$stage" -depth -delete
}
trap cleanup EXIT
curl -q -fLsS --retry 2 --max-time 600 --proto '=https' --proto-redir '=https' \
 "$(jq -er .kernel_parent.url "$owner/$manifest")" -o "$stage/parent.src.rpm"
parent_hash=$(jq -er .kernel_parent.sha256 "$owner/$manifest")
printf '%s  %s\n' "$parent_hash" "$stage/parent.src.rpm" | sha256sum -c --strict -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.1-12101.fc46 ]]
rpmkeys --checksig --nosignature --verbose "$stage/parent.src.rpm"
rpm2cpio "$stage/parent.src.rpm" > "$stage/parent.cpio"
cpio -t --quiet < "$stage/parent.cpio" > "$stage/entries"
awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/entries"
mkdir -p "$output" "$stage/unpacked"
(cd "$output"; cpio -idm --quiet --no-absolute-filenames < "$stage/parent.cpio")
spec=$output/senemos-uke-linux-kernel-mainline-unstable.spec
native_archive=senemos-native-profile-7.3.1.tar.xz
boot_archive=senemos-uke-boot-recipe.tar.xz
find "$output" -maxdepth 1 -type f ! -name "${spec##*/}" ! -name "$native_archive" \
 ! -name "$boot_archive" ! -name boot-payload.json -print0 | sort -z | xargs -0 sha256sum > "$stage/retained-sources.sha256"
cp "$spec" "$stage/parent.spec"
for archive in "$native_archive" "$boot_archive"; do
    tar -tJf "$output/$archive" > "$stage/entries"
    awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/entries"
    tar -xJf "$output/$archive" -C "$stage/unpacked"
done
profile=$stage/unpacked/native-profile
boot=$stage/unpacked/boot-recipe
[[ $(cat "$profile/source-commit") == bba194e74ab97dcb848887fa62430c20f9d755d9 ]]
jq -e '.source_commit=="bba194e74ab97dcb848887fa62430c20f9d755d9" and
 .kernel_release=="7.3.1-12101-unstable" and .camcc_probe_observation_check==11260755 and
 .qualified_ssc_observation_check==11260554' "$profile/source-composition.json" >/dev/null
(cd "$profile"; sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
cmp "$boot/lock.json" "$output/boot-payload.json"
cmp "$profile/native.config" "$boot/packaging/native/native.config"
printf '%s  %s\n' 739882b3a07fc6a701bae81ac6623a4b576871bd4289de3a095acabc20d49d34 \
 "$profile/native.config" | sha256sum -c --strict -
bash "$owner/packaging/native/overlay-qualified-touch731.sh" "$profile" "$boot"
bash "$owner/tests/o82-memory-layer-contract.sh" "$owner" "$profile" "$boot"
bash "$owner/tests/queued-source-layer731-contract.sh" "$owner" "$profile" "$boot" "$spec"
bash "$owner/tests/o82-private-dnf-layer.sh" "$owner" "$profile" "$spec"
bash "$owner/packaging/native/overlay-ssc-transaction731.sh" "$profile" "$boot"
bash "$owner/packaging/native/overlay-ssc-transaction731.sh" "$profile" "$boot"
bash "$owner/tests/camcc-bootstrap-layer731-contract.sh" "$owner" "$profile" "$boot"
# Extend the complete trees with exact qualified CDSP and model/check inputs.
# No undeclared old byte may be replaced, including optional boot mirrors.
while IFS=$'\t' read -r path digest before; do
    [[ $path =~ ^(src|tests|docs|packaging|manifests)/[a-zA-Z0-9_.,/-]+$ && $path != *..* ]]
    for tree in "$profile" "$boot"; do
        if [[ -e $tree/$path || -L $tree/$path ]]; then
            [[ -f $tree/$path && ! -L $tree/$path ]]
            if ! cmp -s "$owner/$path" "$tree/$path"; then
                [[ $before != null ]]
                printf '%s  %s\n' "$before" "$tree/$path" | sha256sum -c --strict --quiet -
            fi
        fi
    done
done < <(jq -r '.production_assets[]|[.path,.sha256,(.before_sha256 // "null")]|@tsv' "$owner/$manifest")
cp "$profile/SHA256SUMS" "$stage/extension-profile.before"
(cd "$boot"; find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$stage/extension-boot.before"
cp "$boot/lock.json" "$stage/extension-lock.before"
mapfile -t assets < <(jq -r '.production_assets[].path' "$owner/$manifest"; printf '%s\n' "$manifest")
for path in "${assets[@]}"; do
    for tree in "$profile" "$boot"; do install -Dm644 "$owner/$path" "$tree/$path"; done
    digest=$(sha256sum "$owner/$path"); digest=${digest%% *}
    jq --arg path "$path" --arg sha "$digest" '
     if any(.source_assets[];.path==$path) then
       (.source_assets[]|select(.path==$path)|.sha256)=$sha
     else .source_assets += [{path:$path,sha256:$sha}] end' "$boot/lock.json" > "$stage/next.lock"
    install -m644 "$stage/next.lock" "$boot/lock.json"
done
for role in profile boot; do
    tree=$profile; receipt=$stage/extension-profile.before
    [[ $role != boot ]] || { tree=$boot; receipt=$stage/extension-boot.before; }
    while read -r digest path; do
        path=${path#./}
        if ! printf '%s\n' "${assets[@]}" | grep -Fxq "$path"; then
            printf '%s  %s\n' "$digest" "$tree/$path" | sha256sum -c --strict --quiet -
        fi
    done < "$receipt"
done
cmp <(jq -cS 'del(.source_assets)' "$stage/extension-lock.before") <(jq -cS 'del(.source_assets)' "$boot/lock.json")
# The complete source/DT/audio policy must survive all ABI renaming unchanged.
audio_path=src/audio/uke-audio-card.c
audio_release="7.3.1-${revision}u"
audio_driver=uke${audio_release//./_}
[[ ${#audio_driver} -lt 16 ]]
audio_helper=$(jq -er .audio_controls_only.helper "$owner/$manifest")
audio_commit=$(jq -er .audio_controls_only.source_commit "$owner/$manifest")
[[ $audio_commit =~ ^[a-f0-9]{40}$ ]]
git -C "$owner" cat-file -e "$audio_commit^{commit}" 2>/dev/null || git -C "$owner" fetch --depth=1 origin "$audio_commit"
git -C "$owner" worktree add --detach "$stage/audio-source" "$audio_commit"
(cd "$stage/audio-source"; jq -r '.audio_controls_only.assets[]|.sha256+"  "+.path' "$owner/$manifest" | sha256sum -c --strict --quiet -)
bash "$stage/audio-source/$audio_helper" "$profile" "$audio_commit"
sha256sum "$profile/SHA256SUMS" "$boot/lock.json" > "$stage/audio-applied"
bash "$stage/audio-source/$audio_helper" "$profile" "$audio_commit"
sha256sum -c --strict --quiet "$stage/audio-applied"
for tree in "$profile" "$boot"; do
    [[ $(grep -Fo 'uke7.3.1-12101u' "$tree/$audio_path" | wc -l) == 2 ]]
    sed "s/uke7[.]3[.]1-12101u/uke$audio_release/g" "$tree/$audio_path" > "$stage/audio-card.c"
    sed "s/uke$audio_release/uke7.3.1-12101u/g" "$stage/audio-card.c" > "$stage/audio-restored.c"
    cmp "$tree/$audio_path" "$stage/audio-restored.c"
    install -m644 "$stage/audio-card.c" "$tree/$audio_path"
done
audio_hash=$(sha256sum "$boot/$audio_path"); audio_hash=${audio_hash%% *}
jq --arg path "$audio_path" --arg sha "$audio_hash" \
 '(.source_assets[]|select(.path==$path)|.sha256)=$sha' "$boot/lock.json" > "$stage/next.lock"
install -m644 "$stage/next.lock" "$boot/lock.json"
bash "$profile/src/audio/desktop/install-policy.sh" "$stage/audio-policy" "7.3.1-$revision-unstable"
test -r "$stage/audio-policy/usr/share/alsa/ucm2/conf.d/$audio_driver/POCO-Pad-X1.conf"
commit=$(git -C "$owner" rev-parse HEAD)
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
history=source-composition-before-cumulative-camera.json
test ! -e "$profile/$history"
cp "$profile/source-composition.json" "$profile/$history"
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg commit "$commit" --arg revision "$revision" --arg audio "$audio_driver" \
 --arg hash "$parent_hash" --arg history "$history" --arg manifest "$manifest" \
 --slurpfile plan "$owner/$manifest" '. + {
 source_commit:$commit,kernel_release:("7.3.1-"+$revision+"-unstable"),rpm_revision:$revision,
 source_mode:(.source_mode+"+qualified-cdsp-actlr+coordinated-camera"),
 parent_copr_build:11260781,parent_srpm_sha256:$hash,parent_composition:$history,
 parent_source_commit:"bba194e74ab97dcb848887fa62430c20f9d755d9",
 diagnostic_audio_driver:$audio,cumulative_source_manifest:$manifest,
 cumulative_qualified_checks:$plan[0].required_checks,cdsp_actlr_layer:1,
 cdsp_actlr_qualified_source:"3776f776b5be22d01e4bb084cff994050c719a2e",cdsp_actlr_check:11261896,
 cdsp_actlr_physical_acceptance:false,kernel_driver_source_unchanged:false,
 automatic_policy_unchanged:true,automatic_seamless_staging_required:true,
 package_rollback_default:"enforced",preserve_local_rollback_preference:true,
 normal_kernel_promotion:false,device_installation:false,physical_acceptance:false}' \
 "$profile/$history" > "$profile/source-composition.json"
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
install -m644 "$boot/lock.json" "$output/boot-payload.json"
for tree in native-profile boot-recipe; do
    archive=$native_archive
    [[ $tree != boot-recipe ]] || archive=$boot_archive
    tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
     -cJf "$output/$archive" -C "$stage/unpacked" "$tree"
done
# Retain every production section/check; insert the new SMMU prep before the
# existing queued hook so the latter stays immediately adjacent to %build.
awk -v revision="$revision" '
 /^%global senemos_build_release 12101$/ {$0="%global senemos_build_release "revision;release++}
 /^bash native-profile\/packaging\/native\/prepare-queued-kernel731.sh / {
   print "bash native-profile/tests/cdsp-actlr-qualify.sh \"$PWD\"";prep++
 }
 /^%build$/ {
   print
   print "bash native-profile/packaging/native/check-cumulative-camera731.sh \"$PWD\" %{_uke_out} prepared"
   build++;next
 }
 /^%check$/ {
   print
   print "bash native-profile/packaging/native/check-cumulative-camera731.sh \"$PWD\" %{_uke_out} linked"
   check++;next
 }
 /^%changelog$/ {
   print;print "* Thu Nov 05 2026 Uke contributors - 7.3.1-"revision
   print "- Retain complete12101 with touch, memory/v5, geometry and GMU corrections."
   print "- Include qualified SSC transactions, CDSP ACTLR and OEM CAMCC gate order."
   print "- Retain speaker admission, seamless staging and the local rollback preference."
   print "";next
 }
 {print}
 END {if(release!=1||prep!=1||build!=1||check!=1)exit 1}
' "$spec" > "$stage/next.spec"
install -m644 "$stage/next.spec" "$spec"
sha256sum -c --strict --quiet "$stage/retained-sources.sha256"
bash "$owner/tests/unstable-boot-family731-contract.sh" "$spec"
[[ $(rpmspec --target aarch64 --define 'dist %{nil}' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$spec") == senemos-uke-linux-kernel-mainline-unstable-7.3.1-$revision ]]
printf 'One complete unstable production candidate prepared; full build/signatures and physical camera/calibration/focus qualification remain required\n'

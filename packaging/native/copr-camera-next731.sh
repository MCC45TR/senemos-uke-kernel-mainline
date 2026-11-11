#!/usr/bin/env bash
# Historical12204 constructor. Later kernels must start from the full12204 SRPM.
set -Eeuo pipefail
trap 'rc=$?; printf "Next-camera production factory failed at line%s/exit%s\n" "$LINENO" "$rc" >&2; exit "$rc"' ERR
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 2 && $(rpm --eval '%{_host_cpu}') == aarch64 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "$1")
revision=$2
[[ $revision == 12204 ]] || {
    printf 'Retired12203-based constructor: retain full12204 and all later qualified handoffs in the next producer\n' >&2
    exit 1
}
bash "$owner/packaging/native/refuse-published-release.sh" senemos-uke-linux-kernel-mainline-unstable "7.3.1-$revision"
plan=$owner/manifests/camera-next-cohort731-20261105.json
[[ $(curl -q -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$(jq -er .combined_source_check "$plan")" | jq -er .state) == succeeded ]]
bash "$owner/packaging/native/assemble-camera-next731.sh" "$output"
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
native=senemos-native-profile-7.3.1.tar.xz
boot_archive=senemos-uke-boot-recipe.tar.xz
for archive in "$native" "$boot_archive"; do tar -xJf "$output/$archive" -C "$stage"; done
profile=$stage/native-profile
boot=$stage/boot-recipe
spec=$output/senemos-uke-linux-kernel-mainline-unstable.spec
jq -e '(.source_check_view_only // false)==false and .source_commit=="45d8355e366e6b75e43f441ca99b517302adf522"' \
    "$profile/source-composition.json" >/dev/null
audio_path=src/audio/uke-audio-card.c
audio_release="7.3.1-${revision}u"
audio_driver=uke${audio_release//./_}
[[ ${#audio_driver} -lt 16 ]]
for tree in "$profile" "$boot"; do
    [[ $(grep -Fo 'uke7.3.1-12203u' "$tree/$audio_path" | wc -l) == 2 ]]
    sed "s/uke7[.]3[.]1-12203u/uke$audio_release/g" "$tree/$audio_path" > "$stage/audio.c"
    sed "s/uke$audio_release/uke7.3.1-12203u/g" "$stage/audio.c" > "$stage/audio-before.c"
    cmp "$tree/$audio_path" "$stage/audio-before.c"
    install -m644 "$stage/audio.c" "$tree/$audio_path"
done
digest=$(sha256sum "$boot/$audio_path");digest=${digest%% *}
jq --arg path "$audio_path" --arg sha "$digest" \
    '(.source_assets[]|select(.path==$path)|.sha256)=$sha' "$boot/lock.json" > "$stage/lock.next"
install -m644 "$stage/lock.next" "$boot/lock.json"
bash "$profile/src/audio/desktop/install-policy.sh" "$stage/audio-policy" "7.3.1-$revision-unstable"
test -r "$stage/audio-policy/usr/share/alsa/ucm2/conf.d/$audio_driver/POCO-Pad-X1.conf"
history=source-composition-before-camera-next-identity.json
test ! -e "$profile/$history"
install -m644 "$profile/source-composition.json" "$profile/$history"
commit=$(git -C "$owner" rev-parse HEAD)
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg commit "$commit" --arg revision "$revision" --arg audio "$audio_driver" --arg history "$history" \
    --slurpfile plan "$plan" '. + {source_commit:$commit,
      kernel_release:("7.3.1-"+$revision+"-unstable"),rpm_revision:$revision,
      parent_copr_build:11262313,parent_source_commit:"45d8355e366e6b75e43f441ca99b517302adf522",
      parent_srpm_sha256:$plan[0].kernel_parent.sha256,parent_composition:$history,
      diagnostic_audio_driver:$audio,source_mode:(.source_mode+"+camera-gcc-and-qualified-postfreeze"),
      cumulative_source_manifest:"manifests/camera-next-cohort731-20261105.json",
      cumulative_qualified_checks:((.cumulative_qualified_checks+$plan[0].required_checks)|unique_by(.copr_build)),
      kernel_driver_source_unchanged:false,normal_kernel_promotion:false,
      device_installation:false,physical_acceptance:false}' \
    "$profile/$history" > "$profile/source-composition.json"
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
install -m644 "$boot/lock.json" "$output/boot-payload.json"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
for tree in native-profile boot-recipe; do
    archive=$native;[[ $tree != boot-recipe ]] || archive=$boot_archive
    tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
        -cJf "$output/$archive" -C "$stage" "$tree"
done
awk -v revision="$revision" '
 /^%global senemos_build_release 12203$/ {$0="%global senemos_build_release "revision;n++}
 /^bash native-profile\/packaging\/native\/check-cumulative-camera731.sh .* prepared$/ {
    print;print "bash native-profile/packaging/native/check-camera-next731.sh \"$PWD\" %{_uke_out} prepared";p++;next
 }
 /^bash native-profile\/packaging\/native\/check-cumulative-camera731.sh .* linked$/ {
    print;print "bash native-profile/packaging/native/check-camera-next731.sh \"$PWD\" %{_uke_out} linked";l++;next
 }
 /^%changelog$/ {
    print;print "* Thu Nov 05 2026 Uke contributors - 7.3.1-"revision
    print "- Retain complete12203 and all qualified cumulative peer contributions."
    print "- Restore exact OEM GCC camera configuration gates; keep physical admission separate."
    print "";next
 }
 {print}
 END {if(n!=1||p!=1||l!=1)exit 1}
' "$spec" > "$stage/spec.next"
install -m644 "$stage/spec.next" "$spec"
unlink "$output/camera-next-check-inputs.tar.xz"
bash "$owner/tests/unstable-boot-family731-contract.sh" "$spec"
[[ $(rpmspec --target aarch64 --define 'dist %{nil}' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$spec") == senemos-uke-linux-kernel-mainline-unstable-7.3.1-$revision ]]
printf 'One full cumulative unstable source candidate prepared; full/native/package/device camera gates remain required\n'

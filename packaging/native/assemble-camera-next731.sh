#!/usr/bin/env bash
# COPR only: layer the latest complete production SRPM, without reserving an NVR.
set -Eeuo pipefail
trap 'rc=$?; printf "Next-camera assembly failed at line%s/exit%s\n" "$LINENO" "$rc" >&2; exit "$rc"' ERR
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?Empty assembly output}")
plan=$owner/manifests/camera-next-cohort731-20261105.json
jq -e '.ssc.admission=="qualified" and (.ssc.source_commit|test("^[a-f0-9]{40}$"))' "$plan" >/dev/null
jq -e '(.layers|length)==6 and (.layers|map(.role)|unique|length)==6 and
 all(.layers[];.source_commit|test("^[a-f0-9]{40}$")) and
 .ssc.source_commit==(.layers[]|select(.role=="ssc")|.source_commit) and
 .ssc.copr_build==(.layers[]|select(.role=="ssc")|.copr_build) and
 any(.required_checks[];.copr_build==11263019 and
   .source_commit=="933cdd27eacbb38278c89e8fe345ad85cd391153")' "$plan" >/dev/null
while read -r build; do
    [[ $(curl -q -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$build" | jq -er .state) == succeeded ]]
done < <(jq -er '.required_checks[].copr_build' "$plan")
[[ ! -e $output || (-d $output && -z $(find "$output" -mindepth 1 -maxdepth 1 -print -quit)) ]]
stage=$(mktemp -d)
cleanup() {
    for role in governor observer pogo ssc inclusion inclusion_spec; do
        [[ ! -d $stage/$role ]] || git -C "$owner" worktree remove --force "$stage/$role"
    done
    find "$stage" -depth -delete
}
trap cleanup EXIT
curl -q -fLsS --retry 2 --max-time 600 --proto '=https' --proto-redir '=https' \
    "$(jq -er .kernel_parent.url "$plan")" -o "$stage/parent.src.rpm"
printf '%s  %s\n' "$(jq -er .kernel_parent.sha256 "$plan")" "$stage/parent.src.rpm" | sha256sum -c --strict -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/parent.src.rpm") == "$(jq -er .kernel_parent.rpm_nvr "$plan")" ]]
rpmkeys --checksig --nosignature --verbose "$stage/parent.src.rpm"
rpm2cpio "$stage/parent.src.rpm" > "$stage/parent.cpio"
cpio -t --quiet < "$stage/parent.cpio" | awk '/^\/|(^|\/)\.\.($|\/)/{bad=1} END{exit bad}'
mkdir -p "$output" "$stage/unpacked"
(cd "$output"; cpio -idm --quiet --no-absolute-filenames < "$stage/parent.cpio")
spec=$output/senemos-uke-linux-kernel-mainline-unstable.spec
native=senemos-native-profile-7.3.1.tar.xz
boot_archive=senemos-uke-boot-recipe.tar.xz
find "$output" -maxdepth 1 -type f ! -name "${spec##*/}" ! -name "$native" \
    ! -name "$boot_archive" ! -name boot-payload.json -print0 | sort -z | xargs -0 sha256sum > "$stage/retained-sources"
for archive in "$native" "$boot_archive"; do
    tar -tJf "$output/$archive" | awk '/^\/|(^|\/)\.\.($|\/)/{bad=1} END{exit bad}'
    tar -xJf "$output/$archive" -C "$stage/unpacked"
done
profile=$stage/unpacked/native-profile
boot=$stage/unpacked/boot-recipe
cmp "$boot/lock.json" "$output/boot-payload.json"
(cd "$profile"; sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
jq -e '.source_commit=="45d8355e366e6b75e43f441ca99b517302adf522" and
 .kernel_release=="7.3.1-12203-unstable" and .camcc_bootstrap_check==11261918 and
 .speaker_legacy_fixture_layer_commit=="f05c32a879b9c56abe3531365f95b85684af4510" and
 .physical_acceptance==false' "$profile/source-composition.json" >/dev/null
for tree in "$profile" "$boot"; do
    (cd "$tree"; find . -type f -print | sort) > "$stage/$(basename "$tree").paths"
done
while IFS=$'\t' read -r role commit; do
    [[ $role =~ ^(governor|observer|pogo|ssc|inclusion|inclusion_spec)$ && $commit =~ ^[a-f0-9]{40}$ ]]
    git -C "$owner" cat-file -e "$commit^{commit}" 2>/dev/null || git -C "$owner" fetch --depth=1 origin "$commit"
    git -C "$owner" worktree add --detach "$stage/$role" "$commit"
done < <(jq -er '.layers[]|[.role,.source_commit]|@tsv' "$plan")
mkdir -p "$stage/check-inputs/ssc-addon/original/src/sensors" "$stage/check-inputs/ssc-addon/original/tests" \
    "$stage/check-inputs/ssc-addon/v1/src/sensors" "$stage/check-inputs/ssc-addon/v1/tests" \
    "$stage/check-inputs/governor-addon" "$stage/check-inputs/union-addon/packaging/native"
for path in src/sensors/uke-ssc-iio.c src/sensors/uke-ssc-protocol.c src/sensors/uke-ssc-protocol.h \
    tests/ssc-native-host.h tests/ssc-native-contract.sh; do
    install -Dm644 "$profile/$path" "$stage/check-inputs/ssc-addon/original/$path"
done
# The unchanged old source is tested with the new behavioral assertions.
install -m644 "$stage/ssc/tests/ssc-native-contract.c" "$stage/check-inputs/ssc-addon/original/tests/ssc-native-contract.c"
superseded=0dcfd5bcd42867dbf15853fa20e9e64b18ce136e
git -C "$owner" cat-file -e "$superseded^{commit}" 2>/dev/null || git -C "$owner" fetch --depth=1 origin "$superseded"
for path in src/sensors/uke-ssc-protocol.c src/sensors/uke-ssc-protocol.h tests/ssc-native-host.h; do
    install -Dm644 "$profile/$path" "$stage/check-inputs/ssc-addon/v1/$path"
done
for path in src/sensors/uke-ssc-iio.c tests/ssc-native-contract.sh; do
    git -C "$owner" show "$superseded:$path" > "$stage/check-inputs/ssc-addon/v1/$path"
done
install -m644 "$stage/ssc/tests/ssc-native-contract.c" "$stage/check-inputs/ssc-addon/v1/tests/ssc-native-contract.c"
git -C "$stage/ssc" archive HEAD packaging/native/check-ssc-early731.sh manifests/ssc-early-layer-v2-20261105.json \
    | tar -xf - -C "$stage/check-inputs/ssc-addon"
mapfile -t governor_assets < <(jq -r '.assets[].path,.check_inputs[].path' \
    "$stage/governor/manifests/governor-options-layer-20261105.json";
    printf '%s\n' manifests/governor-options-layer-20261105.json)
git -C "$stage/governor" archive HEAD "${governor_assets[@]}" | tar -xf - -C "$stage/check-inputs/governor-addon"
printf '%s  %s\n' 20e003dea911755d9a08394661079e21aaaf111b69d94d13c8057a87f9cb7009 \
    "$owner/packaging/native/check-postfreeze-union.sh" | sha256sum -c --strict -
install -m644 "$owner/packaging/native/check-postfreeze-union.sh" \
    "$stage/check-inputs/union-addon/packaging/native/check-postfreeze-union.sh"
# Keep the governor's earlier-phase refusals/repeats before other composition additions.
bash "$stage/governor/tests/governor-layer-contract.sh" "$profile" "$boot" > "$output/governor-source-controls.txt"
bash "$stage/governor/tests/governor-spec-contract.sh" "$spec" >> "$output/governor-source-controls.txt"
bash "$stage/governor/packaging/native/overlay-governor-options731.sh" "$profile" "$boot"
bash "$stage/governor/packaging/native/overlay-governor-spec731.sh" "$spec"
observer=$(jq -er '.layers[]|select(.role=="observer")|.source_commit' "$plan")
bash "$stage/observer/packaging/native/overlay-speaker-state-observer.sh" "$profile" "$observer"
bash "$stage/pogo/src/pogo/apply-backlight.sh" "$profile"
bash "$stage/ssc/packaging/native/overlay-ssc-early731.sh" "$profile" "$boot"
sha256sum "$profile/SHA256SUMS" "$boot/lock.json" > "$stage/ssc-repeat"
bash "$stage/ssc/packaging/native/overlay-ssc-early731.sh" "$profile" "$boot"
sha256sum -c --strict "$stage/ssc-repeat"
inclusion=$(jq -er '.layers[]|select(.role=="inclusion")|.source_commit' "$plan")
bash "$stage/inclusion/packaging/native/overlay-speaker-inclusion-gate.sh" "$profile" "$inclusion"
bash "$stage/inclusion_spec/packaging/native/overlay-speaker-inclusion-spec.sh" "$spec"

# All coordinator additions are declared new assets, with authenticated bytes.
while IFS=$'\t' read -r path digest; do
    [[ $path =~ ^(src|tests|packaging|manifests|docs)/[a-zA-Z0-9_.,/-]+$ && $path != *..* ]]
    printf '%s  %s\n' "$digest" "$owner/$path" | sha256sum -c --strict --quiet -
    for tree in "$profile" "$boot"; do
        [[ ! -e $tree/$path && ! -L $tree/$path ]]
        install -Dm644 "$owner/$path" "$tree/$path"
    done
    jq --arg path "$path" --arg sha "$digest" \
        '.source_assets += [{path:$path,sha256:$sha}]' "$boot/lock.json" > "$stage/lock.next"
    install -m644 "$stage/lock.next" "$boot/lock.json"
done < <(jq -er '.assets[]|[.path,.sha256]|@tsv' "$plan")
history=source-composition-before-camera-next.json
test ! -e "$profile/$history"
install -m644 "$profile/source-composition.json" "$profile/$history"
jq --slurpfile plan "$plan" '. + {camera_gcc_config_layer:1,
 camera_gcc_config_check:11263019,camera_gcc_config_source:"933cdd27eacbb38278c89e8fe345ad85cd391153",
 camera_gcc_config_physical_acceptance:false,camera_next_layer_manifest:"manifests/camera-next-cohort731-20261105.json",
 camera_next_qualified_inputs:$plan[0].required_checks}' "$profile/$history" > "$profile/source-composition.json"
install -Dm644 "$plan" "$profile/manifests/camera-next-cohort731-20261105.json"
install -Dm644 "$plan" "$boot/manifests/camera-next-cohort731-20261105.json"
digest=$(sha256sum "$plan");digest=${digest%% *}
jq --arg sha "$digest" '.source_assets += [{path:"manifests/camera-next-cohort731-20261105.json",sha256:$sha}]' \
    "$boot/lock.json" > "$stage/lock.next"
install -m644 "$stage/lock.next" "$boot/lock.json"
jq -n --arg source "$(git -C "$owner" rev-parse HEAD)" \
    '{source_commit:$source,parent_source:"45d8355e366e6b75e43f441ca99b517302adf522",
      governor:"faca9d65778fda479d08df41785873d40c09e80f",
      audio:"13fb0ff522531924c0e96f81cef59d7c64b93eb8",
      pogo:"e9867405d0773065880863ea2df0dbd6242f5894",
      scope:"Retained qualified postfreeze source-check inputs; no physical acceptance"}' \
    > "$profile/postfreeze-union-check.json"

# Retain queued preparation as the final original hook; camera GCC runs before it.
awk '
 /^bash native-profile\/packaging\/native\/prepare-queued-kernel731.sh / {
  print "bash native-profile/src/camera/provider/apply-gcc-config731.sh \"$PWD\"";n++
 }
 {print}
 END {if(n!=1)exit 1}
' "$spec" > "$stage/spec.next"
install -m644 "$stage/spec.next" "$spec"
for tree in "$profile" "$boot"; do
    (cd "$tree"; find . -type f -print | sort) > "$stage/after.paths"
    test -z "$(comm -23 "$stage/$(basename "$tree").paths" "$stage/after.paths")"
done
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
install -m644 "$boot/lock.json" "$output/boot-payload.json"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
for tree in native-profile boot-recipe; do
    archive=$native;[[ $tree != boot-recipe ]] || archive=$boot_archive
    tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
        -cJf "$output/$archive" -C "$stage/unpacked" "$tree"
done
git -C "$owner" rev-parse HEAD > "$stage/check-inputs/source-commit"
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
    -cJf "$output/camera-next-check-inputs.tar.xz" -C "$stage/check-inputs" .
sha256sum -c --strict --quiet "$stage/retained-sources"
printf 'Complete12203 plus qualified camera/peer source assembly prepared; no kernel NVR, Image or target change\n'

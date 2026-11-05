#!/usr/bin/env bash
# COPR only: combine qualified post12203 source layers without a kernel release.
set -Eeuo pipefail
trap 'status=$?; printf "Postfreeze source check failed at line %s: %s (status %s)\n" "$LINENO" "$BASH_COMMAND" "$status" >&2; exit "$status"' ERR
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR source result directory}")
revision=${2:-17}
[[ $revision =~ ^[1-9][0-9]*$ ]]
stage=$(mktemp -d)
cleanup() {
 for role in governor audio pogo; do
  if [[ -d $stage/$role ]]; then git -C "$owner" worktree remove --force "$stage/$role"; fi
 done
 find "$stage" -depth -delete
}
trap cleanup EXIT
governor=faca9d65778fda479d08df41785873d40c09e80f
audio=13fb0ff522531924c0e96f81cef59d7c64b93eb8
pogo=e9867405d0773065880863ea2df0dbd6242f5894
for role in governor audio pogo; do
 commit=${!role}
 git -C "$owner" cat-file -e "$commit^{commit}" 2>/dev/null || git -C "$owner" fetch --depth=1 origin "$commit"
 git -C "$owner" worktree add --detach "$stage/$role" "$commit"
done
# Reuse the qualified exact12203 source factory; only the text-package name
# changes, including its existing cross-project immutable-version admission.
factory=$stage/governor/packaging/native/copr-governor-cumulative731-check.sh
printf '%s  %s\n' e071a77bc175b381781842ad8f82d6b9a8176a40395690dd19a9a69e37b02ab5 "$factory" | sha256sum -c --strict -
sed 's/uke-governor-cumulative-check/uke-o82-kms-check/g' "$factory" > "$stage/governor/packaging/native/postfreeze-base-factory.sh"
bash "$stage/governor/packaging/native/postfreeze-base-factory.sh" "$output" "$revision"
spec=$output/uke-o82-kms-check.spec
native_archive=senemos-native-profile-7.3.1.tar.xz
boot_archive=senemos-uke-boot-recipe.tar.xz
find "$output" -maxdepth 1 -type f ! -name "${spec##*/}" ! -name "$native_archive" ! -name "$boot_archive" -print0 |
 LC_ALL=C sort -z | xargs -0 sha256sum > "$stage/retained-outputs.sha256"
mkdir "$stage/unpacked"
for archive in "$native_archive" "$boot_archive"; do tar -xJf "$output/$archive" -C "$stage/unpacked"; done
profile=$stage/unpacked/native-profile
boot=$stage/unpacked/boot-recipe
cp "$profile/source-composition.json" "$stage/composition-before.json"
cat > "$stage/changed-paths" <<'PATHS'
./src/audio/uke-fs19xx-runtime.c
./src/pogo/hid-nanosic-uke.c
./src/pogo/nanosic-uke-hid.h
./src/pogo/nanosic-uke-protocol.h
./src/pogo/README.md
./tests/audio-speaker-state-read-contract.sh
./tests/nanosic-protocol-contract.sh
./tests/nanosic-lifecycle-contract.sh
./tests/nanosic-backlight-contract.sh
./tests/nanosic-power-contract.sh
./tests/nanosic-hid-contract.sh
./source-composition.json
./SHA256SUMS
PATHS
(cd "$profile"; find . -type f | LC_ALL=C sort | grep -Fvx -f "$stage/changed-paths") > "$stage/retained-paths"
(cd "$profile"; xargs -r sha256sum < "$stage/retained-paths") > "$stage/retained-profile.sha256"
(cd "$boot"; find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum) > "$stage/retained-boot.sha256"
bash "$stage/audio/packaging/native/overlay-speaker-state-observer.sh" "$profile" "$audio"
bash "$stage/pogo/src/pogo/apply-backlight.sh" "$profile"
(cd "$profile"; find . -type f | LC_ALL=C sort | grep -Fvx -f "$stage/changed-paths") > "$stage/after-paths"
cmp "$stage/retained-paths" "$stage/after-paths"
keys='del(.speaker_state_observer_layer_commit,.speaker_running_state_requires_guard,
 .pogo_backlight_source,.pogo_backlight_conditional_led,.pogo_outputs_require_host_token_delivery,
 .pogo_power_order,.pogo_touchpad_descriptor,.pogo_backlight_physical_acceptance)'
cmp <(jq -cS "$keys" "$stage/composition-before.json") <(jq -cS "$keys" "$profile/source-composition.json")
(cd "$profile"; sha256sum -c --strict --quiet "$stage/retained-profile.sha256")
(cd "$boot"; sha256sum -c --strict --quiet "$stage/retained-boot.sha256")
install -m644 "$stage/composition-before.json" "$profile/source-composition-before-postfreeze-union.json"
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS)
jq -n --arg source "$(git -C "$owner" rev-parse HEAD)" --arg governor "$governor" --arg audio "$audio" --arg pogo "$pogo" \
 '{schema_version:1,date:"2026-11-05",source_commit:$source,parent_source:"45d8355e366e6b75e43f441ca99b517302adf522",
 governor:$governor,audio:$audio,pogo:$pogo,scope:"Combined source/config/callback/object checks; no Image, final module or physical acceptance"}' > "$profile/postfreeze-union-check.json"
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS)
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
for tree in native-profile boot-recipe; do
 archive=$native_archive; [[ $tree != boot-recipe ]] || archive=$boot_archive
 tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$archive" -C "$stage/unpacked" "$tree"
done
mkdir "$stage/union-addon"
git -C "$owner" archive HEAD packaging/native/check-postfreeze-union.sh LICENSE LICENSES/GPL-2.0-only.txt |
 tar -xf - -C "$stage/union-addon"
git -C "$owner" rev-parse HEAD > "$stage/union-addon/source-commit"
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/postfreeze-union-addon.tar.xz" -C "$stage" union-addon
awk '
 /^Summary:/ {$0="Summary: Combined post12203 governor speaker and pogo source checks"}
 /^Source12:/ {print;print "Source13: postfreeze-union-addon.tar.xz";sources++;next}
 /^tar -xJf %\{SOURCE9\}$/ {print;print "tar -xJf %{SOURCE13}";preps++;next}
 /^bash governor-addon\/packaging\/native\/check-governor-cumulative731.sh / {
  sub("governor-addon/packaging/native/check-governor-cumulative731.sh","union-addon/packaging/native/check-postfreeze-union.sh");builds++
 }
 /^install -m644 governor-addon\/source-commit / {
  print "install -m644 governor-addon/source-commit %{buildroot}%{_docdir}/%{name}/governor-source-commit"
  print "install -m644 union-addon/source-commit %{buildroot}%{_docdir}/%{name}/source-commit"
  print "install -m644 native-profile/postfreeze-union-check.json %{buildroot}%{_docdir}/%{name}/union-inputs.json"
  installs++;next
 }
 {print}
 END {if(sources!=1||preps!=1||builds!=1||installs!=1)exit 1}
' "$spec" > "$stage/union.spec"
install -m644 "$stage/union.spec" "$spec"
sha256sum -c --strict --quiet "$stage/retained-outputs.sha256"
[[ $(rpmspec --target aarch64 -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$spec") == uke-o82-kms-check-7.3.1-$revision* ]]
printf '%s\n' 'Postfreeze source union prepared: exact12203 + governor/audio/pogo; no kernel revision or target state operation'

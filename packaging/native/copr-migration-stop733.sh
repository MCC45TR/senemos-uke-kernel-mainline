#!/usr/bin/env bash
# COPR only. Extend the qualified733 source factory without replacing its gates.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
manifest=$owner/manifests/stop-deadline-cumulative-20261107.json
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
output=$(realpath -m "${1:?Source result directory}")
revision=${2:?Automatically derived full release}
mode=${3:?check or full}
proof=${4:?Source-check release or admitted build}
[[ $mode == check || $mode == full ]]
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
# The focused receipt authenticates callbacks, not cumulative kernel objects.
curl -qfsSL --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11283674 > "$work/callback-build.json"
jq -e '.state=="succeeded" and .source_package.name=="uke-kernel-migration-check" and .source_package.version=="7.3.3-12"' "$work/callback-build.json" >/dev/null
curl -qfsSL --max-time 90 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable:custom:kernel-migration-20261105/fedora-rawhide-aarch64/11283674-uke-kernel-migration-check/uke-kernel-migration-check-7.3.3-12.fc46.aarch64.rpm -o "$work/callback.rpm"
printf '%s  %s\n' ad74e82b447fbb776f3aee6b3bb9e4c56a8c68f452b44d367b0ff0b4c6fadfb7 "$work/callback.rpm" | sha256sum -c --strict -
[[ $(rpm2cpio "$work/callback.rpm" | cpio -i --to-stdout --quiet '*source-commit') == 501bc599ced1e6be2b9c020b399cbbae86f4de33 ]]
bash "$owner/packaging/native/copr-migration-stable733.sh" "$@"
tuple=$(bash "$owner/scripts/kernel-release.sh" json "$owner/manifests/cumulative-release.json")
version=$(jq -er .version <<< "$tuple")
native=senemos-native-profile-$version.tar.xz
boot_archive=senemos-uke-boot-recipe.tar.xz
mkdir "$work/unpacked"
tar -xJf "$output/$native" -C "$work/unpacked"
tar -xJf "$output/$boot_archive" -C "$work/unpacked"
profile=$work/unpacked/native-profile
boot=$work/unpacked/boot-recipe
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$work/configs"
for tree in "$profile" "$boot";do
 for path in $(jq -r '.payload_assets[]' "$manifest");do
  install -Dm644 "$owner/$path" "$tree/$path"
 done
 install -Dm644 "$manifest" "$tree/manifests/${manifest##*/}"
 # Both legacy fixtures keep every assertion; only the synthetic timer is new.
 (cd "$tree";jq -r '.retained_fixture_hashes|to_entries[]|.value.before+"  "+.key' "$manifest" | sha256sum -c --strict -)
 git -C "$tree" apply --check --whitespace=error "$owner/src/audio/0024-muted-stop-legacy-clock.patch"
 git -C "$tree" apply --whitespace=error "$owner/src/audio/0024-muted-stop-legacy-clock.patch"
 (cd "$tree";jq -r '.retained_fixture_hashes|to_entries[]|.value.after+"  "+.key' "$manifest" | sha256sum -c --strict -)
done
# Only native-profile checks run against the prepared cumulative kernel.
# Boot-recipe's historical checker bytes remain intact.
(cd "$profile";jq -r '.retained_helper_hashes|to_entries[]|.value.before+"  "+.key' "$manifest" | sha256sum -c --strict -)
git -C "$profile" apply --check --whitespace=error "$owner/src/audio/0023-muted-stop-source-seals.patch"
git -C "$profile" apply --whitespace=error "$owner/src/audio/0023-muted-stop-source-seals.patch"
(cd "$profile";jq -r '.retained_helper_hashes|to_entries[]|.value.after+"  "+.key' "$manifest" | sha256sum -c --strict -)
cp "$profile/source-composition.json" "$profile/source-composition-before-stop-deadline.json"
jq --arg mode "$mode" --arg proof "$proof" '.+{
 muted_stop_deadline_layer:1,muted_stop_deadline_ms:6000,
 muted_stop_all_readbacks_before_mode1:true,muted_stop_faults_retained:true,
 muted_stop_startup_poll_budget_unchanged:true,muted_stop_gain_and_calibration_unchanged:true,
 muted_stop_callback_build:11283674,muted_stop_callback_source:"501bc599ced1e6be2b9c020b399cbbae86f4de33",
 muted_stop_callback_case_count:100,muted_stop_callback_modes:12,
 muted_stop_native_admitted:($mode=="full"),
 muted_stop_qualification_build:(if $mode=="full" then ($proof|tonumber) else null end),
 device_installation:false,physical_acceptance:false}' "$profile/source-composition-before-stop-deadline.json" > "$profile/source-composition.json"
for name in senemos-uke-linux-kernel-mainline-unstable.spec uke-kernel-migration-check.spec;do
 spec=$output/$name
 [[ -e $spec ]] || continue
 phase=linked;[[ $name != uke-kernel-migration-check.spec ]] || phase=objects
 changelog_release=$revision;[[ $mode != check ]] || changelog_release=$proof
 awk -v phase="$phase" -v version="$version" -v release="$changelog_release" '
  /^bash native-profile\/src\/display\/apply-vrr-api731.sh / {
   print;print "bash native-profile/src/audio/apply-stop-deadline733.sh \"$PWD\" \"$PWD/native-profile\"";prep++;next
  }
  $0=="bash native-profile/packaging/native/check-stable733.sh \"$PWD\" %{_uke_out} "phase {
   print;print "bash native-profile/packaging/native/check-stop-deadline733.sh \"$PWD\" %{_uke_out} "phase;checked++;next
  }
  /^%changelog$/ {
   print;print "* Sat Nov 07 2026 Uke contributors - "version"-"release;
   print "- Retain feedback through the finite muted APM STOP completion window.";
   print "- Publish configured mode after all four DAC mute readbacks complete.";
   print "- Preserve gain223, startup checks, all faults and cumulative features.";print "";next
  }
  {print}END{if(prep!=1||checked!=1)exit 1}
 ' "$spec" > "$work/updated.spec"
 install -m644 "$work/updated.spec" "$spec"
 # Text proof packages and the complete kernel both omit extra debug RPMs.
 grep -Fx '%global debug_package %{nil}' "$spec"
done
sha256sum -c --strict --quiet "$work/configs"
(cd "$profile";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot";find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$work/assets.sha256"
jq -Rn '[inputs|capture("^(?<sha256>[a-f0-9]{64})  [.]?/?(?<path>.*)$")]|map({path,sha256})' < "$work/assets.sha256" > "$work/assets.json"
jq --slurpfile assets "$work/assets.json" '.source_assets=$assets[0]' "$boot/lock.json" > "$work/lock.json"
install -m644 "$work/lock.json" "$boot/lock.json"
install -m644 "$boot/lock.json" "$output/boot-payload.json"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$native" -C "$work/unpacked" native-profile
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$boot_archive" -C "$work/unpacked" boot-recipe
printf 'Complete cumulative%s-%s muted STOP recipe prepared:%s; original config and full gates retained, no debug RPMs or physical acceptance.\n' "$version" "$revision" "$mode"

#!/usr/bin/env bash
# COPR only. Add physical initial-level admission to the complete memory/audio candidate.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
manifest=$owner/manifests/hall-initial-cumulative-20261107.json
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
output=$(realpath -m "${1:?Source result directory}")
mode=${3:?check or full}
[[ $mode == check || $mode == full ]]
tuple=$(bash "$owner/scripts/kernel-release.sh" json "$owner/manifests/cumulative-release.json")
version=$(jq -er .version <<< "$tuple")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
if [[ $mode == full ]];then
 [[ $# == 5 && $4 =~ ^[1-9][0-9]*$ && $5 =~ ^[a-f0-9]{64}$ ]]
 url=$(curl -qfsSL --max-time 45 "https://copr.fedorainfracloud.org/api_3/build-chroot/$4/fedora-rawhide-aarch64" | jq -er .result_url)
 curl -qfsSL --max-time 90 "${url}uke-kernel-migration-check-$(jq -er .source_check_evr <<< "$tuple").fc46.aarch64.rpm" -o "$work/proof.rpm"
 printf '%s  %s\n' "$5" "$work/proof.rpm" | sha256sum -c --strict --quiet -
 rpm2cpio "$work/proof.rpm" | cpio -i --to-stdout --quiet '*source-composition.json' | jq -e '.hall_physical_initial_layer==1 and .hall_physical_initial_optional and .hall_physical_initial_input_only and .hall_physical_initial_remote_irq_unchanged and (.hall_physical_initial_native_admitted|not) and (.physical_acceptance|not)' >/dev/null
fi
bash "$owner/packaging/native/copr-memory-compression733.sh" "$@"
native=senemos-native-profile-$version.tar.xz
boot_archive=senemos-uke-boot-recipe.tar.xz
tar -xJf "$output/$native" -C "$work"
tar -xJf "$output/$boot_archive" -C "$work"
profile=$work/native-profile
boot=$work/boot-recipe
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$work/configs.sha256"
history=$profile/history-before-hall-initial
[[ ! -e $history ]]
mkdir "$history"
cp "$profile/src/boot/uke-hall.h" "$history/uke-hall.h"
cp "$profile/packaging/native/check-migration-cohort731.sh" "$history/check-migration-cohort731.sh"
cp "$profile/tests/hall-startup-controls.sh" "$history/hall-startup-controls.sh"
(cd "$history";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
for tree in "$profile" "$boot";do
 while IFS= read -r file;do install -Dm644 "$owner/$file" "$tree/$file";done < <(jq -r '.payload_assets[]' "$manifest")
 install -Dm644 "$manifest" "$tree/manifests/${manifest##*/}"
 git -C "$tree" apply --check --whitespace=error "$owner/src/input/0004-hall-initial-gpio-dt.patch"
 git -C "$tree" apply --whitespace=error "$owner/src/input/0004-hall-initial-gpio-dt.patch"
done
awk '
 $0=="profile=$kernel/native-profile" {print;print "hall_initial_legacy=$(bash \"$profile/packaging/native/hall-initial-source-view733.sh\" \"$kernel\")";init++;next}
 {if(sub(/"\$kernel\/drivers\/input\/misc\/qcom-smp2p-switch[.]c"/,"\"$hall_initial_legacy\""))paths++;print}
 END{if(init!=1||paths!=3)exit 1}
' "$history/check-migration-cohort731.sh" > "$profile/packaging/native/check-migration-cohort731.sh"
awk '
 $0=="driver=$kernel/drivers/input/misc/qcom-smp2p-switch.c" {print "driver=$(bash \"$root/packaging/native/hall-initial-source-view733.sh\" \"$kernel\")";n++;next}
 {print}END{if(n!=1)exit 1}
' "$history/hall-startup-controls.sh" > "$profile/tests/hall-startup-controls.sh"
cp "$profile/source-composition.json" "$profile/source-composition-before-hall-initial.json"
jq --arg mode "$mode" --arg proof "$4" '.+{
 hall_physical_initial_layer:1,hall_physical_initial_optional:true,
 hall_physical_initial_active_low:true,hall_physical_initial_input_only:true,
 hall_physical_initial_remote_irq_unchanged:true,hall_physical_initial_gpio_released:true,
 hall_physical_initial_samples:2,hall_physical_initial_debounce_us:[1000,2000],
 hall_physical_initial_native_admitted:($mode=="full"),
 hall_physical_initial_qualification_build:(if $mode=="full" then ($proof|tonumber) else null end),
 device_installation:false,physical_acceptance:false}' "$profile/source-composition-before-hall-initial.json" > "$profile/source-composition.json"
for name in senemos-uke-linux-kernel-mainline-unstable.spec uke-kernel-migration-check.spec;do
 spec=$output/$name
 [[ -e $spec ]] || continue
 phase=linked;[[ $name != uke-kernel-migration-check.spec ]] || phase=objects
 awk -v phase="$phase" '
  /^bash native-profile\/src\/audio\/apply-enable-readback733.sh / {print;print "bash native-profile/src/input/apply-hall-initial-gpio733.sh \"$PWD\"";prep++;next}
  $0=="bash native-profile/packaging/native/check-migration-cohort731.sh \"$PWD\" %{_uke_out} prepared" {print;print "bash native-profile/packaging/native/check-hall-initial733.sh \"$PWD\" %{_uke_out} prepared";tests++;next}
  $0=="bash native-profile/packaging/native/check-memory-compression733.sh \"$PWD\" %{_uke_out} "phase {print;print "bash native-profile/packaging/native/check-hall-initial733.sh \"$PWD\" %{_uke_out} "phase;objects++;next}
  {print}END{if(prep!=1||tests!=1||objects!=1)exit 1}
 ' "$spec" > "$work/updated.spec"
 install -m644 "$work/updated.spec" "$spec"
 grep -Fx '%global debug_package %{nil}' "$spec"
done
sha256sum -c --strict --quiet "$work/configs.sha256"
(cd "$profile";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot";find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$work/assets.sha256"
jq -Rn '[inputs|capture("^(?<sha256>[a-f0-9]{64})  [.]?/?(?<path>.*)$")]|map({path,sha256})' < "$work/assets.sha256" > "$work/assets.json"
jq --slurpfile assets "$work/assets.json" '.source_assets=$assets[0]' "$boot/lock.json" > "$work/lock.json"
install -m644 "$work/lock.json" "$boot/lock.json"
install -m644 "$boot/lock.json" "$output/boot-payload.json"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$native" -C "$work" native-profile
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$boot_archive" -C "$work" boot-recipe
printf 'Complete cumulative Hall initial-level recipe prepared; fixed audio and memory capabilities retained, stationary closed boot acceptance separate.\n'

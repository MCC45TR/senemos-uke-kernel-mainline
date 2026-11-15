#!/usr/bin/env bash
# COPR only: retain cumulative7332 and qualify independent PCM period delivery.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
manifest=$owner/manifests/pcm-period-cumulative-20261107.json
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
output=$(realpath -m "${1:?Source result directory}")
revision=${2:?Automatically derived full release}
mode=${3:?check or full}
proof=${4:?Source-check release or admitted build}
[[ $mode == check || $mode == full ]]
bash "$owner/packaging/native/copr-migration-stop733.sh" "$@"
tuple=$(bash "$owner/scripts/kernel-release.sh" json "$owner/manifests/cumulative-release.json")
version=$(jq -er .version <<< "$tuple")
native=senemos-native-profile-$version.tar.xz
boot_archive=senemos-uke-boot-recipe.tar.xz
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
tar -xJf "$output/$native" -C "$work"
tar -xJf "$output/$boot_archive" -C "$work"
profile=$work/native-profile
boot=$work/boot-recipe
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$work/configs"
for tree in "$profile" "$boot";do
 while IFS= read -r asset;do install -Dm644 "$owner/$asset" "$tree/$asset";done < <(jq -r '.payload_assets[]' "$manifest")
 install -Dm644 "$manifest" "$tree/manifests/${manifest##*/}"
done
cp "$profile/source-composition.json" "$profile/source-composition-before-pcm-period.json"
jq --arg mode "$mode" --arg proof "$proof" '.+{
 pcm_period_work_layer:1,pcm_period_work_queue:"system_unbound_wq",
 pcm_period_close_gate_and_drain:true,pcm_period_compressed_unchanged:true,
 pcm_period_capture_eos_unchanged:true,pcm_period_native_admitted:($mode=="full"),
 pcm_period_qualification_build:(if $mode=="full" then ($proof|tonumber) else null end),
 pcm_period_source_before:"acb1773a93e99881ff51bcc78c26e8d48b6e8c59cb396755d47100dd91a6797b",
 pcm_period_source_after:"f14978b215fe56b1e5505ca9f36da9633c5631fd7b1be40ae85896aea86d7e65",
 device_installation:false,physical_acceptance:false}' "$profile/source-composition-before-pcm-period.json" > "$profile/source-composition.json"
for name in senemos-uke-linux-kernel-mainline-unstable.spec uke-kernel-migration-check.spec;do
 spec=$output/$name
 [[ -e $spec ]] || continue
 phase=linked;[[ $name != uke-kernel-migration-check.spec ]] || phase=objects
 changelog_release=$revision;[[ $mode != check ]] || changelog_release=$proof
 awk -v phase="$phase" -v version="$version" -v release="$changelog_release" '
  /^bash native-profile\/src\/audio\/apply-stop-deadline733.sh / {
   print;print "bash native-profile/src/audio/apply-pcm-period733.sh \"$PWD\" \"$PWD/native-profile\"";prep++;next
  }
  $0=="bash native-profile/packaging/native/check-stop-deadline733.sh \"$PWD\" %{_uke_out} "phase {
   print;print "bash native-profile/packaging/native/check-pcm-period733.sh \"$PWD\" %{_uke_out} "phase;checked++;next
  }
  /^ drivers\/firmware\/arm_scmi\/uke-cpucp-observe.o / {
   if(sub(/sound\/soc\/qcom\/qdsp6\/q6apm.o /,"sound/soc/qcom/qdsp6/q6apm.o sound/soc/qcom/qdsp6/q6apm-dai.o "))objects++
  }
  /^%changelog$/ {
   print;print "* Sat Nov 07 2026 Uke contributors - "version"-"release;
   print "- Deliver PCM periods independently of ordered GPR command reception.";
   print "- Drain reports before PCM release; retain compressed and capture paths.";
   print "- Preserve all cumulative features, protected223 and existing admission.";print "";next
  }
  {print}END{if(prep!=1||checked!=1||(phase=="objects"&&objects!=1)||(phase=="linked"&&objects))exit 1}
 ' "$spec" > "$work/updated.spec"
 install -m644 "$work/updated.spec" "$spec"
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
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$native" -C "$work" native-profile
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$boot_archive" -C "$work" boot-recipe
printf 'Complete cumulative%s-%s PCM period recipe prepared:%s; original config/full gates retained, no debug RPMs or physical acceptance.\n' "$version" "$revision" "$mode"

#!/usr/bin/env bash
# COPR only: retain the complete PCM-qualified recipe and add enable diagnostics.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
manifest=$owner/manifests/speaker-enable-control-cumulative-20261107.json
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
output=$(realpath -m "${1:?Source result directory}")
revision=${2:?History-derived full release}
mode=${3:?check or full}
proof=${4:?Source release or admitted check build}
[[ $mode == check || $mode == full ]]
tuple=$(bash "$owner/scripts/kernel-release.sh" json "$owner/manifests/cumulative-release.json")
version=$(jq -er .version <<< "$tuple")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
if [[ $mode == full ]];then
 [[ $# == 5 && $5 =~ ^[a-f0-9]{64}$ ]]
 curl -qfsSL --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$proof" > "$work/proof.json"
 jq -e --arg evr "$(jq -er .source_check_evr <<< "$tuple")" '.state=="succeeded" and .source_package.name=="uke-kernel-migration-check" and .source_package.version==$evr' "$work/proof.json" >/dev/null
 url=$(curl -qfsSL --max-time 45 "https://copr.fedorainfracloud.org/api_3/build-chroot/$proof/fedora-rawhide-aarch64" | jq -er .result_url)
 curl -qfsSL --max-time 90 "${url}uke-kernel-migration-check-$(jq -er .source_check_evr <<< "$tuple").fc46.aarch64.rpm" -o "$work/proof.rpm"
 printf '%s  %s\n' "$5" "$work/proof.rpm" | sha256sum -c --strict -
 rpm2cpio "$work/proof.rpm" | cpio -i --to-stdout --quiet '*source-composition.json' | jq -e '.speaker_enable_readback_layer==1 and .speaker_enable_readback_read_only and .speaker_enable_readback_privileged and .speaker_enable_readback_owner_and_generation and .speaker_enable_readback_client_byte and (.speaker_enable_readback_native_admitted|not) and .speaker_gain_ceiling==223 and (.physical_acceptance|not)' >/dev/null
fi
bash "$owner/packaging/native/copr-migration-pcm733.sh" "$@"
native=senemos-native-profile-$version.tar.xz
boot_archive=senemos-uke-boot-recipe.tar.xz
tar -xJf "$output/$native" -C "$work"
tar -xJf "$output/$boot_archive" -C "$work"
profile=$work/native-profile
boot=$work/boot-recipe
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$work/configs"
for tree in "$profile" "$boot";do
 while IFS= read -r file;do install -Dm644 "$owner/$file" "$tree/$file";done < <(jq -r '.payload_assets[]' "$manifest")
 install -Dm644 "$manifest" "$tree/manifests/${manifest##*/}"
 printf '%s  %s\n' a67238ed0039ad9dc69ddcf421534f27fc884e62b3980f3398fe3cf3eb208daa "$tree/tests/audio-speaker-state-store-contract.sh" | sha256sum -c --strict -
 install -Dm644 "$tree/tests/audio-speaker-state-store-contract.sh" "$tree/history-before-enable-readback/tests/audio-speaker-state-store-contract.sh"
 git -C "$tree" apply --check --whitespace=error "$owner/src/audio/0027-enable-store-fixture.patch"
 git -C "$tree" apply --whitespace=error "$owner/src/audio/0027-enable-store-fixture.patch"
done
cp "$profile/source-composition.json" "$profile/source-composition-before-enable-readback.json"
jq --arg mode "$mode" --arg proof "$proof" '.+{
 speaker_enable_readback_layer:1,speaker_enable_readback_read_only:true,
 speaker_enable_readback_privileged:true,speaker_enable_readback_owner_and_generation:true,
 speaker_enable_readback_client_byte:true,speaker_enable_readback_shared_dma:false,
 speaker_enable_readback_query_timeout_ms:250,speaker_enable_readback_limiter_claim:false,
 speaker_enable_readback_native_admitted:($mode=="full"),
 speaker_enable_readback_qualification_build:(if $mode=="full" then ($proof|tonumber) else null end),
 device_installation:false,physical_acceptance:false}' "$profile/source-composition-before-enable-readback.json" > "$profile/source-composition.json"
for name in senemos-uke-linux-kernel-mainline-unstable.spec uke-kernel-migration-check.spec;do
 spec=$output/$name
 [[ -e $spec ]] || continue
 phase=linked;[[ $name != uke-kernel-migration-check.spec ]] || phase=objects
 awk -v phase="$phase" '
  /^bash native-profile\/src\/audio\/apply-pcm-period733.sh / {
   print;print "bash native-profile/src/audio/apply-enable-readback733.sh \"$PWD\" \"$PWD/native-profile\"";prep++;next
  }
  $0=="bash native-profile/packaging/native/check-pcm-period733.sh \"$PWD\" %{_uke_out} "phase {
   print;print "bash native-profile/packaging/native/check-enable-readback733.sh \"$PWD\" %{_uke_out} "phase;checked++;next
  }
  /^ drivers\/firmware\/arm_scmi\/uke-cpucp-observe.o / {
   if(sub(/sound\/soc\/qcom\/qdsp6\/q6apm-dai.o /,"sound/soc/qcom/qdsp6/q6apm-dai.o sound/soc/qcom/qdsp6/uke-fs19xx-readback.o "))objects++
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
printf 'Complete cumulative%s-%s enable-query recipe prepared:%s; no gain/limiter claim or target operation.\n' "$version" "$revision" "$mode"

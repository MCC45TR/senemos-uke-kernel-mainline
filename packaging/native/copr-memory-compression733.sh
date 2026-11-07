#!/usr/bin/env bash
# COPR only. Extend every qualified audio/DT/config gate with upstream memory support.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
manifest=$owner/manifests/memory-compression-cumulative-20261107.json
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
 rpm2cpio "$work/proof.rpm" | cpio -i --to-stdout --quiet '*source-composition.json' | jq -e '.memory_compression_layer==1 and .memory_compression_zram_multi and .memory_compression_zswap_built and (.memory_compression_zswap_default_enabled|not) and .memory_compression_no_swap_policy_change and (.memory_compression_native_admitted|not) and (.physical_acceptance|not)' >/dev/null
fi
bash "$owner/packaging/native/copr-enable-readback733.sh" "$@"
native=senemos-native-profile-$version.tar.xz
boot_archive=senemos-uke-boot-recipe.tar.xz
tar -xJf "$output/$native" -C "$work"
tar -xJf "$output/$boot_archive" -C "$work"
profile=$work/native-profile
boot=$work/boot-recipe
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
old=$(jq -er .migration_native_config_sha256 "$profile/source-composition.json")
[[ $old == ef98810f064de0f97a1ef9361737d37cd7d7353fdfb0e71fc7979fca456c9136 ]]
printf '%s  %s\n' "$old" "$profile/native.config" "$old" "$boot/packaging/native/native.config" | sha256sum -c --strict --quiet -
history=$profile/history-before-memory-compression
[[ ! -e $history ]]
mkdir "$history"
cp "$profile/native.config" "$history/native.config"
cp "$profile/configs/kernel-manager/resources.config" "$history/resources.config"
cp "$profile/configs/kernel-manager/resource-dependencies.txt" "$history/resource-dependencies.txt"
cp "$profile/packaging/native/check-cumulative-camera731.sh" "$history/check-cumulative-camera731.sh"
(cd "$history";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
[[ $(grep -Fxc CONFIG_ZSMALLOC=m "$history/resource-dependencies.txt") == 1 ]]
for tree in "$profile" "$boot";do
 while IFS= read -r file;do install -Dm644 "$owner/$file" "$tree/$file";done < <(jq -r '.payload_assets[]' "$manifest")
 install -Dm644 "$manifest" "$tree/manifests/${manifest##*/}"
done
cat "$profile/configs/memory-compression733.config" >> "$profile/configs/kernel-manager/resources.config"
{ sed '/^CONFIG_ZSMALLOC=m$/d' "$history/resource-dependencies.txt";printf '%s\n' CONFIG_842_COMPRESS=y CONFIG_842_DECOMPRESS=y CONFIG_LZ4HC_COMPRESS=y 'CONFIG_ZSWAP_COMPRESSOR_DEFAULT="lz4"'; } > "$profile/configs/kernel-manager/resource-dependencies.txt"
mkdir -p "$work/config-tool/scripts"
tar -xOJf "$output/linux-$version.tar.xz" "linux-$version/scripts/config" > "$work/config-tool/scripts/config"
bash "$profile/packaging/native/apply-kernel-manager-config.sh" "$work/config-tool" "$profile/native.config" "$work/expanded.config" "$profile/configs/kernel-manager/resources.config"
install -m644 "$work/expanded.config" "$profile/native.config"
install -m644 "$profile/native.config" "$boot/packaging/native/native.config"
for file in resources.config resource-dependencies.txt;do install -Dm644 "$profile/configs/kernel-manager/$file" "$boot/configs/kernel-manager/$file";done
new=$(sha256sum "$profile/native.config");new=${new%% *}
[[ $new != "$old" && $(grep -Fc "$old" "$history/check-cumulative-camera731.sh") -ge 1 ]]
sed "s/$old/$new/g" "$history/check-cumulative-camera731.sh" > "$profile/packaging/native/check-cumulative-camera731.sh"
cp "$profile/source-composition.json" "$profile/source-composition-before-memory-compression.json"
jq --arg old "$old" --arg new "$new" --arg mode "$mode" --arg proof "$4" '.+{
 migration_native_config_sha256:$new,memory_compression_layer:1,
 memory_compression_previous_native_config_sha256:$old,
 memory_compression_zram_extra_backends:["lz4hc","deflate","842"],
 memory_compression_zram_multi:true,memory_compression_zswap_built:true,
 memory_compression_zswap_default_enabled:false,memory_compression_no_swap_policy_change:true,
 memory_compression_zsmalloc_builtin:true,memory_compression_native_admitted:($mode=="full"),
 memory_compression_qualification_build:(if $mode=="full" then ($proof|tonumber) else null end),
 device_installation:false,physical_acceptance:false}' "$profile/source-composition-before-memory-compression.json" > "$profile/source-composition.json"
for name in senemos-uke-linux-kernel-mainline-unstable.spec uke-kernel-migration-check.spec;do
 spec=$output/$name
 [[ -e $spec ]] || continue
 phase=linked;[[ $name != uke-kernel-migration-check.spec ]] || phase=objects
 awk -v phase="$phase" '
  $0=="bash native-profile/packaging/native/check-enable-readback733.sh \"$PWD\" %{_uke_out} "phase {print;print "bash native-profile/packaging/native/check-memory-compression733.sh \"$PWD\" %{_uke_out} "phase;checked++;next}
  /^ drivers\/firmware\/arm_scmi\/uke-cpucp-observe.o / {if(sub(/sound\/soc\/qcom\/qdsp6\/uke-fs19xx-readback.o /,"sound/soc/qcom/qdsp6/uke-fs19xx-readback.o drivers/block/zram/zram.o mm/zswap.o mm/zsmalloc.o "))objects++}
  {print}END{if(checked!=1||(phase=="objects"&&objects!=1)||(phase=="linked"&&objects))exit 1}
 ' "$spec" > "$work/updated.spec"
 install -m644 "$work/updated.spec" "$spec"
 grep -Fx '%global debug_package %{nil}' "$spec"
done
(cd "$profile";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot";find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$work/assets.sha256"
jq -Rn '[inputs|capture("^(?<sha256>[a-f0-9]{64})  [.]?/?(?<path>.*)$")]|map({path,sha256})' < "$work/assets.sha256" > "$work/assets.json"
jq --slurpfile assets "$work/assets.json" '.source_assets=$assets[0]' "$boot/lock.json" > "$work/lock.json"
install -m644 "$work/lock.json" "$boot/lock.json"
install -m644 "$boot/lock.json" "$output/boot-payload.json"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$native" -C "$work" native-profile
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$boot_archive" -C "$work" boot-recipe
printf 'Complete cumulative memory recipe: fixed audio query, ZRAM backends/multi and default-off Zswap; no new package or runtime policy.\n'

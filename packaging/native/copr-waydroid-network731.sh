#!/usr/bin/env bash
# COPR only: retain the7300 producer and enable Android policy routing/filtering.
set -Eeuo pipefail
export LC_ALL=C
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
revision=7801
bash "$owner/packaging/native/refuse-published-release.sh" \
 senemos-uke-linux-kernel-mainline-unstable "7.3.1-$revision"
bash "$owner/packaging/native/copr-unstable-boot731.sh" "$output" "$revision" 0 1
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
mkdir -p "$stage/unpacked"
for archive in senemos-native-profile-7.3.1.tar.xz senemos-uke-boot-recipe.tar.xz; do
 tar -tJf "$output/$archive" > "$stage/entries"
 awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/entries"
 tar -xJf "$output/$archive" -C "$stage/unpacked"
done
profile=$stage/unpacked/native-profile
boot=$stage/unpacked/boot-recipe
(cd "$profile"; sha256sum --check --strict --quiet SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
cmp "$profile/native.config" "$boot/packaging/native/native.config"
bash "$owner/tests/native-firewall-builtins-contract.sh" \
 "$owner/tests/native-firewall-contract.sh" "$owner/packaging/native/native.config"
for tree in "$profile" "$boot"; do
 install -m644 "$owner/tests/native-firewall-contract.sh" "$tree/tests/native-firewall-contract.sh"
done
guard_hash=$(sha256sum "$boot/tests/native-firewall-contract.sh"); guard_hash=${guard_hash%% *}
jq --arg hash "$guard_hash" \
 '(.source_assets[]|select(.path=="tests/native-firewall-contract.sh")|.sha256)=$hash' \
 "$boot/lock.json" > "$stage/guard-lock.json"
cp "$stage/guard-lock.json" "$boot/lock.json"
cp "$profile/native.config" "$stage/before.config"
fragment=$owner/configs/waydroid-network.config
awk '
 FNR==NR {if ($0 ~ /^CONFIG_/) {split($0,a,"="); wanted[a[1]]=1; lines[++n]=$0} next}
 /^CONFIG_/ {split($0,a,"="); if (a[1] in wanted) next}
 /^# CONFIG_.* is not set$/ {if ($2 in wanted) next}
 {print}
 END {for(i=1;i<=n;i++) print lines[i]}
' "$fragment" "$stage/before.config" > "$profile/native.config"
cp "$profile/native.config" "$boot/packaging/native/native.config"
# Every unrelated input setting remains byte-for-byte equivalent.
awk -F= '/^CONFIG_/ {print $1}' "$fragment" > "$stage/keys"
for version in before after; do
 input=$stage/before.config
 [[ $version != after ]] || input=$profile/native.config
 awk 'FNR==NR {keys[$0]=1;next}
 /^CONFIG_/ {split($0,a,"=");if(a[1] in keys)next}
 /^# CONFIG_.* is not set$/ {if($2 in keys)next} {print}' \
 "$stage/keys" "$input" > "$stage/$version.retained"
done
cmp "$stage/before.retained" "$stage/after.retained"
config_hash=$(sha256sum "$profile/native.config"); config_hash=${config_hash%% *}
jq --arg hash "$config_hash" \
 '(.source_assets[]|select(.path=="packaging/native/native.config")|.sha256)=$hash' \
 "$boot/lock.json" > "$stage/lock.json"
cp "$stage/lock.json" "$boot/lock.json"
cp "$stage/lock.json" "$output/boot-payload.json"
cp "$profile/source-composition.json" "$profile/source-composition-before-waydroid-network.json"
producer=$(git -C "$owner" rev-parse HEAD)
jq --arg hash "$config_hash" --arg producer "$producer" '. + {
 native_config_sha256:$hash, waydroid_network_producer_commit:$producer,
 waydroid_network_overlay:true,waydroid_policy_routing_builtin:true,
 waydroid_legacy_filter_builtin:true,waydroid_network_runtime_qualified:false,
 waydroid_network_parent_producer:"00ebf622ca473b9b7a799b2f531b4871ddc70497",
 waydroid_network_parent_composition:"source-composition-before-waydroid-network.json",
 kernel_driver_source_unchanged:true,physical_acceptance:false
 }' "$profile/source-composition-before-waydroid-network.json" > "$profile/source-composition.json"
install -Dm644 "$fragment" "$profile/configs/waydroid-network.config"
install -Dm644 "$stage/before.config" "$profile/configs/waydroid-firewall-modular-reference.config"
install -Dm644 "$owner/tests/waydroid-network-built731.sh" "$profile/tests/waydroid-network-built731.sh"
install -Dm644 "$owner/tests/native-firewall-builtins-contract.sh" "$profile/tests/native-firewall-builtins-contract.sh"
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
for tree in native-profile boot-recipe; do
 archive=senemos-native-profile-7.3.1.tar.xz
 [[ $tree != boot-recipe ]] || archive=senemos-uke-boot-recipe.tar.xz
 tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
  -cJf "$output/$archive" -C "$stage/unpacked" "$tree"
done
spec=$output/senemos-uke-linux-kernel-mainline-unstable.spec
awk '
 /^%check$/ {
  print
  print "bash native-profile/tests/native-firewall-builtins-contract.sh native-profile/tests/native-firewall-contract.sh native-profile/configs/waydroid-firewall-modular-reference.config"
  print "bash native-profile/tests/waydroid-network-built731.sh %{_uke_out} native-profile/configs/waydroid-network.config"; checks++; next
 }
 {print} END {if(checks!=1)exit 1}
' "$spec" > "$stage/kernel.spec"
cp "$stage/kernel.spec" "$spec"
printf 'Waydroid network input config: %s; producer: %s\n' "$config_hash" "$producer"

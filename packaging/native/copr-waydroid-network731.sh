#!/usr/bin/env bash
# COPR only: retain the current color/7300 cohort and add Android networking.
set -Eeuo pipefail
export LC_ALL=C
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
revision=${2:?Fresh unstable kernel revision}
[[ $revision =~ ^[1-9][0-9]{3,4}$ && $revision -ge 10000 ]]
bash "$owner/packaging/native/refuse-published-release.sh" \
 senemos-uke-linux-kernel-mainline-unstable "7.3.1-$revision"
bash "$owner/packaging/native/copr-o82-hsic-unstable.sh" "$output" "$revision"
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
parent_effective_hash=7f1e3f7a5be62396b2b36534780aeb561dfbf7e0a10698677b860cbc91efbd38
# Check all actual Kconfig dependencies immediately after olddefconfig, before
# spending a complete build on a silently dropped legacy-table prerequisite.
for tree in "$profile" "$boot"; do
 install -Dm644 "$fragment" "$tree/configs/waydroid-network.config"
 install -Dm644 "$owner/tests/waydroid-network-built731.sh" "$tree/tests/waydroid-network-built731.sh"
 install -Dm644 "$owner/tests/waydroid-network-config731.sh" "$tree/tests/waydroid-network-config731.sh"
 install -Dm644 "$stage/before.config" "$tree/configs/waydroid-firewall-modular-reference.config"
 awk -v parent_hash="$parent_effective_hash" '
  {print}
  /^make -C "\$kernel" O="\$out" LOCALVERSION="\$localversion" olddefconfig$/ {
   checks++
   phase=(checks==1 ? "initial" : "final")
   print "bash \"$here/../../tests/waydroid-network-built731.sh\" \"$out\" \"$here/../../configs/waydroid-network.config\" config-only"
   print "bash \"$here/../../tests/waydroid-network-config731.sh\" \"$kernel\" \"$out\" \"$localversion\" \"$here/../../configs/waydroid-firewall-modular-reference.config\" \"$here/../../configs/waydroid-network.config\" "phase" "parent_hash
  }
  END {if(checks!=2)exit 1}
 ' "$tree/src/boot/build-payload.sh" > "$stage/build-payload.sh"
 cp "$stage/build-payload.sh" "$tree/src/boot/build-payload.sh"
 bash -n "$tree/src/boot/build-payload.sh"
done
for path in configs/waydroid-network.config configs/waydroid-firewall-modular-reference.config tests/waydroid-network-built731.sh tests/waydroid-network-config731.sh src/boot/build-payload.sh; do
 digest=$(sha256sum "$boot/$path"); digest=${digest%% *}
 jq --arg path "$path" --arg digest "$digest" \
  '.source_assets |= (map(select(.path!=$path)) + [{path:$path,sha256:$digest}])' \
  "$boot/lock.json" > "$stage/network-lock.json"
 cp "$stage/network-lock.json" "$boot/lock.json"
done
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
 waydroid_network_precompile_config_gate:true,
 waydroid_network_independent_effective_config_gate:true,
 waydroid_network_parent_factory:"copr-o82-hsic-unstable.sh",
 waydroid_network_parent_reference_producer:"34d29c4946fa62ef10fdb1424be304407aee5ed8",
 waydroid_network_parent_composition:"source-composition-before-waydroid-network.json",
 waydroid_network_kernel_driver_source_unchanged:true,
 waydroid_default_kernel_feature_level:1,physical_acceptance:false
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
awk -v parent_hash="$parent_effective_hash" '
 $0=="printf " "\047" parent_hash "  %{_uke_out}/.config\\n" "\047" " | sha256sum -c --strict" {
  print "printf " "\047" parent_hash "  %{_uke_out}/waydroid-config-reference/parent/.config\\n" "\047" " | sha256sum -c --strict"
  print "cmp %{_uke_out}/waydroid-config-reference/expected-final/.config %{_uke_out}/.config"
  parent_checks++; next
 }
 /^%package singleboot$/ || /^%package -n %\{name\}-singleboot$/ || /^%package -n senemos-uke-linux-kernel-mainline-unstable-singleboot$/ {
  print; print "Provides: uke-kernel-default(waydroid-netd) = 1"; profiles++; next
 }
 /^%check$/ {
  print
  print "bash native-profile/tests/native-firewall-builtins-contract.sh native-profile/tests/native-firewall-contract.sh native-profile/configs/waydroid-firewall-modular-reference.config"
  print "bash native-profile/tests/waydroid-network-built731.sh %{_uke_out} native-profile/configs/waydroid-network.config"; checks++; next
 }
 {print} END {if(checks!=1 || profiles!=1 || parent_checks!=1)exit 1}
' "$spec" > "$stage/kernel.spec"
cp "$stage/kernel.spec" "$spec"
printf 'Waydroid network input config: %s; producer: %s\n' "$config_hash" "$producer"

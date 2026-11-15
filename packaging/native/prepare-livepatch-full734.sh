#!/usr/bin/bash
# Add the same independently resolved capability to final and manager inputs,
# after all historical config and storage seed comparisons have completed.
set -Eeuo pipefail
[[ $# == 2 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1");out=$(realpath "$2");profile=$kernel/native-profile
work=$kernel/native-generated/livepatch-full734
[[ -f $kernel/native-generated/storage-config-full733/seed-complete && ! -e $work ]]
mkdir -p "$work/before" "$work/after"
configs=("$out/.config")
roles=(actual before-native native before-cdsp cdsp before-waydroid waydroid)
for role in "${roles[@]:1}";do configs+=("$kernel/native-generated/migration-manager-$role/.config");done
for index in "${!roles[@]}";do
 role=${roles[index]};config=${configs[index]}
 [[ -s $config && ! -L $config ]]
 cp "$config" "$work/before/$role.seed.config"
 make -s -C "$kernel" O="$(dirname "$config")" ARCH=arm64 LLVM=1 LLVM_IAS=1 olddefconfig
 cp "$config" "$work/before/$role.config"
 bash "$profile/src/livepatch/configure734.sh" "$kernel" "$config" "$profile"
 # Each input is independently resolved by the actual target compiler. The
 # two-setting inverse is checked again after Kconfig, rejecting hidden deltas.
 make -s -C "$kernel" O="$(dirname "$config")" ARCH=arm64 LLVM=1 LLVM_IAS=1 olddefconfig
 bash "$profile/tests/kernel-hardening-config-contract.sh" "$config"
 sed -e 's/^CONFIG_LIVEPATCH=y$/# CONFIG_LIVEPATCH is not set/' \
  -e 's|^CONFIG_SYSTEM_TRUSTED_KEYS="native-profile/src/livepatch/uke-livepatch-20261115.pem"$|CONFIG_SYSTEM_TRUSTED_KEYS=""|' \
  "$config" > "$work/after/$role.inverse.config"
 # Effective options, rather than Kconfig comment/order-only formatting.
 for phase in before after;do
  input=$work/before/$role.config
  [[ $phase != after ]] || input=$work/after/$role.inverse.config
  awk '/^CONFIG_[A-Z0-9_]+=/ || /^# CONFIG_[A-Z0-9_]+ is not set$/' "$input" | LC_ALL=C sort > "$work/$role.$phase.effective"
 done
 cmp "$work/$role.before.effective" "$work/$role.after.effective"
done
for prefix in before- '';do
 bash "$profile/tests/nfc-cohort-config731.sh" \
  "$kernel/native-generated/migration-manager-${prefix}native/.config" \
  "$kernel/native-generated/migration-manager-${prefix}waydroid/.config"
done
for role in native cdsp waydroid;do
 bash "$profile/tests/kernel-manager-config-contract.sh" \
  "$kernel/native-generated/migration-manager-before-$role/.config" \
  "$kernel/native-generated/migration-manager-$role/.config" "$profile/configs/kernel-manager/resources.config"
done
(cd "$work/before";sha256sum *.config) > "$work/before.sha256"
touch "$work/seed-complete"
printf 'Livepatch full seed: seven independent effective two-setting inverses; historical configs and all manager/NFC comparisons retained.\n'

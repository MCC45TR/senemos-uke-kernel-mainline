#!/usr/bin/bash
# Source assembly only. Preserve the original physical-root guard and recipe.
set -Eeuo pipefail
[[ $# == 2 ]]
boot=$(realpath "$1");builder=$(realpath "$2")
[[ -f $boot/lock.json && -f $builder/src/image/early-super-policy.sh &&
   ! -e $boot/packaging/uke-super-initrd && ! -L $boot/packaging/uke-super-initrd ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
recipe=$boot/src/boot/make-initramfs-base.sh
printf '%s  %s\n' 707e2ab5b306bc48532fde1bfdbd8ec80c4ee00bc9612599d30c25ead87f664c "$recipe" | sha256sum -c --strict --quiet -
cp "$recipe" "$work/original.sh"
awk '
 {print}
 $0=="cp -a /usr/lib/dracut/. \"$work/dracut/\""{
  print "# UKE_SUPER_EARLY734_BEGIN"
  print "cp -a \"$here/../../packaging/uke-super-initrd/modules.d/.\" \"$work/dracut/modules.d/\""
  print "# UKE_SUPER_EARLY734_END";n++
 }END{if(n!=1)exit 1}
' "$recipe" | sed 's/--add uke-abl --kernel-cmdline/--add "uke-abl uke-super-tools uke-super-boot" --kernel-cmdline/' > "$work/new.sh"
awk '/^# UKE_SUPER_EARLY734_BEGIN$/{skip=1;next}/^# UKE_SUPER_EARLY734_END$/{skip=0;next}!skip{print}' "$work/new.sh" |
 sed 's/--add "uke-abl uke-super-tools uke-super-boot" --kernel-cmdline/--add uke-abl --kernel-cmdline/' | cmp - "$recipe"
modules=$boot/packaging/uke-super-initrd/modules.d
mkdir -p "$modules/95uke-super-tools" "$modules/96uke-super-boot"
for script in fastboot-singleboot-layout inspect-fastboot-super plan-super-provision provision-fastboot-super map-fastboot-rescue select-uke-super;do
 install -m755 "$builder/src/image/$script.sh" "$modules/95uke-super-tools/"
done
install -m755 "$builder/src/image/dracut/95uke-super-tools/module-setup.sh" "$modules/95uke-super-tools/"
for script in early-super-policy prepare-early-super guard-early-rescue;do
 install -m755 "$builder/src/image/$script.sh" "$modules/96uke-super-boot/"
done
install -m755 "$builder/src/image/dracut/96uke-super-boot/module-setup.sh" "$modules/96uke-super-boot/"
install -m644 "$builder/src/image/dracut/96uke-super-boot/uke-super-prepare.service" "$modules/96uke-super-boot/"
install -m644 "$builder/LICENSE" "$boot/packaging/uke-super-initrd/LICENSE"
install -m644 "$work/new.sh" "$recipe"
bash -n "$recipe"
hash=$(sha256sum "$recipe" | cut -d' ' -f1)
(cd "$boot";find packaging/uke-super-initrd -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum) > "$work/new-assets.sha256"
jq -Rn '[inputs|capture("^(?<sha256>[a-f0-9]{64})  (?<path>[A-Za-z0-9_./-]+)$") | {path,sha256}]' < "$work/new-assets.sha256" > "$work/new-assets.json"
jq --arg hash "$hash" --slurpfile additions "$work/new-assets.json" '
 .source_assets |= map(if .path=="src/boot/make-initramfs-base.sh" then .sha256=$hash else . end) |
 .source_assets += $additions[0] |
 .super_early_profile={seed_contract_bytes:4294967296,normal_guard_preserved:true,explicit_optin_required:true,
   readonly_rescue:true,swap_activation:false,protected_boot_policy_replaced:false,physical_acceptance:false}
' "$boot/lock.json" > "$work/lock.json"
mv "$work/lock.json" "$boot/lock.json"
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
echo 'Early-super modules assembled with complete original make-initramfs inverse; physical-root guard bytes unchanged.'

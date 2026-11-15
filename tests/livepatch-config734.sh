#!/usr/bin/bash
# Metadata/security checks only; no compiler, module load or target access.
set -Eeuo pipefail
[[ $# == 2 ]]
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
scripts_config=$(realpath "$1"); baseline=$(realpath "$2")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir -p "$work/kernel/scripts" "$work/kernel/native-profile/src/livepatch" "$work/kernel/native-profile/manifests"
profile=$work/kernel/native-profile
cp "$scripts_config" "$work/kernel/scripts/config"
cp "$owner/src/livepatch/uke-livepatch-20261115.pem" "$profile/src/livepatch/"
cp "$owner/manifests/livepatch734-20261115.json" "$profile/manifests/"
cp "$baseline" "$work/valid.config"
bash "$owner/src/livepatch/configure734.sh" "$work/kernel" "$work/valid.config" "$profile"
bash "$owner/tests/kernel-hardening-config-contract.sh" "$work/valid.config"
refuse() {
 if "$@" > "$work/refused.log" 2>&1; then
  printf 'Livepatch protection refusal failed\n' >&2; exit 1
 fi
}
for flag in MODULE_SIG_FORCE SECURITY_SELINUX LOCK_DOWN_KERNEL_FORCE_INTEGRITY LIVEPATCH; do
 sed "s/^CONFIG_${flag}=y$/# CONFIG_${flag} is not set/" "$work/valid.config" > "$work/invalid.config"
 refuse bash "$owner/tests/kernel-hardening-config-contract.sh" "$work/invalid.config"
done
sed 's|native-profile/src/livepatch/uke-livepatch-20261115.pem|unreviewed.pem|' "$work/valid.config" > "$work/invalid.config"
refuse bash "$owner/tests/kernel-hardening-config-contract.sh" "$work/invalid.config"
printf '\n' >> "$profile/src/livepatch/uke-livepatch-20261115.pem"
cp "$baseline" "$work/invalid.config"
refuse bash "$owner/src/livepatch/configure734.sh" "$work/kernel" "$work/invalid.config" "$profile"
cmp "$baseline" "$work/invalid.config"
printf 'Livepatch two-setting inverse and exact-certificate/signature/SELinux/lockdown/disabled-livepatch refusal controls passed; no compile or module load.\n'

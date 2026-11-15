#!/usr/bin/env bash
# Check the resolved release configuration, not only the input fragment.
set -Eeuo pipefail
config=${1:?Pass the resolved kernel configuration}
for symbol in MODULE_SIG MODULE_SIG_FORCE MODULE_SIG_ALL MODULE_SIG_SHA256 \
    MODULE_SIG_KEY_TYPE_RSA SYSTEM_TRUSTED_KEYRING SECURITY_DMESG_RESTRICT \
    SECURITY_LOCKDOWN_LSM SECURITY_LOCKDOWN_LSM_EARLY LOCK_DOWN_KERNEL_FORCE_INTEGRITY \
    SECURITY_YAMA SECURITY_SELINUX FORTIFY_SOURCE HARDENED_USERCOPY \
    RANDOMIZE_BASE STACKPROTECTOR_STRONG STRICT_KERNEL_RWX STRICT_MODULE_RWX; do
    grep -Fxq "CONFIG_${symbol}=y" "$config" || {
        printf 'Required release protection missing: %s\n' "$symbol" >&2; exit 1;
    }
done
grep -Fxq 'CONFIG_MODULE_SIG_KEY="certs/signing_key.pem"' "$config"
if grep -Fxq 'CONFIG_SYSTEM_TRUSTED_KEYS="native-profile/src/livepatch/uke-livepatch-20261115.pem"' "$config"; then
    root=$(cd -- "$(dirname -- "$0")/.." && pwd)
    contract=$root/manifests/livepatch734-20261115.json
    cert=$root/src/livepatch/uke-livepatch-20261115.pem
    grep -Fxq 'CONFIG_LIVEPATCH=y' "$config"
    for symbol in DYNAMIC_FTRACE_WITH_ARGS KALLSYMS_ALL HAVE_LIVEPATCH HAVE_RELIABLE_STACKTRACE; do
        grep -Fxq "CONFIG_${symbol}=y" "$config"
    done
    printf '%s  %s\n' "$(jq -er .certificate_pem_sha256 "$contract")" "$cert" | sha256sum -c --strict --quiet -
    [[ $(openssl x509 -in "$cert" -outform DER | sha256sum | cut -d' ' -f1) == $(jq -er .certificate_der_sha256 "$contract") ]]
    ! grep -Eq 'BEGIN .*PRIVATE KEY' "$cert"
else
    grep -Fxq 'CONFIG_SYSTEM_TRUSTED_KEYS=""' "$config"
fi
lsm=$(sed -n 's/^CONFIG_LSM="\([^"]*\)"$/\1/p' "$config")
for name in lockdown yama selinux; do
    case ,$lsm, in *,"$name",*) ;; *) printf 'Required LSM missing: %s\n' "$name" >&2; exit 1;; esac
done
echo 'Resolved kernel release protections passed'

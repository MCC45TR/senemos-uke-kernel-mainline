#!/usr/bin/bash
# Apply only the explicitly requested livepatch configuration to a final build.
set -Eeuo pipefail
[[ $# == 3 ]]
kernel=$(realpath "$1"); config=$(realpath "$2"); profile=$(realpath "$3")
[[ $profile == "$kernel/native-profile" && -f $config && ! -L $config ]]
contract=$profile/manifests/livepatch734-20261115.json
cert=$profile/src/livepatch/uke-livepatch-20261115.pem
[[ $(jq -er .kernel_trusted_keys_path "$contract") == native-profile/src/livepatch/uke-livepatch-20261115.pem ]]
printf '%s  %s\n' "$(jq -er .certificate_pem_sha256 "$contract")" "$cert" | sha256sum -c --strict --quiet -
[[ $(openssl x509 -in "$cert" -outform DER | sha256sum | cut -d' ' -f1) == $(jq -er .certificate_der_sha256 "$contract") ]]
! grep -Eq 'BEGIN .*PRIVATE KEY' "$cert"
grep -Fxq '# CONFIG_LIVEPATCH is not set' "$config"
grep -Fxq 'CONFIG_SYSTEM_TRUSTED_KEYS=""' "$config"
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cp "$config" "$work/before.config"
bash "$kernel/scripts/config" --file "$config" --enable LIVEPATCH \
 --set-str SYSTEM_TRUSTED_KEYS native-profile/src/livepatch/uke-livepatch-20261115.pem
sed -e 's/^CONFIG_LIVEPATCH=y$/# CONFIG_LIVEPATCH is not set/' \
 -e 's|^CONFIG_SYSTEM_TRUSTED_KEYS="native-profile/src/livepatch/uke-livepatch-20261115.pem"$|CONFIG_SYSTEM_TRUSTED_KEYS=""|' \
 "$config" | cmp - "$work/before.config"
printf 'Final-build livepatch requested; only LIVEPATCH and the pinned public module certificate changed. Module signature enforcement remains required.\n'

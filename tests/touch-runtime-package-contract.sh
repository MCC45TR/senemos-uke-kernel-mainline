#!/usr/bin/env bash
# Exercise the production module/client pairing without building or booting Linux.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
sed -n '/^\[\[ -s \$source_modules\/kernel\/drivers\/media\/spi\/nt36532-uke\/nt36532-uke-thp.ko.zst/,+2p' \
    "$root/src/boot/build-payload.sh" > "$stage/production.sh"
[[ $(wc -l < "$stage/production.sh") == 3 ]]
export kernel=$stage/kernel out=$stage/out source_modules=$stage/modules
mkdir -p "$kernel/native-generated" "$out" "$source_modules/kernel/drivers/media/spi/nt36532-uke"
printf 'source-client\n' > "$kernel/native-generated/uke-touch-capture"
printf 'module-fixture\n' > "$source_modules/kernel/drivers/media/spi/nt36532-uke/nt36532-uke-thp.ko.zst"
bash -Eeuo pipefail "$stage/production.sh"
[[ -x $source_modules/uke/uke-touch-capture ]]
cmp "$kernel/native-generated/uke-touch-capture" "$source_modules/uke/uke-touch-capture"
[[ $(cat "$out/boot-manifest") == "touch_client_sha256=$(sha256sum "$source_modules/uke/uke-touch-capture" | cut -d ' ' -f1)" ]]
rm "$source_modules/kernel/drivers/media/spi/nt36532-uke/nt36532-uke-thp.ko.zst"
if bash -Eeuo pipefail "$stage/production.sh"; then
    echo 'Missing touch module admitted' >&2; exit 1
fi
printf 'module-fixture\n' > "$source_modules/kernel/drivers/media/spi/nt36532-uke/nt36532-uke-thp.ko.zst"
rm "$kernel/native-generated/uke-touch-capture"
if bash -Eeuo pipefail "$stage/production.sh"; then
    echo 'Missing touch client admitted' >&2; exit 1
fi
printf 'Production client copy/digest and missing module/client refusals: PASS\n'

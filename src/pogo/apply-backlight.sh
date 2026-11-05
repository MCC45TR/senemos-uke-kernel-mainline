#!/usr/bin/env bash
# COPR cumulative-profile integration; do not append Kconfig a second time.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
profile=$(realpath -- "${1:?Extracted cumulative native profile}")
before=40e216986ac9b47f495ba756e25a8f487b92faae04f71b7459b935b55e38e392
actual=$(sha256sum "$profile/src/pogo/hid-nanosic-uke.c");actual=${actual%% *}
after=$(sha256sum "$owner/src/pogo/hid-nanosic-uke.c");after=${after%% *}
[[ $actual == "$before" || $actual == "$after" ]] || { printf 'Unexpected pogo source; reconcile contributions before integration\n' >&2; exit 1; }
for path in src/pogo/hid-nanosic-uke.c src/pogo/nanosic-uke-hid.h src/pogo/README.md \
 tests/nanosic-lifecycle-contract.sh tests/nanosic-backlight-contract.sh tests/nanosic-power-contract.sh; do
 install -Dm644 "$owner/$path" "$profile/$path"
done
stage=$(mktemp)
trap 'test ! -e "$stage" || unlink "$stage"' EXIT
jq --arg source "$(git -C "$owner" rev-parse HEAD)" '. + {
 pogo_backlight_source:$source,pogo_backlight_conditional_led:true,
 pogo_outputs_require_host_token_delivery:true,pogo_power_order:"Uke-vdd3.3V-then-dvdd1.8V",
 pogo_backlight_physical_acceptance:false}' "$profile/source-composition.json" > "$stage"
install -m644 "$stage" "$profile/source-composition.json"
printf 'Pogo source layer applied; coordinator must refresh profile locks and require new native fixtures\n'

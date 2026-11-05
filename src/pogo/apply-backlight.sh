#!/usr/bin/env bash
# COPR cumulative-profile integration; do not append Kconfig a second time.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
profile=$(realpath -- "${1:?Extracted cumulative native profile}")
before=40e216986ac9b47f495ba756e25a8f487b92faae04f71b7459b935b55e38e392
first=97107ef558ed2d9855f7c174c749e6efd634d5c6c6536cad3135fda9b5eb3f7c
actual=$(sha256sum "$profile/src/pogo/hid-nanosic-uke.c");actual=${actual%% *}
after=$(sha256sum "$owner/src/pogo/hid-nanosic-uke.c");after=${after%% *}
[[ $actual == "$before" || $actual == "$first" || $actual == "$after" ]] || { printf 'Unexpected pogo source; reconcile contributions before integration\n' >&2; exit 1; }
admit_header() {
 local path=$1 old=$2 prior=$3 actual current
 actual=$(sha256sum "$profile/$path");actual=${actual%% *}
 current=$(sha256sum "$owner/$path");current=${current%% *}
 [[ $actual == "$old" || $actual == "$prior" || $actual == "$current" ]] || {
  printf 'Unexpected pogo header: %s; reconcile contributions before integration\n' "$path" >&2;exit 1;
 }
}
admit_header src/pogo/nanosic-uke-protocol.h c65662bdaf94555b02e264375750e42768819fa96d5c89f7aceb6f730c6927be c65662bdaf94555b02e264375750e42768819fa96d5c89f7aceb6f730c6927be
admit_header src/pogo/nanosic-uke-hid.h 3bbf87738232368c9e62844128bd59d1c263fd466fde721d914a9e803babfc1a 46e68cf8983b8ef3eebe36749c80d64a1a4008c0dec106ddb875c0b647fab1c4
for path in src/pogo/hid-nanosic-uke.c src/pogo/nanosic-uke-hid.h src/pogo/nanosic-uke-protocol.h src/pogo/README.md \
 tests/nanosic-protocol-contract.sh tests/nanosic-lifecycle-contract.sh tests/nanosic-backlight-contract.sh \
 tests/nanosic-power-contract.sh tests/nanosic-hid-contract.sh; do
 install -Dm644 "$owner/$path" "$profile/$path"
done
stage=$(mktemp)
trap 'test ! -e "$stage" || unlink "$stage"' EXIT
jq --arg source "$(git -C "$owner" rev-parse HEAD)" '. + {
 pogo_backlight_source:$source,pogo_backlight_conditional_led:true,
 pogo_outputs_require_host_token_delivery:true,pogo_power_order:"Uke-vdd3.3V-then-dvdd1.8V",
 pogo_touchpad_descriptor:"Uke-3199x2135-94x42mm-3-entries-8-frame-contacts",
 pogo_backlight_physical_acceptance:false}' "$profile/source-composition.json" > "$stage"
install -m644 "$stage" "$profile/source-composition.json"
printf 'Pogo source layer applied; coordinator must refresh profile locks and require new native fixtures\n'

#!/usr/bin/bash
# Source-worker overlay only. All LED execution and compilation stay in COPR.
set -Eeuo pipefail
[[ $# == 2 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
for tree in "$1" "$2"; do
 [[ -d $tree && ! -L $tree ]]
 while read -r expected path; do
  printf '%s  %s\n' "$expected" "$tree/$path" | sha256sum -c --strict --quiet -
  install -m644 "$owner/$path" "$tree/$path"
 done <<'ASSETS'
a8eaa89fe1cd0ba55555276befbb1b554b82624d44ca2a578afc7a9c3e380c85 src/leds/leds-uke-rgb.c
38378c23efb7a882f5b64431beda9988061e33ea25938fcbcd5caf342101fe57 src/leds/uke-rgb-policy.h
8d1b9c749eab51f340e3f8b3a634e64fa6c95933a44d370ba80a9e8829886cc2 src/leds/uke-rgb-uapi.h
bea2e5f76c0fa56df6bc03e1fe8d6854b83e76a7190df76e768d6b90b786c2b9 tests/rgb-policy.sh
ASSETS
 # The working full28 preparation already owns RGB and has no standalone
 # torch overlay. Preserve it byte-for-byte except the new battery fixture;
 # the generic checkout's older torch preparation is not this recipe's owner.
 prepare=$tree/src/leds/prepare-source.sh
 printf '%s  %s\n' 0206fd69cf4fe4749fe75cddecdc7ed20937246e78ce2235f200ef8e813079b9 "$prepare" | sha256sum -c --strict --quiet -
 awk '{print} $0=="bash \"$here/../../tests/rgb-policy.sh\"" {print "bash \"$here/../../tests/rgb-charge-events.sh\"";n++} END{if(n!=1)exit 1}' \
  "$prepare" > "$prepare.next"
 sed '\|^bash "$here/../../tests/rgb-charge-events.sh"$|d' "$prepare.next" | cmp - "$prepare"
 bash -n "$prepare.next"
 mv "$prepare.next" "$prepare"
 [[ ! -e $tree/tests/rgb-charge-events.sh ]]
 install -m644 "$owner/tests/rgb-charge-events.sh" "$tree/tests/rgb-charge-events.sh"
done
printf 'Existing native RGB owner retained; inclusive battery fades and finite charge notification sources staged, without a runtime bridge package.\n'

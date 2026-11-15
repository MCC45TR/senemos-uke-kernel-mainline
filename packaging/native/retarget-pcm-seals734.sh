#!/usr/bin/bash
# Keep the signed stable ring-pointer fix and every PCM worker assertion.
set -Eeuo pipefail
[[ $# == 2 && ! -e /etc/senemos/kernel-update.conf ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
for tree in "$1" "$2"; do
 while read -r hash path; do
  printf '%s  %s\n' "$hash" "$tree/$path" | sha256sum -c --strict --quiet -
  sed -e 's/acb1773a93e99881ff51bcc78c26e8d48b6e8c59cb396755d47100dd91a6797b/d3c99fd9322c42eab0304f9af698ea8da8f63ef7b8b43475f46c40ae37da4d25/g' \
   -e 's/f14978b215fe56b1e5505ca9f36da9633c5631fd7b1be40ae85896aea86d7e65/54c1b3fce6eeb3b85650762b23d724d090e2bd923a13c99a3e4021ad6ce6813b/g' \
   "$tree/$path" > "$work/next"
  sed -e 's/d3c99fd9322c42eab0304f9af698ea8da8f63ef7b8b43475f46c40ae37da4d25/acb1773a93e99881ff51bcc78c26e8d48b6e8c59cb396755d47100dd91a6797b/g' \
   -e 's/54c1b3fce6eeb3b85650762b23d724d090e2bd923a13c99a3e4021ad6ce6813b/f14978b215fe56b1e5505ca9f36da9633c5631fd7b1be40ae85896aea86d7e65/g' \
   "$work/next" | cmp - "$tree/$path"
  install -m644 "$work/next" "$tree/$path"
 done <<'ASSETS'
c0d3522aa56737196fa97f001795680344904546a5cccd7f5023dad7937fab47 src/audio/apply-pcm-period733.sh
54ea2725cfd61f29c7788d686ce085c5fb1ec6ae7326262ef280a0f495e8b16b packaging/native/check-pcm-period733.sh
79f6d89b065b2a18df07ade3a831229259e9650a10de7619c6b7a110d6488f76 manifests/pcm-period-cumulative-20261107.json
ASSETS
done
printf 'Stable PCM ring-pointer fix retained; whole-file worker pre/post seals and all behavior assertions preserved.\n'

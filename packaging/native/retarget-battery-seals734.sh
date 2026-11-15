#!/usr/bin/bash
# Preserve stable charger-online notifications through every retained Uke layer.
set -Eeuo pipefail
[[ $# == 2 && ! -e /etc/senemos/kernel-update.conf ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/map" <<'MAP'
0d04e4ea8baad97a1c590cc4c753eb56efbbb8759851e3848c88ae4ba0e8708e 62f1be87d90cae67d8ce385348a5ef56786951b74f79b65b2f8a8758338099ab
d9d2c5165342870fffddd2a2aa5edfa4cf4886bad158760b5eb1fb5a5e4802c2 f9c0f5f235dead6faa799b97576bbc672ae88ae27746f141ad4e4c1b3609a464
cac2ca201e5f2f33bf5474a3cd83130c3fca2fcb5af510c8259f2e823e697c7e 10ef5c8e58bff9532efc82bc8ff4931c67379a990506f910d6baae714dbb55c0
57d7ed9d043694afcd4d3c09cf7c2edd031ac1b4924f5b332c5fd67bced90905 63b0832264ac851cd7eff35f9c0f36ddb45fa36d24562375cb0684c640c0420c
MAP
awk '{print "s/"$1"/"$2"/g"}' "$work/map" > "$work/forward.sed"
awk '{print "s/"$2"/"$1"/g"}' "$work/map" > "$work/inverse.sed"
for tree in "$1" "$2"; do
 while read -r hash name; do
  file=$tree/manifests/$name
  printf '%s  %s\n' "$hash" "$file" | sha256sum -c --strict --quiet -
  sed -f "$work/forward.sed" "$file" > "$work/next"
  sed -f "$work/inverse.sed" "$work/next" | cmp - "$file"
  jq -e . "$work/next" >/dev/null
  install -m644 "$work/next" "$file"
 done <<'ASSETS'
4e225c331ebc5f35b0281598b42f77fa32ec7d21a610ad98c755c6d6cec5e9e0 charge-online-cap-20261111.json
27b6f4f7e3a42554f5a5b38d5cab99d690db06b8c94e3e186cb1bc6d151bce36 battery-event-health-20261111.json
8bfdb7e83374a455f61edc5a84b09b557f302cda31423ff60b97e843a65d2599 charge-standard-storage-20261111.json
651d0534aa73a4d45c2ffab90f2c3f3326b31c74f2fb3f824680e00312c6d1f9 charge-demand-20261111.json
e373db079d64c38e25f74a0782cce68112e6daf79343d5b9d4e9d2adc8935d02 charge-observe-v2-20261111.json
ASSETS
done
printf 'Stable online-notification source retained across all four sealed battery stages; five contracts changed only by admitted SHA256 replacements.\n'

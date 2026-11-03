#!/usr/bin/env bash
# Explicit one-time acquisition of generic OEM data; never reads persist.
set -Eeuo pipefail
[[ $(id -u) == 0 ]] || { echo 'Root is required to prepare the generic speaker data cache' >&2; exit 1; }
cache=/var/cache/uke-speaker-runtime
if [[ -e $cache || -L $cache ]]; then
 [[ -d $cache && ! -L $cache && $(stat -c %u "$cache") == 0 ]]
 [[ $((8#$(stat -c %a "$cache") & 8#022)) == 0 ]]
else
 install -d -o root -g root -m755 "$cache"
fi
file=$cache/Forte_acdb_cal.acdb
expected=bd3f9b8834b80c23f86241756e263e36ddf92b2b8993ed83ff71c310af952f3e
if [[ -e $file || -L $file ]]; then
 [[ -f $file && ! -L $file && $(stat -c %u "$file") == 0 ]]
 [[ $((8#$(stat -c %a "$file") & 8#022)) == 0 ]]
 printf '%s  %s\n' "$expected" "$file" | sha256sum -c --status
 printf '%s\n' 'The verified generic speaker DSP data is already present.'
 exit 0
fi
temporary=$(mktemp "$cache/.generic.XXXXXXXX")
trap 'rm -f -- "$temporary"' EXIT
curl -fLsS --proto '=https' --proto-redir '=https' --connect-timeout 15 --max-time 90 \
 --max-filesize 2838166 \
 https://raw.githubusercontent.com/delano-git/android_vendor_xiaomi_uke/87f59fc5c2ef1ee04e494e5258853d36a3346059/proprietary/odm/etc/acdbdata/Forte/Forte_acdb_cal.acdb \
 -o "$temporary"
[[ $(stat -c %s "$temporary") == 2838166 ]]
printf '%s  %s\n' "$expected" "$temporary" | sha256sum -c --status
chmod 444 "$temporary"
mv -T -- "$temporary" "$file"
printf '%s\n' 'Verified generic speaker DSP data prepared. No unit calibration was copied.'

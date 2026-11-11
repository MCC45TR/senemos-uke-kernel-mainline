#!/usr/bin/bash
# Exercise only archive text/identity; no compiler, kernel or audio device access.
set -Eeuo pipefail
owner=$(realpath "${1:?Source}")
input=$(realpath "${2:?Immutable57 native card source}")
plan=$owner/manifests/cumulative-release.json
helper=$owner/packaging/native/retarget-audio-tuple733.sh
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
for release in 11 12;do
 mkdir -p "$work/$release/profile/src/audio" "$work/$release/boot/src/audio"
 for tree in profile boot;do cp "$input" "$work/$release/$tree/src/audio/uke-audio-card.c";done
 jq --argjson release "$release" '.full_release=$release' "$plan" > "$work/$release/plan.json"
 bash "$helper" "$work/$release/profile" "$work/$release/boot" "$work/$release/plan.json"
 grep -F "card->driver_name = \"uke7.3.3-${release}u\";" "$work/$release/profile/src/audio/uke-audio-card.c"
 cmp "$work/$release/profile/src/audio/uke-audio-card.c" "$work/$release/boot/src/audio/uke-audio-card.c"
done
# The next candidate starts from the admitted11 archive, not the older10 card.
before11=$(sha256sum "$work/11/profile/src/audio/uke-audio-card.c" | cut -d' ' -f1)
bash "$helper" "$work/11/profile" "$work/11/boot" "$work/12/plan.json" "$before11"
cmp "$work/11/profile/src/audio/uke-audio-card.c" "$work/12/profile/src/audio/uke-audio-card.c"
before12=$(sha256sum "$work/11/profile/src/audio/uke-audio-card.c" | cut -d' ' -f1)
if bash "$helper" "$work/11/profile" "$work/11/boot" "$work/12/plan.json" "$before12" > "$work/replay.log" 2>&1;then exit 1;fi
if bash "$helper" "$work/11/profile" "$work/11/boot" "$work/12/plan.json" "$before11" > "$work/stale.log" 2>&1;then exit 1;fi
[[ $(sha256sum "$work/11/profile/src/audio/uke-audio-card.c" | cut -d' ' -f1) == "$before12" ]]
# A stale/mixed supplier copy must refuse before changing the other archive.
for tree in profile boot;do cp "$input" "$work/11/$tree/src/audio/uke-audio-card.c";done
printf '\n/* unreviewed */\n' >> "$work/11/boot/src/audio/uke-audio-card.c"
if bash "$helper" "$work/11/profile" "$work/11/boot" "$plan" > "$work/mixed.log" 2>&1;then exit 1;fi
cmp "$input" "$work/11/profile/src/audio/uke-audio-card.c"
printf 'Actual audio tuple text transform:10-to11/12 and11-to12, both archives, whole-card inverse, replay/stale/mixed pre-mutation refusal passed.\n'

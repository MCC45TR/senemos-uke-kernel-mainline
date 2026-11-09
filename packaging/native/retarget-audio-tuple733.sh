#!/usr/bin/bash
# Data-only archive transformation; compact ALSA identity follows the same tuple.
set -Eeuo pipefail
[[ $# == 3 ]]
profile=$(realpath "${1:?Native profile}")
boot=$(realpath "${2:?Boot recipe}")
tuple=$(bash "$(dirname -- "$0")/../../scripts/kernel-release.sh" json "${3:?Cumulative release plan}")
name=uke$(jq -er .version <<< "$tuple")-$(jq -er .release <<< "$tuple")u
[[ ${#name} -lt 16 && $name != uke7.3.3-10u ]]
[[ ${name//./_} == "$(jq -er .audio_driver <<< "$tuple")" ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
path=src/audio/uke-audio-card.c
for tree in "$profile" "$boot";do
 printf '%s  %s\n' 8d29e1ca21c8580c4090eddc88e2a706933116c628e1ac0827c34ecbc4cb4878 "$tree/$path" | sha256sum -c --strict --quiet -
done
cmp "$profile/$path" "$boot/$path"
awk -v name="$name" '
 {n+=gsub(/"uke7[.]3[.]3-10u"/,"\"" name "\"");print}
 END{if(n!=2)exit 1}
' "$profile/$path" > "$work/card.c"
awk -v name="$name" '
 {needle="\"" name "\"";pos=index($0,needle);if(pos){$0=substr($0,1,pos-1) "\"uke7.3.3-10u\"" substr($0,pos+length(needle));n++}print}
 END{if(n!=2)exit 1}
' "$work/card.c" | cmp - "$profile/$path"
for tree in "$profile" "$boot";do install -m644 "$work/card.c" "$tree/$path";done
printf 'Compact ALSA tuple retargeted:%s; both archives match and whole-card inverse passed.\n' "$name"

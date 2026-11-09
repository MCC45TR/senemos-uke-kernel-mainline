#!/usr/bin/bash
# COPR only: compile staged topology and parse UCM with original ALSA libraries.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
profile=$kernel/native-profile
bash "$profile/src/audio/prepare-surround-profiles733.sh" "$kernel"
work=$kernel/native-generated/surround-profiles733
alsatplg -c "$work/topology-before.conf" -o "$work/before.bin"
cmp "$kernel/native-generated/POCO-Pad-X1-tplg.bin" "$work/before.bin"
alsatplg -c "$work/topology.conf" -o "$work/surround.bin"
alsatplg -d "$work/surround.bin" -o "$work/decoded.conf"
for name in spk.fs.rx spk.fs.tx spk.vi.source 'MultiMedia3 Capture' S24_LE S32_LE;do
 grep -F "$name" "$work/decoded.conf"
done
node - "$work/before.bin" "$work/surround.bin" <<'NODE'
const fs=require('fs'),[a,b]=process.argv.slice(2),before=fs.readFileSync(a),after=fs.readFileSync(b);
if(before.length!==after.length)throw Error('Topology length changed');
const changed=[];for(let i=0;i<before.length;i++)if(before[i]!==after[i]){if(before[i]!==4||after[i]!==8)throw Error('Unexpected topology byte delta');changed.push(i);}
if(!changed.length||changed.length>2)throw Error('Unexpected FE capability copy count');
console.log('Compiled protected topology: only '+changed.length+' frontend max-channel capability byte(s) change4-to8; all graph bytes retained.');
NODE
for cc in g++ clang++;do
 "$cc" -std=c++17 -O2 -UNDEBUG -Wall -Wextra -Werror "$profile/tests/speaker-surround-ucm.cpp" \
  $(pkg-config --cflags --libs alsa) -o "$work/ucm-check"
 "$work/ucm-check" "$profile/src/audio/desktop/array-ucm2/Speaker-HiFi.conf" \
  "$work/ucm/Speaker-Surround51.conf" "$work/ucm/Speaker-Surround71.conf" "$work/ucm/POCO-Pad-X1.conf"
done
jq '."monitor.alsa.rules"[].matches[] |= if ."node.name"=="~alsa_input[.]platform-sound-uke[.].*__Mic__source" then
 ."node.name"="alsa_input.platform-sound-uke.HiFi__Mic__source" else . end' "$work/microphone-rules.conf" | jq -S . > "$work/wp-inverse.json"
jq -S . "$profile/src/audio/desktop/wireplumber/80-uke-microphone-array.conf" > "$work/wp-before.json"
cmp "$work/wp-before.json" "$work/wp-inverse.json"
printf 'Staged5.1/7.1 original ALSA/UCM profiles and scoped capture rules pass; no installed profile, firmware or physical acceptance.\n'

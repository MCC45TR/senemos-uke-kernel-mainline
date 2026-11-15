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
printf '%s  %s\n' e6fb9df54268e43d83ae8a2ac679c44330f370e932d43dfd69504910c3e15a40 "$profile/referances/alsa-ucm-parser.c" | sha256sum -c --strict --quiet -
awk '/^static int parse_is_name_safe\(/ {copy=1} copy{print} copy&&/^}/{n++;exit} END{if(n!=1)exit 1}' "$profile/referances/alsa-ucm-parser.c" > "$work/actual-alsa-ucm-name.inc"
sed 's/HiFiSurround51/HiFi Surround 5.1/;s/HiFiSurround71/HiFi Surround 7.1/' "$work/ucm/POCO-Pad-X1.conf" > "$work/historical-unsafe-ucm.conf"
ulimit -c 0
for cc in g++ clang++;do
 "$cc" -std=c++17 -O2 -UNDEBUG -Wall -Wextra -Werror "$profile/tests/speaker-surround-ucm.cpp" \
  -I"$work" $(pkg-config --cflags --libs alsa) -o "$work/ucm-check"
 "$work/ucm-check" "$profile/src/audio/desktop/array-ucm2/Speaker-HiFi.conf" \
  "$work/ucm/Speaker-Surround51.conf" "$work/ucm/Speaker-Surround71.conf" "$work/ucm/POCO-Pad-X1.conf"
 status=0
 "$work/ucm-check" "$profile/src/audio/desktop/array-ucm2/Speaker-HiFi.conf" "$work/ucm/Speaker-Surround51.conf" "$work/ucm/Speaker-Surround71.conf" "$work/historical-unsafe-ucm.conf" > "$work/$cc-semantic-refusal.log" 2>&1 || status=$?
 [[ $status == 134 ]]
 grep -F 'parse_is_name_safe(id)' "$work/$cc-semantic-refusal.log"
 printf 'Original ALSA semantic UCM names pass and historical dotted IDs refuse:%s.\n' "$cc"
done
jq '."monitor.alsa.rules"[].matches[] |= if ."node.name"=="~alsa_input[.]platform-sound-uke[.].*__Mic__source" then
 ."node.name"="alsa_input.platform-sound-uke.HiFi__Mic__source" else . end' "$work/microphone-rules.conf" | jq -S . > "$work/wp-inverse.json"
jq -S . "$profile/src/audio/desktop/wireplumber/80-uke-microphone-array.conf" > "$work/wp-before.json"
cmp "$work/wp-before.json" "$work/wp-inverse.json"
printf 'Staged5.1/7.1 original ALSA/UCM profiles and scoped capture rules pass; no installed profile, firmware or physical acceptance.\n'

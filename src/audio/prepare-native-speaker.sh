#!/usr/bin/env bash
# Called only by the retained protected full-kernel candidate, after its native prep.
set -Eeuo pipefail
kernel=$(realpath "${1:?Prepared kernel}")
output=$(realpath "${2:?Native generated directory}")
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
[[ $(cat "$owner/audio-profile") == microphones ]]
bash "$owner/src/audio/prepare-control-links.sh" "$kernel"
bash "$owner/src/audio/prepare-fs19xx-runtime.sh" "$kernel"
bash "$owner/src/audio/prepare-speaker-formats.sh" "$kernel"
for fixture in audio-fs19xx-contract audio-fs19xx-lifecycle-contract audio-graph-lifetime-contract audio-readiness-contract audio-probe-contract audio-port-lifetime-contract; do
 CC=clang CXX=clang++ bash "$owner/tests/$fixture.sh" "$kernel"
done
CC=clang bash "$owner/tests/audio-pcm-formats-contract.sh" "$kernel"
CC=clang bash "$owner/tests/audio-speaker-safety-contract.sh" "$kernel"
bash "$owner/src/audio/build-protected-topology.sh" "$output/POCO-Pad-X1-protected-speaker.conf"
cat "$output/POCO-Pad-X1-protected-speaker.conf" "$owner/src/audio/POCO-Pad-X1-Microphone-Capture.conf" > "$output/POCO-Pad-X1.conf"
alsatplg -c "$output/POCO-Pad-X1.conf" -o "$output/POCO-Pad-X1-tplg.bin"
alsatplg -d "$output/POCO-Pad-X1-tplg.bin" -o "$output/POCO-Pad-X1-decoded.conf"
for name in spk.fs.rx spk.fs.tx spk.vi.source 'MultiMedia3 Capture'; do
 grep -Fq "$name" "$output/POCO-Pad-X1-decoded.conf"
done
# Audio lives in both supplier-specific embedded display overlays, not USB.
for variant in 36 42; do
 fdtdump "$output/display-$variant.dtbo" 2>/dev/null > "$output/audio-protected-dt-$variant.txt"
 [[ $(grep -c 'foursemi,require-protection;' "$output/audio-protected-dt-$variant.txt") == 4 ]]
 [[ $(grep -c 'xiaomi,fs19xx-protected;' "$output/audio-protected-dt-$variant.txt") == 1 ]]
done
printf '%s\n' 'Protected speaker graph prepared with unchanged four-channel raw microphone capture and gain ceiling 223'

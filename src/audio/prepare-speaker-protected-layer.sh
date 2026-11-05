#!/usr/bin/env bash
# COPR-only final preparation after all cumulative peer hooks and inactive checks.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
profile=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$kernel/native-generated
(cd "$profile"; sha256sum -c --strict --quiet SHA256SUMS)
jq -e '.speaker_profile_mode=="protected-223" and .speaker_gain_ceiling==223 and
 .speaker_physical_protection_qualified==false' "$profile/source-composition.json" >/dev/null
cmp "$profile/src/audio/uke-fs19xx-runtime.c" "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c"
[[ $(grep -Fxc 'CFLAGS_uke-fs19xx-runtime.o += -DUKE_FS19XX_CONTROLS_ONLY' "$kernel/sound/soc/qcom/qdsp6/Makefile") == 1 ]]
# APM/IMCL are already present. Applying their old hunks twice is forbidden.
git -C "$kernel" apply --check --include=sound/soc/codecs/fs19xx.c "$profile/patches/boot/0073-uke-fs19xx-protected-runtime.patch"
git -C "$kernel" apply --include=sound/soc/codecs/fs19xx.c "$profile/patches/boot/0073-uke-fs19xx-protected-runtime.patch"
# Some cumulative profiles already apply 0074 in their original preparation.
if git -C "$kernel" apply --reverse --check "$profile/patches/boot/0074-uke-speaker-pcm-formats.patch" 2>/dev/null; then
 printf '%s\n' 'Qualified PCM layer already present; retaining it.'
else
 bash "$profile/src/audio/prepare-speaker-formats.sh" "$kernel"
fi
sed -i '\|^CFLAGS_uke-fs19xx-runtime.o += -DUKE_FS19XX_CONTROLS_ONLY$|d' "$kernel/sound/soc/qcom/qdsp6/Makefile"
bash "$profile/src/audio/build-protected-topology.sh" "$output/POCO-Pad-X1-protected-speaker.conf"
cat "$output/POCO-Pad-X1-protected-speaker.conf" "$profile/src/audio/POCO-Pad-X1-Microphone-Capture.conf" > "$output/POCO-Pad-X1.conf"
alsatplg -c "$output/POCO-Pad-X1.conf" -o "$output/POCO-Pad-X1-tplg.bin"
alsatplg -d "$output/POCO-Pad-X1-tplg.bin" -o "$output/POCO-Pad-X1-decoded.conf"
for name in spk.fs.rx spk.fs.tx spk.vi.source 'MultiMedia3 Capture' S24_LE S32_LE; do
 grep -Fq "$name" "$output/POCO-Pad-X1-decoded.conf"
done
for compiler in gcc clang; do
 CC=$compiler bash "$profile/tests/audio-speaker-safety-contract.sh" "$kernel"
 CC=$compiler bash "$profile/tests/audio-speaker-state-store-contract.sh" "$kernel"
 CC=$compiler bash "$profile/tests/audio-pcm-formats-contract.sh" "$kernel"
done
bash "$profile/packaging/native/check-speaker-inclusion.sh" "$kernel" prepared-protected
printf '%s\n' 'Protected223 source prepared; DSP acceptance and physical limiting remain unqualified.'

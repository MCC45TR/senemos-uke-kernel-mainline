#!/usr/bin/env bash
# COPR only: actual linked kernel, packaged firmware/UCM, generated native DT.
set -Eeuo pipefail
root=${1:?RPM buildroot}
objects=${2:?Kernel object directory}
generated=${3:?Native generated directory}
release=${4:?Kernel release}
[[ $release =~ ^7[.]3[.]1-[1-9][0-9]+-unstable$ ]]
audio_release=${release%-unstable}u
audio_driver=uke${audio_release//./_}
[[ ${#audio_driver} -lt 16 ]]
for symbol in q6apm_fs19xx_register q6apm_fs19xx_configured q6apm_fs19xx_running q6apm_fs19xx_fault; do
 awk -v symbol="$symbol" '$2==symbol {found=1} END {exit !found}' "$objects/Module.symvers"
done
for variant in 36 42; do
 fdtdump "$generated/display-$variant.dtbo" 2>/dev/null > "$generated/audio-package-dt-$variant.txt"
 [[ $(grep -c 'foursemi,require-protection;' "$generated/audio-package-dt-$variant.txt") == 4 ]]
 [[ $(grep -c 'xiaomi,fs19xx-protected;' "$generated/audio-package-dt-$variant.txt") == 1 ]]
done
firmware=$root/usr/lib/firmware/$release/qcom
first=$firmware/sm7675/POCO-Pad-X1-tplg.bin
second=$firmware/uke$audio_release/POCO-Pad-X1-tplg.bin
test -s "$first";cmp "$first" "$second"
alsatplg -d "$first" -o "$generated/audio-packaged-topology.conf"
for name in spk.fs.rx spk.fs.tx spk.vi.source spk.mfc 'MultiMedia3 Capture' S24_LE S32_LE; do
 grep -Fq "$name" "$generated/audio-packaged-topology.conf"
done
ucm=$root/usr/share/alsa/ucm2/Qualcomm/$audio_driver/Speaker-PCM.conf
test -s "$ucm"
! grep -Eq '^[[:space:]]*format[[:space:]]+S16_LE' "$ucm"
printf '%s\n' 'Full speaker package: linked guard exports, native DT admission, both firmware aliases, raw microphone retention and PCM formats pass; no physical protection claim'

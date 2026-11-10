#!/usr/bin/bash
# Cumulative delivery: two admitted source proofs, no new runtime package.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
out=$(realpath -m "${2:?Production output}")
phase=${3:?source, linked or install}
profile=$kernel/native-profile
work=$kernel/native-generated/pcm-surround733
if [[ $phase == source ]];then
 bash "$profile/src/audio/prepare-pcm-surround733.sh" "$kernel"
 bash "$profile/packaging/native/prepare-surround-full733.sh" "$kernel" "$out" verify
 bash "$profile/packaging/native/check-pcm-surround733.sh" "$kernel"
 # Check the actual generated UCM IDs, not plain configuration syntax alone.
 ucm=$kernel/native-generated/surround-profiles733
 printf '%s  %s\n' e6fb9df54268e43d83ae8a2ac679c44330f370e932d43dfd69504910c3e15a40 "$profile/referances/alsa-ucm-parser.c" | sha256sum -c --strict --quiet -
 awk '/^static int parse_is_name_safe\(/ {copy=1} copy{print} copy&&/^}/{n++;exit}END{if(n!=1)exit 1}' "$profile/referances/alsa-ucm-parser.c" > "$ucm/actual-alsa-ucm-name.inc"
 for cc in g++ clang++;do
  "$cc" -std=c++17 -O2 -UNDEBUG -Wall -Wextra -Werror -I"$ucm" "$profile/tests/speaker-surround-ucm.cpp" $(pkg-config --cflags --libs alsa) -o "$ucm/full-ucm-check"
  "$ucm/full-ucm-check" "$profile/src/audio/desktop/array-ucm2/Speaker-HiFi.conf" "$ucm/ucm/Speaker-Surround51.conf" "$ucm/ucm/Speaker-Surround71.conf" "$ucm/ucm/POCO-Pad-X1.conf"
 done
 printf 'Cumulative PCM source: actual wire cases and both original ALSA semantic imports pass; firmware/physical acceptance separate.\n'
 exit 0
fi
bash "$profile/src/audio/verify-pcm-surround733.sh" "$kernel"
if [[ $phase == linked ]];then
 llvm-readelf -h "$out/sound/soc/qcom/qdsp6/snd-q6apm.o" | grep -F AArch64
 [[ $(modinfo -F vermagic "$out/sound/soc/qcom/qdsp6/snd-q6apm.ko") == "$(cat "$out/include/config/kernel.release") "* ]]
 printf 'Cumulative PCM production object/ABI and complete source inverse pass; firmware/physical acceptance separate.\n'
 exit 0
fi
[[ $phase == install ]]
destination=${4:?RPM buildroot}
driver=$(bash "$profile/scripts/kernel-release.sh" json "$profile/manifests/cumulative-release.json" | jq -er .audio_driver)
ucm=$destination/usr/share/alsa/ucm2/Qualcomm/$driver
for id in HiFiSurround51 HiFiSurround71;do grep -F "SectionUseCase.\"$id\"" "$ucm/POCO-Pad-X1.conf";done
! grep -Eq 'SectionUseCase.*HiFi Surround [57][.]1' "$ucm/POCO-Pad-X1.conf"
for name in POCO-Pad-X1 Speaker-Surround51 Speaker-Surround71;do
 sed "s/@UKE_AUDIO_DRIVER@/$driver/g" "$kernel/native-generated/surround-profiles733/ucm/$name.conf" | cmp - "$ucm/$name.conf"
done
printf 'Cumulative PCM package: both semantic-safe UCM IDs and exact generated files retained; no new runtime family.\n'

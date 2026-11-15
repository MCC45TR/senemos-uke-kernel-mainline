#!/usr/bin/env bash
# Retain the original runtime comparison, then require the exact OOB postimage.
set -Eeuo pipefail
kernel=$(realpath "${1:?Prepared cumulative kernel}")
profile=$kernel/native-profile
actual=$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c
original=$profile/src/audio/uke-fs19xx-runtime.c
marker=$kernel/native-generated/uke-oob-native-layer
if [[ ! -e $marker ]];then
 cmp "$original" "$actual"
 exit 0
fi
[[ -f $marker && ! -L $marker ]]
jq -e '.protected_oob_native_backend_layer==1 and .speaker_gain_ceiling==223 and
 .speaker_protection_graph_admitted and (.speaker_physical_protection_qualified|not)' \
 "$profile/source-composition.json" >/dev/null
printf '%s  %s\n' \
 8b6202e36fbfb9c94f290a19a2dfc907d1b1e0c2018dd1f31547ed70df66ea57 "$original" \
 58626ac77c9fd677ccadc991f5789766ba380bab63fcc76e5030979e8b87d4e3 "$actual" | sha256sum -c --strict --quiet -
for asset in uke-fs19xx-oob-backend.c uke-fs19xx-oob-backend.h uke-fs19xx-oob.h;do
 cmp "$profile/src/audio/$asset" "$kernel/sound/soc/qcom/qdsp6/$asset"
done
cmp "$profile/src/audio/uke-audio-config-memory.c" "$kernel/drivers/soc/qcom/uke-audio-config-memory.c"
cmp "$profile/src/audio/uke-audio-config-memory.h" "$kernel/include/linux/soc/qcom/uke-audio-config-memory.h"
cmp "$profile/src/audio/uke-audio-config-dt.h" "$kernel/arch/arm64/kernel/uke-audio-config-dt.h"
printf 'Protected runtime exact preimage/postimage and complete OOB source identities pass; no physical claim.\n'

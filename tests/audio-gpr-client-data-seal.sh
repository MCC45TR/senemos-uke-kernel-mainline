#!/usr/bin/env bash
# COPR only. Exercise exact postimage and historical-preimage refusal controls.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
paths=(native-generated/uke-oob-native-layer native-generated/backend-before-client-data.c
 native-profile/source-composition.json
 native-profile/src/audio/uke-fs19xx-runtime.c
 native-profile/src/audio/uke-fs19xx-oob-backend.c
 native-profile/src/audio/uke-fs19xx-oob-backend.h
 native-profile/src/audio/uke-fs19xx-oob.h
 native-profile/src/audio/uke-audio-config-memory.c
 native-profile/src/audio/uke-audio-config-memory.h
 native-profile/src/audio/uke-audio-config-dt.h
 sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c
 sound/soc/qcom/qdsp6/uke-fs19xx-oob-backend.c
 sound/soc/qcom/qdsp6/uke-fs19xx-oob-backend.h
 sound/soc/qcom/qdsp6/uke-fs19xx-oob.h
 drivers/soc/qcom/uke-audio-config-memory.c
 include/linux/soc/qcom/uke-audio-config-memory.h
 arch/arm64/kernel/uke-audio-config-dt.h)
for path in "${paths[@]}";do install -Dm644 "$kernel/$path" "$work/$path";done
checker=$kernel/native-profile/packaging/native/check-oob-runtime731.sh
bash "$checker" "$work"
if bash "$kernel/native-profile/history-before-gpr-client-data/packaging/native/check-oob-runtime731.sh" "$work" > "$work/original.log" 2>&1;then exit 1;fi
grep -Fq 'uke-fs19xx-oob-backend.c differ' "$work/original.log"
printf 'Original OOB source seal rejects the new backend postimage as required.\n'
for path in sound/soc/qcom/qdsp6/uke-fs19xx-oob-backend.c \
 native-profile/src/audio/uke-fs19xx-oob-backend.c \
 native-generated/backend-before-client-data.c \
 native-profile/src/audio/uke-fs19xx-runtime.c \
 sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c;do
 printf '\n' >> "$work/$path"
 if bash "$checker" "$work" > "$work/refusal.log" 2>&1;then exit 1;fi
 grep -Fq 'FAILED' "$work/refusal.log"
 install -m644 "$kernel/$path" "$work/$path"
 printf 'Client-data source seal refuses changed bytes: %s.\n' "$path"
done
jq '.protected_gpr_client_data_allowed_mask=31' "$kernel/native-profile/source-composition.json" > "$work/native-profile/source-composition.json"
if bash "$checker" "$work" > "$work/refusal.log" 2>&1;then exit 1;fi
printf 'Client-data source seal refuses changed protocol masks.\n'
install -m644 "$kernel/native-profile/source-composition.json" "$work/native-profile/source-composition.json"
bash "$checker" "$work"
printf 'Exact client-data source seals pass; six altered source/contract controls refuse.\n'

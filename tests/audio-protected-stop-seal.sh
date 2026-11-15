#!/usr/bin/env bash
# COPR only. Strict new source seals and retained16 checks on exact preimages.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
paths=(native-generated/uke-oob-native-layer native-generated/backend-before-client-data.c
 native-generated/backend-before-client-byte.c native-generated/runtime-before-initial-ready.c
 native-profile/src/audio/uke-fs19xx-initial-ready.h sound/soc/qcom/qdsp6/uke-fs19xx-initial-ready.h
 native-profile/source-composition.json native-profile/src/audio/uke-fs19xx-runtime.c
 native-profile/src/audio/uke-fs19xx-oob-backend.c native-profile/src/audio/uke-fs19xx-oob-backend.h
 native-profile/src/audio/uke-fs19xx-oob.h native-profile/src/audio/uke-audio-config-memory.c
 native-profile/src/audio/uke-audio-config-memory.h native-profile/src/audio/uke-audio-config-dt.h
 sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c sound/soc/qcom/qdsp6/uke-fs19xx-oob-backend.c
 sound/soc/qcom/qdsp6/uke-fs19xx-oob-backend.h sound/soc/qcom/qdsp6/uke-fs19xx-oob.h
 drivers/soc/qcom/uke-audio-config-memory.c include/linux/soc/qcom/uke-audio-config-memory.h
 arch/arm64/kernel/uke-audio-config-dt.h native-generated/runtime-before-protected-stop.c
 native-generated/codec-before-protected-stop.c native-generated/runtime-header-before-protected-stop.h
 native-generated/graph-stop-before-protected-stop.c sound/soc/qcom/qdsp6/uke-fs19xx-runtime.h
 sound/soc/codecs/fs19xx.c sound/soc/codecs/uke-fs19xx-muted-stop.h
 native-profile/src/audio/uke-fs19xx-muted-stop.h sound/soc/qcom/qdsp6/q6apm.c
 native-profile/packaging/native/check-oob-runtime731.sh)
for path in "${paths[@]}";do install -Dm644 "$kernel/$path" "$work/$path";done
checker=$kernel/native-profile/packaging/native/check-protected-stop731.sh
bash "$checker" "$work" "$work/native-generated" source
for path in native-generated/runtime-before-protected-stop.c sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c \
 native-generated/codec-before-protected-stop.c sound/soc/codecs/fs19xx.c \
 native-generated/runtime-header-before-protected-stop.h sound/soc/qcom/qdsp6/uke-fs19xx-runtime.h \
 native-generated/graph-stop-before-protected-stop.c native-profile/src/audio/uke-fs19xx-muted-stop.h \
 sound/soc/codecs/uke-fs19xx-muted-stop.h;do
 printf '\n' >> "$work/$path"
 if bash "$checker" "$work" "$work/native-generated" source > "$work/refusal.log" 2>&1;then exit 1;fi
 grep -Fq FAILED "$work/refusal.log"
 install -m644 "$kernel/$path" "$work/$path"
 printf 'Muted-stop source seal refuses changed bytes: %s.\n' "$path"
done
sed 's/return mute_ret ? mute_ret : ret;/return ret;/' "$kernel/sound/soc/qcom/qdsp6/q6apm.c" > "$work/sound/soc/qcom/qdsp6/q6apm.c"
if bash "$checker" "$work" "$work/native-generated" source > "$work/refusal.log" 2>&1;then exit 1;fi
grep -Fq FAILED "$work/refusal.log"
install -m644 "$kernel/sound/soc/qcom/qdsp6/q6apm.c" "$work/sound/soc/qcom/qdsp6/q6apm.c"
printf 'Muted-stop source seal refuses changed STOP callback.\n'
for property in protected_stop_vi_until_reply protected_stop_existing_fault_deadline;do
 jq --arg property "$property" '.[$property]=false' "$kernel/native-profile/source-composition.json" > "$work/native-profile/source-composition.json"
 if bash "$checker" "$work" "$work/native-generated" source > "$work/refusal.log" 2>&1;then exit 1;fi
 printf 'Muted-stop source seal refuses changed contract: %s.\n' "$property"
done
install -m644 "$kernel/native-profile/source-composition.json" "$work/native-profile/source-composition.json"
bash "$checker" "$work" "$work/native-generated" source
printf 'Exact muted-stop seals pass; twelve altered source/contract controls refuse.\n'

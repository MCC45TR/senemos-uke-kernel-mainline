#!/usr/bin/env bash
# COPR only. Exact source identities, then actual cumulative AArch64 objects.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Cumulative kernel}")
out=$(realpath "${2:?Native output or generated source directory}")
phase=${3:-objects}
[[ $phase == source || $phase == objects || $phase == linked ]]
profile=$kernel/native-profile
generated=$kernel/native-generated
for path in "$generated/runtime-before-protected-stop.c" "$generated/codec-before-protected-stop.c" "$generated/runtime-header-before-protected-stop.h" "$generated/graph-stop-before-protected-stop.c";do [[ -f $path && ! -L $path ]];done
jq -e '.protected_stop_drain_layer==1 and .protected_stop_mute_before_dsp and .protected_stop_vi_until_reply and .protected_stop_poweroff_after_reply and .protected_stop_failure_erases and .protected_stop_existing_fault_deadline and .protected_stop_no_gain_calibration_change and .speaker_gain_ceiling==223 and (.speaker_physical_protection_qualified|not)' "$profile/source-composition.json" >/dev/null
printf '%s  %s\n' \
 0e526c3eddccff940925900fc2db4cd0279136de14cac7f393375f98f1ae21ee "$generated/runtime-before-protected-stop.c" \
 3774c03041895fb5876611c4e73d3bf19aaa191d1d5cd3278fd13667dc1492b5 "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c" \
 e2ca68c256f47bb7bc339ffb4dfb5833dc5787904828eed68f75dafd613f77b8 "$generated/codec-before-protected-stop.c" \
 4c7ce07b2868cdc76fc0534f9bfe46805b956ebdb6200dacd44fa205579651e2 "$kernel/sound/soc/codecs/fs19xx.c" \
 58bd8b9c9c947632cae1c0951fb0b5facd25a683e8a6b2bd93e0a27d35a0466a "$generated/runtime-header-before-protected-stop.h" \
 465cf1060b9e0252ae5febf3b669034be67c08c86d6e00f42f669bea32c1804c "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.h" \
 7ccd1442087c2f26769bae2f3378b33539d7aa6868880d32aac71ad14e91dd43 "$generated/graph-stop-before-protected-stop.c" \
 aac729f7c7c893cf69048da8c21c8c0cdf078dd9563ddf0a594c63323a004955 "$profile/src/audio/uke-fs19xx-muted-stop.h" \
 aac729f7c7c893cf69048da8c21c8c0cdf078dd9563ddf0a594c63323a004955 "$kernel/sound/soc/codecs/uke-fs19xx-muted-stop.h" | sha256sum -c --strict -
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
awk '/^int q6apm_graph_stop\(/ {copy=1} copy{print} copy&&/^}/ {found++;exit} END{if(found!=1)exit 1}' "$kernel/sound/soc/qcom/qdsp6/q6apm.c" > "$work/stop.c"
printf '%s  %s\n' e6569ecf3efef40c4613b45faa7891e905c17946096eb36f1434795a4e6278e6 "$work/stop.c" | sha256sum -c --strict -
bash "$profile/packaging/native/check-oob-runtime731.sh" "$kernel"
printf 'Exact muted-stop source/runtime/codec/STOP seals pass; physical sound remains unqualified.\n'
[[ $phase != source ]] || exit 0
bash "$profile/packaging/native/check-client-byte-ready731.sh" "$kernel" "$out" "$phase"
for path in sound/soc/qcom/qdsp6/q6apm.o sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o sound/soc/qcom/qdsp6/snd-q6apm.o sound/soc/codecs/fs19xx.o;do llvm-readelf -h "$out/$path" | grep -E 'Machine:.*AArch64';done
llvm-nm -u "$out/sound/soc/qcom/qdsp6/q6apm.o" > "$work/q6apm"
grep -Eq ' U q6apm_fs19xx_stopping$' "$work/q6apm"
llvm-nm -g --defined-only "$out/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o" > "$work/runtime"
grep -Eq ' T q6apm_fs19xx_stopping$' "$work/runtime"
llvm-nm -g --defined-only "$out/sound/soc/qcom/qdsp6/snd-q6apm.o" > "$work/composite"
grep -Eq ' T q6apm_fs19xx_stopping$' "$work/composite"
llvm-nm -u "$out/sound/soc/qcom/qdsp6/snd-q6apm.o" > "$work/unresolved"
! grep -Eq ' U q6apm_fs19xx_stopping$' "$work/unresolved"
printf 'Actual AArch64 muted protected STOP runtime/caller/codec/composite passed:%s; physical speakers remain unqualified.\n' "$phase"

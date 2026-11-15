#!/usr/bin/env bash
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Cumulative kernel}")
out=$(realpath "${2:?Native output}")
phase=${3:-objects}
[[ $phase == objects || $phase == linked ]]
printf '%s  %s\n' \
 6d9b4b98558345593762a2f10291d7d17f1279453bc8dacb15ee42c4a33d5113 "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-oob-backend.c" \
 0e526c3eddccff940925900fc2db4cd0279136de14cac7f393375f98f1ae21ee "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c" | sha256sum -c --strict -
bash "$kernel/native-profile/packaging/native/check-client-data731.sh" "$kernel" "$out" "$phase"
object=$out/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o
llvm-readelf -h "$object" | grep -E 'Machine:.*AArch64'
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
llvm-nm -u "$object" > "$work/undefined"
for symbol in schedule_timeout prepare_to_wait_event finish_wait __wake_up;do grep -Eq " U $symbol$" "$work/undefined";done
printf 'Actual AArch64 target client-byte/runtime wait-wake/APM composite passed:%s; physical sound remains unqualified.\n' "$phase"

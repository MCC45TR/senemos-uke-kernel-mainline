#!/usr/bin/env bash
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Cumulative kernel}")
out=$(realpath "${2:?Native output}")
phase=${3:-objects}
[[ $phase == objects || $phase == linked ]]
printf '%s  %s\n' bcbff25aebc8189deafbc957dd754943c76434ed12712b45bb3ff998c2ef1690 "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-oob-backend.c" | sha256sum -c --strict -
bash "$kernel/native-profile/packaging/native/check-config-smmu731.sh" "$kernel" "$out" "$phase"
bash "$kernel/native-profile/packaging/native/check-oob-objects731.sh" "$kernel" "$out" "$phase"
printf 'Actual AArch64 client-data backend and APM composite pass:%s; physical audio remains unqualified.\n' "$phase"

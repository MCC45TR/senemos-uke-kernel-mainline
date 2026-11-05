#!/usr/bin/env bash
# COPR only: actual prepared callbacks with synthetic OF/register operations.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
directory=${1:?Prepared arm-smmu directory}
here=$(cd -- "$(dirname -- "$0")/.." && pwd)
helper=${2:-$directory/uke-cdsp-smmu.c}
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
awk '/^static bool qcom_uke_sensor_cb\(/ {p=1} p {print} p&&/^}/ {exit}' \
    "$directory/arm-smmu-qcom.c" > "$stage/actual-admission.inc"
awk '/^static int qcom_uke_smmu_alloc_context_bank\(/ {p=1} p {print} p&&/^}/ {exit}' \
    "$directory/arm-smmu-qcom.c" > "$stage/actual-allocation.inc"
cp "$helper" "$stage/actual-cdsp.inc"
read -r -a flags <<< "${CFLAGS:-}"
"${CC:-cc}" -std=gnu11 -O1 -g -Wall -Wextra -Werror -Wno-sign-compare "${flags[@]}" \
    -I "$stage" "$here/tests/fixtures/cdsp-actlr-check.c" -o "$stage/check"
ulimit -c 0
"$stage/check"

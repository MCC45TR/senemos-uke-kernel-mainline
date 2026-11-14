#!/usr/bin/env bash
# COPR only: execute actual helper and allocator with synthetic OF/bitmap ops.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Cumulative kernel}")
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
before=$kernel/native-generated/smmu-before-audio-config.c
actual=$kernel/drivers/iommu/arm/arm-smmu
cc=${CC:-gcc};san=${SANITIZE:-0}
[[ $san == 0 || $san == 1 ]]
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
ulimit -c 0
flags=(-std=gnu11 -O1 -g -Wall -Wextra -Werror -Wno-sign-compare -Wno-unused-parameter -Wno-unused-function -fno-omit-frame-pointer)
[[ $san == 0 ]] || flags+=(-fsanitize=address,undefined -fno-sanitize-recover=all)
extract() {
 local source=$1
 for name in sensor hdmi;do
  func=qcom_uke_sensor_cb;[[ $name != hdmi ]] || func=qcom_uke_hdmi_dma
  awk -v fn="$func" '$0~("^static bool "fn"\\("){p=1}p{print}p&&/^}/{exit}' "$source" > "$work/actual-$name.inc"
  test -s "$work/actual-$name.inc"
 done
 awk '/^static int qcom_uke_smmu_alloc_context_bank\(/{p=1}p{print}p&&/^}/{exit}' "$source" > "$work/actual-allocation.inc"
 test -s "$work/actual-allocation.inc"
}
compile() { "$cc" "${flags[@]}" "$@" -I "$work" "$owner/tests/audio-config-smmu.c" -o "$work/test"; }
assert_control() {
 local result
 if "$work/test" > "$work/control.log" 2>&1;then echo 'Missing required assertion' >&2;exit 1;else result=$?;fi
 [[ $result == 134 ]]
 grep -Fq 'Assertion' "$work/control.log"
}
extract "$actual/arm-smmu-qcom.c"
cp "$actual/uke-audio-config-smmu.c" "$work/actual-config.inc"
compile
ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/test"
printf 'Actual root-supplier SMMU passed: %s/sanitize%s.\n' "$cc" "$san"
if [[ $san == 0 ]];then
 extract "$before";compile -DORIGINAL;assert_control
 grep -Fq 'allocate()==7&&allocations==1' "$work/control.log"
 printf 'Original frontend-only SMMU allocator rejects root supplier before allocation: %s/status134.\n' "$cc"
 extract "$actual/arm-smmu-qcom.c"
 for mutation in encoded-sid frontend controller;do
  case $mutation in
   encoded-sid) expression='s/spec->ids\[0\] != 0x801001/false/';;
   frontend) expression='s/memcmp(supplier, frontend, bytes)/false/';;
   controller) expression='s/controller != smmu->dev->of_node/false/';;
  esac
  sed "$expression" "$actual/uke-audio-config-smmu.c" > "$work/actual-config.inc"
  if cmp -s "$actual/uke-audio-config-smmu.c" "$work/actual-config.inc";then exit 1;fi
  compile;assert_control
  printf 'Actual root-supplier SMMU mutant detected: %s/%s/status134.\n' "$cc" "$mutation"
 done
fi

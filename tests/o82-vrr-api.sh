#!/usr/bin/env bash
# COPR only. Compile exact callback/metadata block, without a display operation.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
cc=${CC:-gcc};san=${SANITIZE:-0}
[[ $san == 0 || $san == 1 ]]
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
ulimit -c 0
awk '/^static unsigned int o82_vrr_test_min_hz;/ {copy=1} copy{print}
 /^MODULE_PARM_DESC\(o82_vrr_floor_api,/ {description=1}
 description&&/\);$/ {found++;exit} END{if(found!=1)exit 1}' \
 "$kernel/drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c" > "$work/actual-vrr-api.inc"
flags=(-std=c11 -O1 -g -Wall -Wextra -Werror -fno-omit-frame-pointer)
[[ $san == 0 ]] || flags+=(-fsanitize=address,undefined -fno-sanitize-recover=all)
compile(){ "$cc" "${flags[@]}" -I "$work" "$owner/tests/o82-vrr-api.c" -o "$work/check"; }
compile
ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/check"
printf 'Actual O82 VRR API passed: %s/sanitize%s.\n' "$cc" "$san"
if [[ $san == 0 ]];then
 cp "$work/actual-vrr-api.inc" "$work/good.inc"
 for mutant in writable-api wrong-api-version;do
  case $mutant in
   writable-api) sed '/^static const struct kernel_param_ops o82_vrr_api_ops = {/a\	.set = param_set_uint,' "$work/good.inc" > "$work/actual-vrr-api.inc";;
   wrong-api-version) sed 's/o82_vrr_floor_api = 1;/o82_vrr_floor_api = 2;/' "$work/good.inc" > "$work/actual-vrr-api.inc";;
  esac
  compile
  set +e
  "$work/check" > "$work/refusal.log" 2>&1
  result=$?
  set -e
  [[ $result == 134 ]]
  grep -Eq 'Assertion|assertion' "$work/refusal.log"
  printf 'Actual O82 VRR API mutant refused: %s/%s/status134.\n' "$cc" "$mutant"
 done
fi

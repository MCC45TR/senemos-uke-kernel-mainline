#!/usr/bin/bash
# COPR only. Test new callbacks before inherited object work, without mutating it.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
mode=${2:?test or verify}
record=$kernel/native-generated/avr-early-files.sha256
case $mode in
 test)
  work=$(mktemp -d)
  trap 'find "$work" -depth -delete' EXIT
  path=drivers/gpu/drm/msm/disp/dpu1
  mkdir -p "$work/$path" "$kernel/native-generated"
  for file in dpu_encoder.c dpu_hw_intf.c dpu_hw_intf.h; do cp "$kernel/$path/$file" "$work/$path/$file"; done
  ln -s "$kernel/native-profile" "$work/native-profile"
  bash "$kernel/native-profile/src/display/apply-avr-transaction733.sh" "$work"
  bash "$kernel/native-profile/tests/kernel-release-advance.sh" "$kernel/native-profile"
  for compiler in gcc clang; do
   for sanitize in 0 1; do
    CC=$compiler SANITIZE=$sanitize bash "$kernel/native-profile/tests/o82-avr-transaction.sh" "$work"
   done
  done
  (cd "$work"; sha256sum "$path/dpu_encoder.c" "$path/dpu_hw_intf.c" "$path/dpu_hw_intf.h") > "$record"
  printf 'Early actual AVR callbacks qualified in an isolated source view; inherited source untouched.\n'
  ;;
 verify)
  test -s "$record"
  (cd "$kernel"; sha256sum -c --strict "$record")
  printf 'Late native AVR C/header postimages exactly match the early tested source view.\n'
  ;;
 *) exit 2;;
esac

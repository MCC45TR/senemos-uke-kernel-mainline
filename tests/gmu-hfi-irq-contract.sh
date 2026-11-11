#!/usr/bin/env bash
# COPR only: actual IRQ and synchronous waiter, modeled register boundaries.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Pass retained callback source directory}")
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
ulimit -c 0
gmu=$kernel/drivers/gpu/drm/msm/adreno/a6xx_gmu.c
hfi=$kernel/drivers/gpu/drm/msm/adreno/a6xx_hfi.c
extract() {
 awk -v start="$1" 'index($0,start)==1 {emit=1} emit{print} emit&&/^}/{exit}' "$2" > "$3"
 test -s "$3"
}
extract 'static irqreturn_t a6xx_hfi_irq(' "$gmu" "$stage/irq.inc"
extract 'static int a6xx_hfi_wait_for_msg_interrupt(' "$hfi" "$stage/wait.inc"
# Linux generates its register header from this pinned XML. Derive only the
# four fixture constants with native awk; no build generator or Python runs.
awk -F '\"' '
 function attr(name, i) {for(i=1;i<NF;i+=2)if($i~("(^| )"name"=$"))return $(i+1);return ""}
 /<reg32 / {
  reg=attr("name")
  if(reg=="GMU_GMU2HOST_INTR_INFO" || reg=="GMU_GMU2HOST_INTR_CLR") {
   value=attr("offset");if(value!~/^0x[0-9a-fA-F]+$/)exit 1
   printf "#define REG_A6XX_%s %su\n",reg,value;registers++
  }
 }
 reg=="GMU_GMU2HOST_INTR_INFO" && /<bitfield / {
  name=attr("name");pos=attr("pos")
  if(name=="MSGQ" || name=="CM3_FAULT") {
   if(pos!~/^[0-9]+$/ || pos>31)exit 1
   printf "#define A6XX_GMU_GMU2HOST_INTR_INFO_%s (UINT32_C(1) << %s)\n",name,pos;bits++
  }
 }
 /<\/reg32>/ {reg=""}
 END {if(registers!=2 || bits!=2)exit 1}
' "$kernel/drivers/gpu/drm/msm/registers/adreno/a6xx_gmu.xml" > "$stage/registers.inc"
awk '$1=="#define"&&$2=="HFI_H2F_MSG_GX_BW_PERF_VOTE" {print;found++} END{if(found!=1)exit 1}' \
 "$kernel/drivers/gpu/drm/msm/adreno/a6xx_hfi.h" >> "$stage/registers.inc"
printf 'Original retained IRQ and waiter SHA256:\n'
sha256sum "$stage/irq.inc" "$stage/wait.inc"
printf '%s  %s\n' \
 9ee70b3f49184e1aaceb03e18495023ccbbbc1f2674a3a70dd2a787ecbd5dff0 "$stage/irq.inc" \
 89cd584b2e2f874b7afa8e1a036a07ac5ae77a0802a82aa5e964a150751b3741 "$stage/wait.inc" \
 | sha256sum -c --strict
# Callback signatures intentionally retain unused Linux API parameters.
gcc -std=gnu11 -O2 -UNDEBUG -Wall -Wextra -Werror -Wno-unused-parameter \
 -I "$stage" "$owner/tests/fixtures/gmu-hfi-irq-check.c" -o "$stage/check"
set +e
"$stage/check" > "$stage/original.log" 2>&1
status=$?
set -e
if [[ $status != 134 ]] || ! grep -Fq 'HFI response must survive an unrelated fault IRQ' "$stage/original.log"; then
 cat "$stage/original.log"
 printf 'Actual original IRQ/waiter did not fail the required independent response assertion134\n' >&2
 exit 1
fi
printf 'Actual original IRQ loses the pending MSGQ response: required assertion134 observed\n'
git -C "$kernel" apply --check "$owner/patches/gpu/0075-gmu-hfi-irq-owned-status.patch"
git -C "$kernel" apply "$owner/patches/gpu/0075-gmu-hfi-irq-owned-status.patch"
extract 'static irqreturn_t a6xx_hfi_irq(' "$gmu" "$stage/irq.inc"
export ASAN_OPTIONS=halt_on_error=1:abort_on_error=1:detect_leaks=1
export UBSAN_OPTIONS=halt_on_error=1:abort_on_error=1
for compiler in gcc clang; do
 for sanitize in no yes; do
  flags=()
  [[ $sanitize == no ]] || flags+=(-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$compiler" -std=gnu11 -O2 -UNDEBUG -Wall -Wextra -Werror -Wno-unused-parameter \
   "${flags[@]}" -I "$stage" "$owner/tests/fixtures/gmu-hfi-irq-check.c" -o "$stage/check"
  "$stage/check"
  printf 'GMU IRQ native contract: %s sanitizers=%s passed\n' "$compiler" "$sanitize"
 done
done
printf 'Corrected IRQ SHA256:\n'
sha256sum "$stage/irq.inc"
printf 'Actual callback/waiter qualification only; full linked kernel and Uke physical effectiveness remain pending\n'

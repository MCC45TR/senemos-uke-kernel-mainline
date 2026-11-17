#!/usr/bin/bash
# COPR only; never access a real adapter, EEPROM or regulator.
set -Eeuo pipefail
[[ $# == 3 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1");source=$(realpath "$2");owner=$(realpath "$3")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
ulimit -c 0
awk '/^void \*__init uke_abl_prepare_fdt\(.*\)$/{copy=1}copy{print}copy&&/^}/{exit}' "$source" > "$work/entry.h"
[[ $(grep -Fc 'void *__init uke_abl_prepare_fdt' "$work/entry.h") == 1 ]]
awk '/^static int UKE_INIT uke_scope_qup_buses\(/{copy=1}copy{print}copy&&/^}/{exit}' "$source" > "$work/qup-scope.h"
awk '/^static int UKE_INIT uke_bwmon_mc_tags\(/{copy=1}copy{print}copy&&/^}/{exit}' "$kernel/arch/arm64/kernel/uke-bwmon.h" > "$work/bwmon-tags.h"
[[ $(grep -Fc 'static int UKE_INIT uke_bwmon_mc_tags' "$work/bwmon-tags.h") == 1 ]]
cp "$kernel/boot-recipe/tests/fixtures/front-eeprom-fdt-check.c" "$work/"
early=0
if grep -Fq 'ret = uke_front_eeprom_graph(output);' "$source"; then early=1; fi
read -ra flags <<< "$FRONT_STAGE_FLAGS"
"$CC" -std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror "${flags[@]}" \
 -DEARLY_FRONT_GATE="$early" -I "$work" -I "$kernel/arch/arm64/kernel" \
 "$owner/tests/fixtures/front-stage734-check.c" -lfdt -o "$work/check"
ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 timeout 20s "$work/check"

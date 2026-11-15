#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -Eeuo pipefail
[[ ($# == 3 || $# == 4) && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1"); out=$(realpath -m "$2"); phase=$3
layer=$kernel/qtee-information
work=$kernel/native-generated/qtee-information733
release=$(jq -er .kernel_release "$kernel/native-profile/source-composition.json")
if [[ $phase == source ]]; then
 [[ $# == 3 && ! -e $work ]]
 mkdir -p "$work/before"
 for file in call.c Makefile; do install -m644 "$kernel/drivers/tee/qcomtee/$file" "$work/before/$file"; done
 bash "$layer/src/security/apply-qtee-tpm-info733.sh" "$kernel" "$layer"
 for compiler in g++ clang++; do
  for sanitizer in plain address-undefined; do
   flags=()
   if [[ $sanitizer != plain ]]; then flags=(-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer); fi
   "$compiler" -std=c++20 -O2 -Wall -Wextra -Werror "${flags[@]}" \
    -I"$layer/src/security" "$layer/tests/qtee-tpm-info-core.cpp" -o "$work/fixture"
   "$work/fixture" > "$work/core-$compiler-$sanitizer.json"
   jq -e '.same_production_core and .transport_doubled and .positive_types==3 and .refused_cases==23 and
    .all_owned_references_released and .no_automatic_retry and .previous_reply_cleared and
    (.firmware_called|not) and (.physical_tpm_qualified|not)' "$work/core-$compiler-$sanitizer.json"
  done
 done
 find "$work" -maxdepth 1 -type f -name fixture -delete
 (cd "$kernel"; sha256sum drivers/tee/qcomtee/{call.c,Makefile,qtee-tpm-info.c,qtee-tpm-info.h,qtee-tpm-info-core.h}) > "$work/source.sha256"
 touch "$work/source-complete"
 exit 0
fi
[[ -f $work/source-complete ]]
(cd "$kernel"; sha256sum -c --strict --quiet "$work/source.sha256")
if [[ $phase == linked ]]; then
 [[ $(cat "$out/include/config/kernel.release") == "$release" ]]
 for symbol in uke_qtee_tpm_info_attach uke_qtee_tpm_info_detach; do
  llvm-nm --defined-only "$out/drivers/tee/qcomtee/qtee-tpm-info.o" | awk -v symbol="$symbol" '$NF==symbol{found=1}END{exit !found}'
 done
 grep -aqF uke_tpm_information "$out/drivers/tee/qcomtee/qtee-tpm-info.o"
 (cd "$out"; sha256sum drivers/tee/qcomtee/{call.o,qtee-tpm-info.o,core.o} arch/arm64/boot/Image .config) > "$work/linked.sha256"
 exit 0
fi
[[ -s $work/linked.sha256 ]]
(cd "$out"; sha256sum -c --strict --quiet "$work/linked.sha256")
if [[ $phase == sealed ]]; then exit 0; fi
[[ $# == 4 && ($phase == install || $phase == check) ]]
identity=$(realpath -m "$4")/usr/share/senemos/uke/$release
if [[ $phase == install ]]; then
 install -m644 "$work/source.sha256" "$identity/qtee-information-source.sha256"
 install -m644 "$work/linked.sha256" "$identity/qtee-information-linked.sha256"
 install -m644 "$layer/manifests/qtee-information-20261115.json" "$identity/qtee-information-delivery.json"
else
 cmp "$work/source.sha256" "$identity/qtee-information-source.sha256"
 cmp "$work/linked.sha256" "$identity/qtee-information-linked.sha256"
 cmp "$layer/manifests/qtee-information-20261115.json" "$identity/qtee-information-delivery.json"
fi

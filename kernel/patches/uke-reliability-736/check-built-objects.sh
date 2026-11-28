#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -Eeuo pipefail
export LC_ALL=C
[[ $# == 2 ]]
out=$(realpath -e -- "$1")
assets=$(realpath -e -- "$2")
cd "$out"
mapfile -t objects < <(awk -F '\t' '{sub(/\.c$/, ".o", $3); print $3}' "$assets/qualified-features.tsv")
[[ ${#objects[@]} == 5 ]]
for object in "${objects[@]}"; do
    header=$(llvm-readelf -h "$object")
    grep -Eq 'Machine:[[:space:]]+AArch64' <<< "$header"
done

baud=$(strings drivers/bluetooth/hci_qca.o)
clock=$(strings drivers/iio/common/uke-ssc/uke-ssc-iio.o)
apr=$(llvm-nm --defined-only drivers/soc/qcom/apr.o)
audio=$(llvm-nm sound/soc/qcom/qdsp6/q6apm-dai.o)
grep -Fq 'Controller baud-rate status: %#x' <<< "$baud"
grep -Fxq 'ssc_timestamp_trial' <<< "$clock"
grep -Eq ' T gpr_free_port$' <<< "$apr"
grep -Eq ' [tT] q6apm_dai_compr_trigger$' <<< "$audio"
grep -Eq ' [tT] q6apm_compr_copy$' <<< "$audio"
grep -Eq ' U system_dfl_wq$' <<< "$audio"

sha256sum -- "${objects[@]}"

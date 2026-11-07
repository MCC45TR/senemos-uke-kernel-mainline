#!/usr/bin/env bash
# Exact complete17 extension; native symbol checks never replace physical tests.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared complete kernel}")
out=$(realpath "${2:?Native output}")
phase=${3:-objects}
[[ $phase == source || $phase == objects || $phase == linked ]]
profile=$kernel/native-profile
jq -e '.protected_idle_worker_layer==1 and .protected_idle_atomic_guard_classification and .protected_idle_real_faults_retained and .speaker_gain_ceiling==223 and (.physical_acceptance|not)' "$profile/source-composition.json" >/dev/null
paths=(sound/soc/codecs/fs19xx.c sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c include/sound/uke-fs19xx-guard.h)
after=(d8a9e70f14fd854e3333352199abc0fb5fe8d632c1bf298b25d01d931cc494cb d9bf78985dd1de6db50daddce2c544d2b88496b085f821bcfdab86a44c4da157 be42db31591220ae1e8a8177e20d85e21cc22a26e4ca881872c0172cd7f6dd99)
for i in 0 1 2;do printf '%s  %s\n' "${after[i]}" "$kernel/${paths[i]}" | sha256sum -c --strict -;done
[[ $phase != source ]] || exit 0
bash "$profile/packaging/native/check-protected-stop731.sh" "$kernel" "$out" "$phase"
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
apm=$out/sound/soc/qcom/qdsp6/snd-q6apm.o
codec=$out/sound/soc/codecs/fs19xx.o
for file in "$apm" "$codec";do llvm-readelf -h "$file" | grep -E 'Machine:.*AArch64';done
llvm-nm -g --defined-only "$apm" > "$work/apm"
llvm-nm -u "$codec" > "$work/codec"
llvm-nm "$apm" > "$work/exports"
grep -Eq ' T q6apm_fs19xx_output_fault$' "$work/apm"
grep -Eq ' [rR] __export_symbol_q6apm_fs19xx_output_fault$' "$work/exports"
llvm-readelf -rW "$apm" | awk '
 /^Relocation section / {emit=($0 ~ /[.]rela[.]export_symbol/)}
 emit {print}' > "$work/export-relocations"
grep -Eq 'R_AARCH64_ABS64[[:space:]]+[^[:space:]]+[[:space:]]+q6apm_fs19xx_output_fault([[:space:]]|$)' "$work/export-relocations"
grep -Fx 'EXPORT_SYMBOL_GPL(q6apm_fs19xx_output_fault);' "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c"
grep -Eq ' U q6apm_fs19xx_output_fault$' "$work/codec"
if [[ $phase == linked ]];then
 llvm-nm "$out/sound/soc/qcom/qdsp6/snd-q6apm.ko" > "$work/module-exports"
 grep -Eq ' [rR] __ksymtab_q6apm_fs19xx_output_fault$' "$work/module-exports"
fi
printf 'Actual AArch64 healthy-idle runtime/codec/export passed:%s; physical repeat use remains unqualified.\n' "$phase"

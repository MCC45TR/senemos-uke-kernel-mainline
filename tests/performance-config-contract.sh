#!/usr/bin/env bash
# Host-only validation of a fully resolved Linux .config, not an input fragment.
# Usage: bash tests/performance-config-contract.sh PATH/TO/.config [--thinlto]
set -Eeuo pipefail
[[ $# == 1 || $# == 2 ]] || { echo 'Expected .config [--thinlto]' >&2; exit 64; }
config=$1
[[ -f $config ]] || { echo "Missing resolved configuration: $config" >&2; exit 66; }
[[ $# == 1 || $2 == --thinlto ]] || exit 64
for symbol in PREEMPT PREEMPT_DYNAMIC CPU_FREQ CPU_FREQ_GOV_SCHEDUTIL \
    CPU_FREQ_DEFAULT_GOV_SCHEDUTIL ENERGY_MODEL UCLAMP_TASK UCLAMP_TASK_GROUP \
    LRU_GEN LRU_GEN_ENABLED BPF BPF_SYSCALL BPF_JIT \
    BPF_JIT_ALWAYS_ON BPF_JIT_DEFAULT_ON DEBUG_INFO_DWARF5 \
    DEBUG_INFO_BTF SCHED_CLASS_EXT KALLSYMS_ALL FUNCTION_TRACER; do
    if ! grep -Fxq "CONFIG_${symbol}=y" "$config"; then
        printf 'Performance candidate Kconfig unresolved: CONFIG_%s\n' "$symbol" >&2
        exit 1
    fi
done
for symbol in DEBUG_INFO_NONE DEBUG_INFO_REDUCED LTO_CLANG_FULL; do
    if grep -Fxq "CONFIG_${symbol}=y" "$config"; then
        printf 'Incompatible option enabled: CONFIG_%s\n' "$symbol" >&2
        exit 1
    fi
done
if [[ $# == 2 ]]; then
    grep -Fxq 'CONFIG_LTO_CLANG_THIN=y' "$config" || { echo 'ThinLTO not resolved' >&2; exit 1; }
    ! grep -Fxq 'CONFIG_LTO_NONE=y' "$config" || { echo 'LTO_NONE conflicts with ThinLTO' >&2; exit 1; }
else
    grep -Fxq 'CONFIG_LTO_NONE=y' "$config" || { echo 'Base cohort must retain LTO_NONE' >&2; exit 1; }
fi
echo 'Resolved Uke experimental performance configuration passed (host-only)'

#!/usr/bin/env bash
# Compare an integration baseline and candidate without invoking a compiler.
set -Eeuo pipefail
baseline=${1:?Pass the complete baseline native configuration}
candidate=${2:?Pass the complete candidate native configuration}
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
symbols=(CPU_FREQ_GOV_POWERSAVE CPU_FREQ_GOV_CONSERVATIVE DEVFREQ_GOV_PERFORMANCE DEVFREQ_GOV_POWERSAVE)
for symbol in "${symbols[@]}"; do
    [[ $(grep -Ec "^(CONFIG_${symbol}=|# CONFIG_${symbol} is not set$)" "$candidate") == 1 ]]
    grep -Fxq "CONFIG_${symbol}=y" "$candidate"
done
for symbol in CPU_FREQ_GOV_POWERSAVE CPU_FREQ_GOV_CONSERVATIVE; do
    grep -Fxq "CONFIG_${symbol}=m" "$baseline"
done
for symbol in DEVFREQ_GOV_PERFORMANCE DEVFREQ_GOV_POWERSAVE; do
    grep -Fxq "# CONFIG_${symbol} is not set" "$baseline"
done
for symbol in CPU_FREQ_DEFAULT_GOV_SCHEDUTIL CPU_FREQ_GOV_SCHEDUTIL CPU_FREQ_GOV_PERFORMANCE \
    CPU_FREQ_GOV_USERSPACE CPU_FREQ_GOV_ONDEMAND DEVFREQ_GOV_SIMPLE_ONDEMAND \
    DEVFREQ_GOV_USERSPACE MQ_IOSCHED_DEADLINE MQ_IOSCHED_KYBER IOSCHED_BFQ BFQ_GROUP_IOSCHED; do
    grep -Fxq "CONFIG_${symbol}=y" "$candidate"
done
pattern='^(CONFIG_(CPU_FREQ_GOV_(POWERSAVE|CONSERVATIVE)|DEVFREQ_GOV_(PERFORMANCE|POWERSAVE))=|# CONFIG_(CPU_FREQ_GOV_(POWERSAVE|CONSERVATIVE)|DEVFREQ_GOV_(PERFORMANCE|POWERSAVE)) is not set$)'
grep -Ev "$pattern" "$baseline" > "$stage/baseline"
grep -Ev "$pattern" "$candidate" > "$stage/candidate"
cmp "$stage/baseline" "$stage/candidate"
printf '%s\n' 'PASS: four governor options built in; every other native config line retained'

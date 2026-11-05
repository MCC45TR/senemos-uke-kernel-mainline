#!/usr/bin/env bash
# Compare resolved complete configs. Never hide unrelated configuration changes.
set -Eeuo pipefail
before=${1:?resolved baseline}
after=${2:?resolved manager config}
fragment=${3:?intent fragment}
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
while IFS= read -r line; do
 if [[ $line =~ ^CONFIG_[A-Z0-9_]+=(y|m)$ || $line =~ ^\#\ CONFIG_[A-Z0-9_]+\ is\ not\ set$ ]]; then
  grep -Fxq "$line" "$after" || { printf 'Unresolved intent: %s\n' "$line" >&2; exit 1; }
 fi
done < "$fragment"
sed -n -E 's/^(# )?(CONFIG_[A-Z0-9_]+).*/\2/p' "$fragment" > "$stage/symbols"
# Dependencies are admitted at exact values, never by an unrestricted prefix.
while IFS= read -r line; do
 [[ $line =~ ^CONFIG_[A-Z0-9_]+=.+$ ]]
 symbol=${line%%=*}
 if grep -q "^$symbol=" "$after"; then
  grep -Fxq "$line" "$after"
  if grep -q "^$symbol=" "$before"; then
   grep -Fxq "$line" "$before" || { printf 'Dependency would replace an existing value: %s\n' "$symbol" >&2; exit 1; }
  fi
 fi
 printf '%s\n' "$symbol" >> "$stage/symbols"
done < "$owner/configs/kernel-manager/resource-dependencies.txt"
LC_ALL=C sort -u "$stage/symbols" -o "$stage/symbols"
normalize() {
 # An unreachable symbol and an explicitly disabled symbol both mean n.
 awk -v list="$stage/symbols" '
 BEGIN {while((getline s < list)>0) skip[s]=1}
 /^CONFIG_[A-Z0-9_]+=/ {key=$0;sub(/=.*/,"",key);if(!skip[key])print}
 ' "$1" | LC_ALL=C sort
}
normalize "$before" > "$stage/before"
normalize "$after" > "$stage/after"
diff -u "$stage/before" "$stage/after"
for symbol in CPU_FREQ_DEFAULT_GOV_SCHEDUTIL CPU_FREQ_GOV_POWERSAVE CPU_FREQ_GOV_CONSERVATIVE \
 DEVFREQ_GOV_PERFORMANCE DEVFREQ_GOV_POWERSAVE MQ_IOSCHED_DEADLINE MQ_IOSCHED_KYBER \
 IOSCHED_BFQ BFQ_GROUP_IOSCHED CPU_IDLE_GOV_MENU THERMAL_DEFAULT_GOV_STEP_WISE; do
 grep -Fxq "CONFIG_$symbol=y" "$after"
done
if [[ $fragment == */resources.config ]]; then
 grep -Fxq '# CONFIG_LRU_GEN_ENABLED is not set' "$after"
 grep -Fxq 'CONFIG_DEBUG_INFO_NONE=y' "$after"
fi
printf '%s\n' 'PASS: complete config retained outside exact manager capabilities and reviewed dependency values'
diff -u "$before" "$after" || [[ $? == 1 ]]

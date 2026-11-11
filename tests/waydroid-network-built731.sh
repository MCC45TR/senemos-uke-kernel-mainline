#!/usr/bin/env bash
# COPR-only effective configuration/object admission, not a runtime claim.
set -Eeuo pipefail
output=${1:?Built kernel output}
fragment=${2:?Required Android network settings}
mode=${3:-objects}
[[ $mode == objects || $mode == config-only ]]
while IFS= read -r setting; do
 [[ $setting == CONFIG_*=y ]] || continue
 grep -Fx "$setting" "$output/.config" || {
  printf 'Missing effective Android network prerequisite: %s\n' "$setting" >&2
  exit 1
 }
done < "$fragment"
[[ $mode != config-only ]] || exit 0
for object in net/ipv4/fib_rules.o net/ipv6/fib6_rules.o \
 net/ipv4/netfilter/iptable_filter.o net/ipv6/netfilter/ip6table_filter.o \
 net/netfilter/xt_owner.o net/netfilter/xt_mark.o net/netfilter/xt_bpf.o; do
 test -s "$output/$object"
done
printf 'Android policy routing/filtering: required built-in config and objects pass\n'

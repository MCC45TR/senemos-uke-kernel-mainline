#!/usr/bin/env bash
# COPR-only effective configuration/object admission, not a runtime claim.
set -Eeuo pipefail
output=${1:?Built kernel output}
fragment=${2:?Required Android network settings}
while IFS= read -r setting; do
 [[ $setting == CONFIG_*=y ]] || continue
 grep -Fx "$setting" "$output/.config"
done < "$fragment"
for object in net/ipv4/fib_rules.o net/ipv6/fib6_rules.o \
 net/ipv4/netfilter/iptable_filter.o net/ipv6/netfilter/ip6table_filter.o \
 net/netfilter/xt_owner.o net/netfilter/xt_mark.o net/netfilter/xt_bpf.o; do
 test -s "$output/$object"
done
printf 'Android policy routing/filtering: required built-in config and objects pass\n'

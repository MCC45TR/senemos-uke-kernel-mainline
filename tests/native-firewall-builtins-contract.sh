#!/usr/bin/env bash
# COPR fixtures: retain modular nftables and require actual built-in receipts.
set -Eeuo pipefail
guard=${1:?Firewall guard}
base=${2:?Original modular configuration}
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
mkdir -p "$stage/output/net"
bash "$guard" "$base"
sed -e 's/^CONFIG_NF_CONNTRACK=m$/CONFIG_NF_CONNTRACK=y/' \
 -e 's/^CONFIG_NF_NAT=m$/CONFIG_NF_NAT=y/' "$base" > "$stage/mixed.config"
for module in nf_tables nf_log_syslog nf_conntrack_netlink \
 nfnetlink_log nft_ct nft_log nft_limit nft_masq nft_redir nft_nat \
 nft_reject nft_reject_ipv4 nft_reject_ipv6 nft_reject_inet \
 nft_fib_ipv4 nft_fib_ipv6 nft_fib_inet nft_compat; do
 touch "$stage/output/net/$module.ko"
done
printf 'kernel/net/netfilter/nf_conntrack.ko\nkernel/net/netfilter/nf_nat.ko\n' > "$stage/output/modules.builtin"
bash "$guard" "$stage/mixed.config" "$stage/output"
: > "$stage/output/modules.builtin"
if bash "$guard" "$stage/mixed.config" "$stage/output"; then exit 1; fi
printf 'kernel/net/netfilter/nf_conntrack.ko\nkernel/net/netfilter/nf_nat.ko\n' > "$stage/output/modules.builtin"
unlink "$stage/output/net/nft_ct.ko"
if bash "$guard" "$stage/mixed.config" "$stage/output"; then exit 1; fi
sed 's/^CONFIG_NF_CONNTRACK=y$/# CONFIG_NF_CONNTRACK is not set/' \
 "$stage/mixed.config" > "$stage/missing.config"
if bash "$guard" "$stage/missing.config"; then exit 1; fi
printf 'Modular/built-in firewall admission and missing-provider refusals pass\n'

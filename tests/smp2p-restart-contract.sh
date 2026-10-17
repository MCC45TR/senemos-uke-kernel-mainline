#!/usr/bin/env bash
set -Eeuo pipefail
source=${1:?Pass prepared kernel source}/drivers/soc/qcom/smp2p.c
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
cat > "$work/test.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#define BIT(n) (1U << (n))
#define SMP2P_FLAGS_RESTART_DONE_BIT 0
struct smp2p_smem_item { uint32_t flags; };
struct smp2p_entry { uint32_t *value, last_value; };
struct entry_list { struct smp2p_entry *entries; unsigned count; };
struct qcom_smp2p {
    struct smp2p_smem_item *in;
    bool ssr_ack_enabled, ssr_ack;
    struct entry_list inbound;
};
#define list_for_each_entry(entry, head, member) \
    for (unsigned i=0; i<(head)->count && ((entry)=&(head)->entries[i],1); ++i)
C
awk '/^static bool qcom_smp2p_check_ssr\(/ {emit=1} emit {print} emit && /^}/ {exit}' "$source" >> "$work/test.c"
cat >> "$work/test.c" <<'C'
int main(void) {
    uint32_t value=6;
    struct smp2p_entry entries[]={{&value,6},{0,17}};
    struct smp2p_smem_item in={0};
    struct qcom_smp2p smp2p={&in,true,false,{entries,2}};
    /* Repeated updates of another entry cannot replay ready/handover. */
    for (unsigned i=0; i<10; ++i) {
        assert(!qcom_smp2p_check_ssr(&smp2p));
        assert((value ^ entries[0].last_value)==0);
    }
    /* Both restart flag edges reset allocated entries before notification. */
    for (unsigned i=0; i<2; ++i) {
        in.flags=i ? 0 : BIT(SMP2P_FLAGS_RESTART_DONE_BIT);
        assert(qcom_smp2p_check_ssr(&smp2p));
        assert(entries[0].last_value==0 && entries[1].last_value==17);
        smp2p.ssr_ack=!smp2p.ssr_ack;
        entries[0].last_value=value;
        assert(!qcom_smp2p_check_ssr(&smp2p));
        assert(entries[0].last_value==value);
    }
    smp2p.ssr_ack_enabled=false;
    in.flags=BIT(SMP2P_FLAGS_RESTART_DONE_BIT);
    assert(!qcom_smp2p_check_ssr(&smp2p));
    assert(entries[0].last_value==value);
}
C
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror "$work/test.c" -o "$work/test"
"$work/test"
printf '%s\n' 'SMP2P ordinary edges, both restart transitions and absent entries passed'

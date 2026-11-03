#!/usr/bin/env bash
# Exercise the actual topology parser in a COPR source worker; no DSP access.
set -Eeuo pipefail
kernel=${1:?Pass prepared kernel source}
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/linux"
cat > "$work/linux/types.h" <<'C'
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <endian.h>
typedef uint32_t u32;
typedef uint32_t __le32;
#define cpu_to_le32(x) htole32(x)
#define le32_to_cpu(x) le32toh(x)
C
printf '#include_next <linux/errno.h>\n' > "$work/linux/errno.h"
printf '#include <string.h>\n' > "$work/linux/string.h"
cat > "$work/parser.c" <<'C'
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "audioreach-control-links.h"
#define BIT(n) (1U << (n))
#define GENMASK(h,l) ((UINT32_MAX >> (31 - (h))) & (UINT32_MAX << (l)))
#define AR_MAX_MOD_LINKS 8
#define ERR_PTR(e) ((void *)(intptr_t)(e))
#define IS_ERR(p) ((uintptr_t)(p) >= (uintptr_t)-4095)
#define PTR_ERR(p) ((intptr_t)(p))
#define dev_err(...) ((void)0)
struct q6apm { void *dev; };
struct audioreach_container { int unused; };
struct snd_soc_dapm_widget { int unused; };
struct snd_soc_tplg_vendor_value_elem { u32 token, value; };
struct snd_soc_tplg_vendor_array {
    u32 num_elems;
    struct snd_soc_tplg_vendor_value_elem value[32];
};
struct snd_soc_tplg_private { struct snd_soc_tplg_vendor_array *array; };
struct audioreach_module {
    u32 module_id, max_ip_port, max_op_port, src_mod_inst_id, num_connections;
    u32 src_mod_op_port_id[8], dst_mod_inst_id[8], dst_mod_ip_port_id[8];
    struct audioreach_ctrl_link ctrl_link;
};
static struct audioreach_module module;
static struct audioreach_module *audioreach_tplg_alloc_module(struct q6apm *a,
        struct audioreach_container *c, struct snd_soc_dapm_widget *w, int id, bool *found)
{
    (void)a; (void)c; (void)w; (void)id;
    *found = false;
    memset(&module, 0, sizeof(module));
    return &module;
}
static const struct snd_soc_tplg_vendor_array *audioreach_get_module_array(
        const struct snd_soc_tplg_private *p) { return p->array; }
C
grep '^#define AR_TKN_' "$kernel/include/uapi/sound/snd_ar_tokens.h" >> "$work/parser.c"
awk '/^static struct audioreach_module \*audioreach_parse_common_tokens\(/ { emit=1 }
     emit { print } emit && /^}/ { exit }' \
    "$kernel/sound/soc/qcom/qdsp6/topology.c" >> "$work/parser.c"
grep -Fq 'ctrl_seen' "$work/parser.c"
cat >> "$work/parser.c" <<'C'
static void add(struct snd_soc_tplg_vendor_array *a, u32 token, u32 value)
{
    a->value[a->num_elems++] = (struct snd_soc_tplg_vendor_value_elem){token, value};
}
static struct snd_soc_tplg_vendor_array legacy(void)
{
    struct snd_soc_tplg_vendor_array a = {0};
    add(&a, AR_TKN_U32_MODULE_ID, 0x10001111);
    add(&a, AR_TKN_U32_MODULE_INSTANCE_ID, 0x4040);
    add(&a, AR_TKN_U32_MODULE_MAX_IP_PORTS, 1);
    add(&a, AR_TKN_U32_MODULE_MAX_OP_PORTS, 1);
    return a;
}
static struct audioreach_module *parse(struct snd_soc_tplg_vendor_array *a)
{
    struct snd_soc_tplg_private p = {.array = a};
    return audioreach_parse_common_tokens(NULL, NULL, &p, NULL);
}
int main(void)
{
    struct snd_soc_tplg_vendor_array a = legacy(), good;
    struct audioreach_module *m = parse(&a);
    assert(!IS_ERR(m) && !m->ctrl_link.first_instance);
    add(&a, AR_TKN_U32_MODULE_CTRL_PORT_ID, 0x80000000);
    add(&a, AR_TKN_U32_MODULE_CTRL_PEER_INSTANCE_ID, 0x49fd);
    add(&a, AR_TKN_U32_MODULE_CTRL_PEER_PORT_ID, 0x80000000);
    add(&a, AR_TKN_U32_MODULE_CTRL_INTENT_ID, 0x08001231);
    add(&a, AR_TKN_U32_MODULE_CTRL_HEAP_ID, 1);
    good = a;
    m = parse(&a);
    assert(!IS_ERR(m) && m->ctrl_link.first_instance == 0x4040 &&
           m->ctrl_link.first_port == 0x80000000 &&
           m->ctrl_link.second_instance == 0x49fd &&
           m->ctrl_link.second_port == 0x80000000 &&
           m->ctrl_link.intent == 0x08001231 && m->ctrl_link.heap == 1);
    for (unsigned int i = 4; i < good.num_elems; i++) {
        a = good;
        a.value[i].value = 0;
        assert(IS_ERR(parse(&a)) && PTR_ERR(parse(&a)) == -EINVAL);
        a = good;
        memmove(&a.value[i], &a.value[i+1], (a.num_elems - i - 1) * sizeof(a.value[0]));
        a.num_elems--;
        assert(IS_ERR(parse(&a)));
        a = good;
        add(&a, good.value[i].token, good.value[i].value);
        assert(IS_ERR(parse(&a)));
    }
    a = good;
    a.value[a.num_elems - 1].value = 4;
    assert(IS_ERR(parse(&a)));
    puts("Actual AudioReach topology parser: legacy, valid, partial, zero and duplicate IMCL tokens passed.");
    return 0;
}
C
${CC:-cc} -std=gnu11 -Wall -Wextra -Werror -fsanitize=address,undefined \
    -I"$work" -I"$root/src/audio" "$work/parser.c" -o "$work/check"
"$work/check"

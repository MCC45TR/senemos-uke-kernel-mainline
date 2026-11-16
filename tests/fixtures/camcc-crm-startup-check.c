/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual startup decoder against an independent exact OEM register model. */
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
typedef uint32_t u32;
typedef uint64_t u64;
#include "camcc-sm7675-crm-startup.h"

struct model {
    u32 words[8][3];
    unsigned reads, fail_at, change_at, status_at;
    int error;
};
static struct cam_cc_crm_lut tables[8];
static const struct cam_cc_crm_caps caps = { 1, 8, 1, 1 };

static int observe(void *context, u32 offset, u32 *out)
{
    struct model *m = context;
    static const u32 resources[8] = {0,1,2,3,4,6,7,0};
    unsigned client, state;
    ++m->reads;
    assert(m->reads <= 72);
    if (m->reads == m->fail_at) return m->error;
    for (client = 0; client < 8; ++client) {
        u32 base = client == 7 ? 0x1400U : 0x1060U + 4 * resources[client];
        if (offset == base + 0x100) {
            *out = m->reads == m->status_at ? 1 : 0;
            return 0;
        }
        for (state = 0; state < 3; ++state)
            if (offset == base + state * 0x40) {
                *out = m->words[client][state];
                if (m->reads == m->change_at) *out ^= 1;
                return 0;
            }
    }
    assert(!"Read outside the eight owned AP0 voters");
    return -EINVAL;
}

static struct model setup(void)
{
    struct model m = { .error = -EREMOTEIO };
    unsigned client, state, level;
    for (client = 0; client < 8; ++client) {
        tables[client] = (struct cam_cc_crm_lut) { .count = 3 };
        for (level = 0; level < 3; ++level)
            tables[client].rates[level].hz = (level + 1) * 100000001ULL;
        for (state = 0; state < 3; ++state)
            m.words[client][state] = client == 7 ?
                0xe0000000U | state * 100U : state;
    }
    return m;
}

static void rejected(struct model *m, int expected, unsigned reads)
{
    struct cam_cc_crm_startup out, before;
    memset(&out, 0xa5, sizeof(out)); before = out;
    assert(cam_cc_crm_startup_read(&caps,tables,0x2000,observe,m,&out) == expected);
    assert(m->reads == reads && !memcmp(&out,&before,sizeof(out)));
}

int main(void)
{
    struct cam_cc_crm_startup out;
    struct model m = setup();
    u64 rate;
    unsigned i, client, state;
    assert(!cam_cc_crm_startup_read(&caps,tables,0x2000,observe,&m,&out));
    assert(m.reads == 72);
    for (client = 0; client < 8; ++client)
        for (state = 0; state < 3; ++state) {
            assert(out.words[client][state] == m.words[client][state]);
            assert(out.rates[client][state] == state * 100000001ULL);
        }
    for (i = 1; i <= 72; ++i) {
        m=setup();m.fail_at=i;rejected(&m,-EREMOTEIO,i);
        m=setup();m.fail_at=i;m.error=1;rejected(&m,-EIO,i);
    }
    /* Every second-pass vote change and every pending-status observation. */
    for (client = 0; client < 8; ++client) {
        for (state = 0; state < 3; ++state) {
            i = 34 + client * 4 + state;
            m=setup();m.change_at=i;rejected(&m,-EAGAIN,i);
        }
        for (i=0;i<3;++i) {
            unsigned read = i == 2 ? 65 + client : 1 + i * 32 + client * 4;
            m=setup();m.status_at=read;rejected(&m,-EUCLEAN,read);
        }
    }
    m=setup();tables[7].rates[2].hz=tables[7].rates[1].hz;rejected(&m,-EINVAL,0);
    m=setup();tables[7].count=0;rejected(&m,-EINVAL,0);
    m=setup();assert(cam_cc_crm_startup_read(&caps,tables,0x1400,observe,&m,&out)==-ERANGE && !m.reads);
    assert(cam_cc_crm_startup_read(NULL,tables,0x2000,observe,&m,&out)==-EINVAL && !m.reads);
    assert(cam_cc_crm_startup_read(&caps,NULL,0x2000,observe,&m,&out)==-EINVAL && !m.reads);
    assert(cam_cc_crm_startup_read(&caps,tables,0x2000,NULL,&m,&out)==-EINVAL && !m.reads);
    assert(cam_cc_crm_startup_read(&caps,tables,0x2000,observe,&m,NULL)==-EINVAL && !m.reads);
    for (i=0;i<32;++i) {
        rate=99;
        if(i<3) continue;
        assert(cam_cc_crm_startup_rate(&tables[0],CAM_CC_CRM_PERF,1U<<i,&rate)==-EOPNOTSUPP && rate==99);
    }
    rate=99;assert(cam_cc_crm_startup_rate(&tables[0],CAM_CC_CRM_PERF,4,&rate)==-ERANGE && rate==99);
    assert(cam_cc_crm_startup_rate(&tables[0],CAM_CC_CRM_PERF,1,NULL)==-EINVAL);
    assert(cam_cc_crm_startup_rate(&tables[7],CAM_CC_CRM_BW,100,&rate)==-EUCLEAN && rate==99);
    assert(cam_cc_crm_startup_rate(&tables[7],CAM_CC_CRM_BW,0xe0000063,&rate)==-ERANGE && rate==99);
    assert(cam_cc_crm_startup_rate(&tables[7],CAM_CC_CRM_BW,0xe000012d,&rate)==-ERANGE && rate==99);
    for(i=14;i<29;++i) {
        assert(cam_cc_crm_startup_rate(&tables[7],CAM_CC_CRM_BW,1U<<i,&rate)==-EOPNOTSUPP && rate==99);
    }
    assert(cam_cc_crm_startup_rate(&tables[0],2,1,&rate)==-EOPNOTSUPP && rate==99);
    puts("PASS: camera startup snapshot: all72 read failures,24 changes,24 status failures; no writes or vote adoption");
}

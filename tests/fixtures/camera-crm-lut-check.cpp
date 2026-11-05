// SPDX-License-Identifier: GPL-2.0-only
#include <cassert>
#include <cerrno>
#include <climits>
#include <cstdio>
#include <cstring>
#include "camcc-sm7675-crm-lut.h"
#include "oem-crmc-registers.h"

extern "C" int oem_lut_read_error(int, unsigned *, unsigned long *);
static unsigned checks;
#define CHECK(value) do { ++checks; assert(value); } while (0)

struct rom {
    u32 cfg[7], pll[7];
    unsigned reads, parents, fail_read, fail_parent;
    int error;
    u64 parent_override;
};
static int read_rom(void *context, u32 offset, u32 *value)
{
    auto &r = *static_cast<rom *>(context);
    unsigned slot = r.reads / 2;
    CHECK(slot < 7);
    CHECK(offset == (r.reads % 2 ? 0x138U : 0x110U) + 4 * 0x200 + (slot + 1) * 4);
    ++r.reads;
    if (r.fail_read == r.reads) return r.error;
    *value = r.reads % 2 ? r.cfg[slot] : r.pll[slot];
    return 0;
}
static int parent_rate(void *context, u32 source, u32 l, u32 alpha, u64 *rate)
{
    auto &r = *static_cast<rom *>(context);
    CHECK(source == 2);
    ++r.parents;
    if (r.fail_parent == r.parents) return r.error;
    *rate = r.parent_override ? r.parent_override :
            19200000ULL * l + (19200000ULL * alpha) / 65536;
    return 0;
}
static rom normal_rom()
{
    rom r{};
    r.error = -EREMOTEIO;
    for (unsigned i = 0; i < 7; ++i) {
        r.cfg[i] = (2U << 8) | 1;
        r.pll[i] = i + 1;
    }
    return r;
}
static bool same_table(const cam_cc_crm_lut &left, const cam_cc_crm_lut &right)
{
    if (left.count != right.count) return false;
    for (unsigned i = 0; i < 7; ++i)
        if (left.rates[i].hz != right.rates[i].hz ||
            left.rates[i].source != right.rates[i].source) return false;
    return true;
}
int main(int argc, char **argv)
{
    if (argc == 2 && std::strcmp(argv[1], "--oem-negative") == 0) {
        unsigned reads = 0; unsigned long rate = 0;
        int rc = oem_lut_read_error(-EIO, &reads, &rate);
        assert(rc == -EIO && reads == 1);
        return 0;
    }
    for (u32 vcd = 0; vcd < 10; ++vcd)
        for (u32 level = 0; level < 9; ++level) {
            u32 cfg = 17, pll = 19;
            bool valid = vcd < 9 && vcd != 5 && level && level < 8;
            int rc = cam_cc_crm_lut_offsets(vcd, level, 0x2000, &cfg, &pll);
            CHECK(rc == (valid ? 0 : -EINVAL));
            if (valid) {
                CHECK(cfg == CLK_RCG_CRMC_CFG_RCGR(vcd, level));
                CHECK(pll == CLK_RCG_CRMC_PERF_LEVEL_PLL_L_VAL_LUT(vcd, level));
                CHECK(cam_cc_crm_lut_offsets(vcd, level, pll, &cfg, &pll) == -ERANGE);
            } else {
                CHECK(cfg == 17 && pll == 19);
            }
        }
    cam_cc_crm_lut table{};
    rom r = normal_rom();
    CHECK(cam_cc_crm_lut_load(4, 0x2000, read_rom, parent_rate, &r, &table) == 0);
    CHECK(table.count == 7 && r.reads == 14 && r.parents == 7);
    for (unsigned i = 0; i < 7; ++i) {
        CHECK(table.rates[i].hz == (i + 1) * 19200000ULL);
        CHECK(table.rates[i].source == 2);
    }
    auto original = table;
    for (unsigned failure = 1; failure <= 14; ++failure) {
        r = normal_rom(); r.fail_read = failure;
        CHECK(cam_cc_crm_lut_load(4, 0x2000, read_rom, parent_rate, &r, &table) == -EREMOTEIO);
        CHECK(r.reads == failure && r.parents == (failure - 1) / 2);
        CHECK(same_table(table, original));
    }
    for (unsigned failure = 1; failure <= 7; ++failure) {
        r = normal_rom(); r.fail_parent = failure;
        CHECK(cam_cc_crm_lut_load(4, 0x2000, read_rom, parent_rate, &r, &table) == -EREMOTEIO);
        CHECK(r.reads == 2 * failure && r.parents == failure);
        CHECK(same_table(table, original));
    }
    r = normal_rom(); r.fail_read = 1; r.error = 1;
    CHECK(cam_cc_crm_lut_load(4, 0x2000, read_rom, parent_rate, &r, &table) == -EIO);
    r = normal_rom(); r.fail_parent = 1; r.error = 1;
    CHECK(cam_cc_crm_lut_load(4, 0x2000, read_rom, parent_rate, &r, &table) == -EIO);
    r = normal_rom(); r.cfg[0] |= 0x1000;
    CHECK(cam_cc_crm_lut_load(4, 0x2000, read_rom, parent_rate, &r, &table) == -EOPNOTSUPP);
    CHECK(r.parents == 0 && same_table(table, original));
    r = normal_rom(); r.pll[0] = 0;
    CHECK(cam_cc_crm_lut_load(4, 0x2000, read_rom, parent_rate, &r, &table) == -EINVAL);
    r = normal_rom(); r.parent_override = ~u64(0);
    CHECK(cam_cc_crm_lut_load(4, 0x2000, read_rom, parent_rate, &r, &table) == -ERANGE);
    for (unsigned hid = 0; hid < 32; ++hid) {
        r = normal_rom();
        for (unsigned i = 0; i < 7; ++i) r.cfg[i] = (2U << 8) | hid;
        CHECK(cam_cc_crm_lut_load(4, 0x2000, read_rom, parent_rate, &r, &table) == 0);
        CHECK(table.rates[0].hz == (hid ? 38400000ULL / (hid + 1) : 19200000ULL));
    }
    r = normal_rom(); r.pll[0] |= 0x80000000U;
    CHECK(cam_cc_crm_lut_load(4, 0x2000, read_rom, parent_rate, &r, &table) == 0);
    CHECK(table.rates[0].hz == 28800000);
    for (unsigned sentinel = 1; sentinel < 7; ++sentinel) {
        r = normal_rom(); r.pll[sentinel] = r.pll[sentinel - 1];
        CHECK(cam_cc_crm_lut_load(4, 0x2000, read_rom, parent_rate, &r, &table) == 0);
        CHECK(table.count == sentinel && r.reads == 2 * (sentinel + 1));
    }
    r = normal_rom();
    CHECK(cam_cc_crm_lut_load(5, 0x2000, read_rom, parent_rate, &r, &table) == -EINVAL);
    CHECK(r.reads == 0);
    CHECK(cam_cc_crm_lut_load(4, 0x954, read_rom, parent_rate, &r, &table) == -ERANGE);
    CHECK(r.reads == 0);
    table = original;
    for (u64 requested = 0; requested <= 140000000; requested += 1000000) {
        u32 level = 99; u64 rounded = 99;
        int rc = cam_cc_crm_lut_pick(&table, requested, &level, &rounded);
        if (requested > 134400000) {
            CHECK(rc == -ERANGE && level == 99 && rounded == 99);
        } else {
            u32 expected = static_cast<u32>((requested + 19199999) / 19200000);
            CHECK(rc == 0 && level == expected && rounded == expected * 19200000ULL);
        }
    }
    u32 level = 99; u64 rounded = 99;
    table.rates[1].hz = table.rates[0].hz;
    CHECK(cam_cc_crm_lut_pick(&table, 1, &level, &rounded) == -EINVAL);
    CHECK(level == 99 && rounded == 99);
    unsigned reads = 0; unsigned long rate = 0;
    CHECK(oem_lut_read_error(-EIO, &reads, &rate) == 0 && reads == 2 && rate == 19200000);
    std::printf("CRM LUT source contract: %u checks; OEM offsets, all14 read failures,7 parent failures,HID/alpha/sentinel/off/range controls passed\n", checks);
}

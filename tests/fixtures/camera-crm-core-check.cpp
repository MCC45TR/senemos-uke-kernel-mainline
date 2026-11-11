// SPDX-License-Identifier: GPL-2.0-only
#include <cassert>
#include <cerrno>
#include <climits>
#include <cstdio>
#include <cstring>
#include <initializer_list>
#include "camcc-sm7675-crm-core.h"

extern "C" u32 oem_offset(unsigned, unsigned, unsigned, u32);
extern "C" u32 oem_bw_word(u32);
extern "C" int oem_vote(int, int, int, unsigned *);

static unsigned checks;
#define CHECK(expr) do { ++checks; assert(expr); } while (0)

struct transport {
    unsigned calls;
    int error[3];
    cam_cc_crm_packet packets[3];
};

static int send_packet(void *context, const cam_cc_crm_packet *packet)
{
    auto &bus = *static_cast<transport *>(context);
    CHECK(bus.calls < 3);
    CHECK(packet->state == bus.calls);
    CHECK(packet->wait_for_ack == (bus.calls == 0));
    bus.packets[bus.calls] = *packet;
    return bus.error[bus.calls++];
}

int main(int argc, char **argv)
{
    if (argc == 2 && std::strcmp(argv[1], "--oem-negative") == 0) {
        unsigned calls = 0;
        int result = oem_vote(-EIO, 0, 0, &calls);
        // This assertion must fail in the independently extracted OEM function.
        assert(result == -EIO && calls == 1);
        return 0;
    }
    cam_cc_crm_caps caps{};
    CHECK(cam_cc_crm_decode_caps((1U << 20) | (9U << 8) | (2U << 24),
                                3U << 26, &caps) == 0);
    CHECK(caps.sw_drvs == 1 && caps.perf_vcds == 9 &&
          caps.bw_vcds == 2 && caps.bw_nodes == 3);
    const auto admitted = caps;
    // All field values: rejected capability decodes leave output unchanged.
    for (u32 sw = 0; sw < 16; ++sw)
        for (u32 perf = 0; perf < 16; ++perf)
            for (u32 bw = 0; bw < 16; ++bw)
                for (u32 nodes = 0; nodes < 32; ++nodes) {
                    caps = admitted;
                    const auto before = caps;
                    bool valid = sw && perf >= 8 && bw && nodes && nodes <= 16;
                    int rc = cam_cc_crm_decode_caps((sw << 20) | (perf << 8) |
                                                  (bw << 24), nodes << 26, &caps);
                    CHECK(rc == (valid ? 0 : -EINVAL));
                    if (!valid)
                        CHECK(std::memcmp(&caps, &before, sizeof(caps)) == 0);
                    else
                        CHECK(caps.sw_drvs == sw && caps.perf_vcds == perf &&
                              caps.bw_vcds == bw && caps.bw_nodes == nodes);
                }
    caps = admitted;
    CHECK(cam_cc_crm_decode_caps(0, 0, nullptr) == -EINVAL);
    CHECK(!cam_cc_crm_caps_valid(nullptr));
    // Compare native offsets with actual OEM register arrays + crm_get_offset.
    for (unsigned kind = 0; kind < 2; ++kind)
        for (u32 resource = 0; resource < 10; ++resource)
            for (unsigned reg = 0; reg < 4; ++reg)
                for (unsigned state = 0; state < 3; ++state) {
                    u32 offset = 0xfeedface;
                    bool owned = kind == 0 ? resource < 8 && resource != 5 : resource == 0;
                    bool valid = owned && (reg == 0 || state == 0);
                    int rc = cam_cc_crm_offset(&caps, kind, resource, reg, state,
                                              0x2000, &offset);
                    CHECK(rc == (valid ? 0 : -EINVAL));
                    if (valid) {
                        CHECK(offset == oem_offset(kind, reg, state, resource));
                        CHECK((offset & 3) == 0 && offset < 0x2000);
                        u32 untouched = 0xabcdef;
                        CHECK(cam_cc_crm_offset(&caps, kind, resource, reg, state,
                                                offset, &untouched) == -ERANGE);
                        CHECK(untouched == 0xabcdef);
                        CHECK(cam_cc_crm_offset(&caps, kind, resource, reg, state,
                                                offset + 4, &untouched) == 0);
                    } else {
                        CHECK(offset == 0xfeedface);
                    }
                }
    for (u32 span : {0U, 1U, 3U, 0x1fffU, 0x2004U, UINT_MAX}) {
        u32 offset = 99;
        CHECK(cam_cc_crm_offset(&caps, 0, 0, 0, 0, span, &offset) == -ERANGE);
        CHECK(offset == 99);
    }
    u32 offset = 99;
    CHECK(cam_cc_crm_offset(&caps, UINT_MAX, 0, 0, 0, 0x2000, &offset) == -EINVAL);
    CHECK(cam_cc_crm_offset(&caps, 0, UINT_MAX, 0, 0, 0x2000, &offset) == -EINVAL);
    CHECK(cam_cc_crm_offset(&caps, 0, 0, UINT_MAX, 0, 0x2000, &offset) == -EINVAL);
    CHECK(cam_cc_crm_offset(&caps, 0, 0, 0, UINT_MAX, 0x2000, &offset) == -EINVAL);
    CHECK(cam_cc_crm_offset(&caps, 0, 0, 0, 0, 0x2000, nullptr) == -EINVAL);
    cam_cc_crm_packet packets[3]{};
    for (unsigned kind = 0; kind < 2; ++kind) {
        const u32 max = kind == 0 ? 7 : 0x3fff;
        for (u32 value = 0; value <= max; ++value) {
            CHECK(cam_cc_crm_plan(&caps, kind, 0, value, 0x2000, packets) == 0);
            for (unsigned state = 0; state < 3; ++state) {
                CHECK(packets[state].data == (kind == 0 ? value : oem_bw_word(value)));
                CHECK(packets[state].offset == oem_offset(kind, 0, state, 0));
                CHECK(packets[state].wait_for_ack == (state == 0));
            }
        }
        cam_cc_crm_packet previous[3];
        for (unsigned state = 0; state < 3; ++state)
            previous[state] = packets[state];
        CHECK(cam_cc_crm_plan(&caps, kind, 0, max + 1, 0x2000, packets) == -ERANGE);
        for (unsigned state = 0; state < 3; ++state) {
            CHECK(previous[state].offset == packets[state].offset);
            CHECK(previous[state].data == packets[state].data);
            CHECK(previous[state].state == packets[state].state);
            CHECK(previous[state].wait_for_ack == packets[state].wait_for_ack);
        }
    }
    CHECK(cam_cc_crm_plan(&caps, 0, 0, 0, 0x2000, nullptr) == -EINVAL);
    // Even if ACTIVE fits, a truncated WAKE bank rejects before any callback.
    transport bus{};
    cam_cc_crm_vote_state vote{false, true, 2};
    CHECK(cam_cc_crm_send_vote(&caps, 0, 0, 3, 0x10e0, &vote,
                              send_packet, &bus) == -ERANGE);
    CHECK(bus.calls == 0 && !vote.poisoned && vote.confirmed_valid &&
          vote.confirmed_value == 2);
    // Every combination of success, I/O error, timeout and invalid positive rc.
    const int errors[] = {0, -EIO, -ETIMEDOUT, 1};
    for (int active : errors)
        for (int sleep : errors)
            for (int wake : errors) {
                bus = {};
                bus.error[0] = active; bus.error[1] = sleep; bus.error[2] = wake;
                vote = {false, true, 2};
                int first = active ? active : sleep ? sleep : wake;
                unsigned expected_calls = active ? 1 : sleep ? 2 : 3;
                int expected_rc = first > 0 ? -EIO : first;
                CHECK(cam_cc_crm_send_vote(&caps, 0, 0, 3, 0x2000, &vote,
                                          send_packet, &bus) == expected_rc);
                CHECK(bus.calls == expected_calls);
                CHECK(vote.poisoned == bool(first));
                CHECK(vote.confirmed_valid == !bool(first));
                CHECK(vote.confirmed_value == (first ? 2U : 3U));
                if (first) {
                    unsigned before = bus.calls;
                    CHECK(cam_cc_crm_send_vote(&caps, 0, 0, 4, 0x2000, &vote,
                                              send_packet, &bus) == -EIO);
                    CHECK(bus.calls == before); // No retry after ambiguous/partial completion.
                }
            }
    unsigned calls = 0;
    CHECK(oem_vote(-EIO, 0, 0, &calls) == 0 && calls == 3);
    CHECK(oem_vote(0, -ETIMEDOUT, 0, &calls) == 0 && calls == 3);
    CHECK(oem_vote(0, 0, -EIO, &calls) == -EIO && calls == 3);
    CHECK(oem_vote(0, 0, 0, &calls) == 0 && calls == 3);
    std::printf("CRM source contract: %u checks; OEM offset/BCM parity, all capability fields, first-error/poison controls passed\n", checks);
}

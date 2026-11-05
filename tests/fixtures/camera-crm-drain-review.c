/* SPDX-License-Identifier: GPL-2.0-only */
/* Include the retained real-body transport fixture; no hardware access. */
#include "retained-fixture.c"

static bool inject_after_drain;
static unsigned late_status_offset;

static void checking_synchronize_irq(unsigned irq)
{
    unsigned before;

    synchronize_irq(irq);
    if (!inject_after_drain)
        return;
    inject_after_drain = false;
    memory[late_status_offset / 4] = 1;
    before = reads;
    /* A queued callback sees quiesced and deliberately performs no MMIO. */
    assert(registered_handler(121, registered_context) == IRQ_NONE);
    assert(reads == before);
}

int main(void)
{
    struct cam_cc_crm_transport transport;
    unsigned kind, resource, release, cases = 0, before;
    int result;

    retained_contract();
    for (kind = 0; kind < 2; kind++) {
        for (resource = 0; resource < 8; resource++) {
            if (kind == 0 ? !owned_perf(resource) : resource != 0)
                continue;
            for (release = 0; release < 2; release++) {
                reset_model(&transport);
                assert(initialize(&transport) == 0);
                late_status_offset = kind == 0 ? 0x1160 + resource * 4 : 0x1500;
                inject_after_drain = true;
                result = cam_cc_crm_transport_idle(&transport, release);
                assert(result == -EUCLEAN);
                assert(transport.fault == -EUCLEAN && transport.irq_owned);
                assert(!transport.ready && !freed && masks == 1);
                assert(memory[late_status_offset / 4] == 1 && !clears && !votes);
                before = reads;
                assert(cam_cc_crm_transport_idle(&transport, true) == -EUCLEAN);
                assert(cam_cc_crm_transport_resume(&transport) == -EUCLEAN);
                assert(reads == before && !freed);
                cases++;
            }
        }
    }
    printf("Actual CRM post-drain review: %u late owned-status cases retain fault/IRQ/mapping and refuse quiesce/release; original transport/lifecycle contract retained; synthetic only\n", cases);
    return 0;
}

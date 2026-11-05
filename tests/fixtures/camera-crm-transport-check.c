/* SPDX-License-Identifier: GPL-2.0-only */
/* Execute the actual transport header against a bounded MMIO/IRQ model. */
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef uint32_t u32;
typedef uint64_t u64;
#define __iomem
#define READ_ONCE(value) (value)
#define WRITE_ONCE(target, value) ((target) = (value))
typedef int irqreturn_t;
#define IRQ_NONE 0
#define IRQ_HANDLED 1
#define IRQF_TRIGGER_RISING 1
struct device { int unused; };
struct mutex { bool locked; };
typedef struct { bool locked; } spinlock_t;
struct completion { bool done; };
static u32 memory[0x2000 / 4];
static bool powered, registered;
static int request_error, enable_failure;
static unsigned access_calls, fail_access, writes, reads, enables, clears, votes, masks;
static unsigned hz, timeout_seen, mode, drains, freed;
static irqreturn_t (*registered_handler)(int, void *);
static void *registered_context;
static void (*before_lock_hook)(void);
static void spin_lock_init(spinlock_t *lock) { lock->locked = false; }
#define spin_lock_irqsave(lock, flags) do { (flags) = 0; assert(!(lock)->locked); (lock)->locked = true; } while (0)
#define spin_unlock_irqrestore(lock, flags) do { (void)(flags); assert((lock)->locked); (lock)->locked = false; } while (0)
static void mutex_init(struct mutex *lock) { lock->locked = false; }
static bool mutex_trylock(struct mutex *lock)
{
    if (before_lock_hook) {
        void (*hook)(void) = before_lock_hook;
        before_lock_hook = NULL;
        hook();
    }
    if (lock->locked) return false;
    lock->locked = true;
    return true;
}
static void mutex_unlock(struct mutex *lock) { assert(lock->locked); lock->locked = false; }
static void init_completion(struct completion *completion) { completion->done = false; }
static void reinit_completion(struct completion *completion) { completion->done = false; }
static void complete(struct completion *completion) { completion->done = true; }
static unsigned long msecs_to_jiffies(unsigned ms) { return (ms * hz + 999) / 1000; }
static unsigned long wait_for_completion_timeout(struct completion *, unsigned long);
static const char *dev_name(struct device *dev) { assert(dev); return "test-crm"; }
static int request_irq(int irq, irqreturn_t (*handler)(int, void *), unsigned flags,
                       const char *name, void *context)
{
    assert(irq == 121 && flags == IRQF_TRIGGER_RISING && name && context);
    if (request_error) return request_error;
    registered = true; registered_handler = handler; registered_context = context;
    return 0;
}
static void disable_irq_nosync(int irq) { assert(registered && irq == 121); masks++; }
static void synchronize_irq(unsigned irq);
static void free_irq(unsigned irq, void *context);
static unsigned register_offset(const volatile void *address)
{
    uintptr_t offset = (uintptr_t)address - (uintptr_t)memory;
    assert(powered && offset < sizeof(memory) && (offset & 3) == 0);
    return (unsigned)offset;
}
static u32 readl(const volatile void *address)
{
    unsigned offset = register_offset(address); reads++;
    return memory[offset / 4];
}
static bool owned_perf(unsigned resource) { return resource < 8 && resource != 5; }
static void writel(u32 value, volatile void *address)
{
    unsigned offset = register_offset(address), resource, state;
    bool known = false;
    writes++;
    for (resource = 0; resource < 8; resource++) {
        if (!owned_perf(resource)) continue;
        if (offset == 0x11e0 + resource * 4 || offset == 0x1580) {
            assert(registered && value <= 1);
            if ((int)enables++ != enable_failure) memory[offset / 4] = value;
            return;
        }
        if (offset == 0x11a0 + resource * 4) {
            assert(value == 1); clears++;
            memory[(0x1160 + resource * 4) / 4] &= ~1U;
            return;
        }
        for (state = 0; state < 3; state++) {
            if (offset == 0x1060 + state * 0x40 + resource * 4) {
                assert(value <= 7); known = true;
            }
        }
    }
    if (offset == 0x1540) {
        assert(value == 1); clears++; memory[0x1500 / 4] &= ~1U; return;
    }
    for (state = 0; state < 3; state++) {
        if (offset == 0x1400 + state * 0x40) {
            assert((value & ~0x3fffU) == 0xe0000000U); known = true;
        }
    }
    assert(known); votes++; memory[offset / 4] = value;
}

#include "crm-transport.h"

static void synchronize_irq(unsigned irq)
{
    struct cam_cc_crm_transport *t = registered_context;
    assert(registered && irq == 121 && !t->lock.locked && t->quiesced);
    assert(!t->ready && !t->pending);
    drains++;
}
static void free_irq(unsigned irq, void *context)
{
    struct cam_cc_crm_transport *t = context;
    assert(registered && irq == 121 && context == registered_context && drains);
    assert(!t->lock.locked && !t->irq_owned && t->quiesced && !t->fault);
    registered = false; freed++;
}

static int access_power(void *context)
{
    assert(context == memory); access_calls++;
    if (!powered || (fail_access && access_calls == fail_access)) return -EHOSTDOWN;
    return 0;
}
static unsigned long wait_for_completion_timeout(struct completion *completion,
                                                  unsigned long timeout)
{
    struct cam_cc_crm_transport *t = registered_context;
    unsigned status = t->pending_kind == 0 ? 0x1160 + t->pending_resource * 4 : 0x1500;
    unsigned before;
    timeout_seen = (unsigned)timeout;
    assert(timeout == 5 * hz && !t->lock.locked && t->pending);
    switch (mode) {
    case 1: return 0; /* no completion */
    case 2: status = 0x1164; break; /* wrong owned resource */
    case 4: memory[status / 4] = 3; break; /* undocumented status bits */
    case 5: powered = false; break;
    case 7: return 1; /* unrelated/spurious completion must not confirm pending */
    case 8: /* contention cannot queue or write */
        before = writes;
        assert(cam_cc_crm_transport_vote(t, 0, 1, 4) == -EBUSY);
        assert(writes == before); break;
    }
    if (mode != 4 && mode != 5) memory[status / 4] = 1;
    assert(registered_handler(121, t) == IRQ_HANDLED);
    if (mode == 3) { /* duplicate completion before waiter resumes */
        memory[status / 4] = 1;
        assert(registered_handler(121, t) == IRQ_HANDLED);
    }
    if (mode == 6) return 0; /* IRQ wins the lock after the timeout expired */
    assert(completion->done);
    return 1;
}
static void reset_model(struct cam_cc_crm_transport *t)
{
    memset(t, 0, sizeof(*t)); memset(memory, 0, sizeof(memory));
    powered = true; registered = false; request_error = 0; enable_failure = -1;
    access_calls = fail_access = writes = reads = enables = clears = votes = masks = 0;
    mode = 0; hz = 250; timeout_seen = 0;
    drains = freed = 0;
    before_lock_hook = NULL;
    memory[0] = 0x10200;
    memory[1] = (1U << 20) | (9U << 8) | (2U << 24);
    memory[2] = 3U << 26; memory[3] = 1;
}
static int initialize(struct cam_cc_crm_transport *t)
{
    static struct device device;
    return cam_cc_crm_transport_init(t, &device, memory, 121, access_power, memory);
}
static void release_before_lock(void)
{
    assert(cam_cc_crm_transport_idle(registered_context, true) == 0);
}

int main(void)
{
    struct cam_cc_crm_transport t;
    unsigned kind, resource, test_hz, scenario, before, i;
    int expected;
    reset_model(&t);
    assert(msecs_to_jiffies(5000) == 1250);
    assert(cam_cc_crm_transport_vote(&t, 0, 0, 1) == -ENODEV && writes == 0);
    assert(cam_cc_crm_transport_irq(121, NULL) == IRQ_NONE);
    for (kind = 0; kind < 2; kind++) {
        for (resource = 0; resource < 8; resource++) {
            if (kind == 0 ? !owned_perf(resource) : resource != 0) continue;
            for (test_hz = 0; test_hz < 3; test_hz++) {
                reset_model(&t); assert(initialize(&t) == 0);
                assert(t.ready && t.irq_owned && !t.fault && enables == 8);
                hz = (unsigned[]){100, 250, 1000}[test_hz];
                assert(cam_cc_crm_transport_vote(&t, kind, resource, 3) == 0);
                assert(votes == 3 && clears == 1 && timeout_seen == 5 * hz);
                assert(t.votes[kind][resource].confirmed_valid &&
                       t.votes[kind][resource].confirmed_value == 3);
                assert(!t.pending && !t.fault && masks == 0 && memory[3] == 1);
            }
        }
    }
    for (scenario = 1; scenario <= 8; scenario++) {
        reset_model(&t); assert(initialize(&t) == 0); mode = scenario;
        expected = scenario == 1 || scenario == 6 ? -ETIMEDOUT :
                   scenario == 5 ? -EHOSTDOWN : scenario == 8 ? 0 : -EUCLEAN;
        assert(cam_cc_crm_transport_vote(&t, 0, 0, 3) == expected);
        if (!expected) { assert(votes == 3 && !t.fault); continue; }
        assert(votes == 1 && t.fault == expected && masks == 1 && !t.ready);
        assert(t.votes[0][0].poisoned && !t.votes[0][0].confirmed_valid);
        powered = true;
        before = writes;
        assert(cam_cc_crm_transport_vote(&t, 0, 0, 4) == expected);
        assert(writes == before);
        memory[0x1160 / 4] = 1; /* late IRQ cannot clear fault or confirm retry */
        assert(registered_handler(121, &t) == IRQ_HANDLED);
        assert(t.fault == expected && writes == before && !t.pending);
    }
    for (i = 3; i <= 4; i++) {
        reset_model(&t); assert(initialize(&t) == 0); access_calls = 0; fail_access = i;
        assert(cam_cc_crm_transport_vote(&t, 0, 0, 3) == -EHOSTDOWN);
        assert(votes == i - 2 && masks == 1 && t.fault == -EHOSTDOWN);
    }
    reset_model(&t); powered = false;
    assert(initialize(&t) == -EHOSTDOWN && reads == 0 && writes == 0 && !registered);
    reset_model(&t); memory[3] = 0;
    assert(initialize(&t) == -EOPNOTSUPP && writes == 0 && !registered);
    reset_model(&t); memory[1] = 0;
    assert(initialize(&t) == -EINVAL && writes == 0 && !registered);
    reset_model(&t); request_error = -EBUSY;
    assert(initialize(&t) == -EBUSY && writes == 0 && !t.irq_owned);
    reset_model(&t); fail_access = 2;
    assert(initialize(&t) == -EHOSTDOWN && writes == 0 && t.irq_owned && masks == 1);
    for (i = 0; i < 8; i++) {
        reset_model(&t); enable_failure = (int)i;
        assert(initialize(&t) == -EIO && enables == i + 1 && masks == 1 && t.irq_owned);
    }
    reset_model(&t); memory[0x1178 / 4] = 1;
    assert(initialize(&t) == -EUCLEAN && writes == 0 && masks == 1);
    reset_model(&t); memory[0x11f8 / 4] = 2;
    assert(initialize(&t) == -EOPNOTSUPP && writes == 0 && masks == 1);
    reset_model(&t); assert(initialize(&t) == 0);
    memory[0x1160 / 4] = 1; before = writes;
    assert(cam_cc_crm_transport_vote(&t, 0, 0, 3) == -EUCLEAN && writes == before);
    reset_model(&t); assert(initialize(&t) == 0);
    memory[0x1174 / 4] = 1; memory[0x1504 / 4] = 1; /* unowned */
    before = writes;
    assert(registered_handler(121, &t) == IRQ_NONE && writes == before && !t.fault);
    assert(memory[0x1174 / 4] == 1 && memory[0x1504 / 4] == 1);
    before = reads;
    assert(registered_handler(122, &t) == IRQ_NONE && reads == before);
    assert(cam_cc_crm_transport_vote(&t, 0, 5, 1) == -EINVAL);
    assert(cam_cc_crm_transport_vote(&t, 1, 1, 1) == -EINVAL);
    assert(cam_cc_crm_transport_vote(&t, 0, 0, 8) == -ERANGE && !t.fault);
    puts("Actual CRM transport: owned IRQ ordering, 24 success/HZ cases, timeout/late/wrong/duplicate IRQ, power/partial-init and contention controls passed");

    reset_model(&t); assert(initialize(&t) == 0);
    assert(cam_cc_crm_transport_idle(&t, false) == 0);
    assert(!t.ready && t.quiesced && t.irq_owned && enables == 16 && drains == 1);
    powered = false; before = reads;
    assert(registered_handler(121, &t) == IRQ_NONE && reads == before && !t.fault);
    assert(cam_cc_crm_transport_vote(&t, 0, 0, 3) == -ENODEV && reads == before);
    assert(cam_cc_crm_transport_idle(&t, false) == 0 && reads == before);
    powered = true;
    assert(cam_cc_crm_transport_resume(&t) == 0 && t.ready && !t.quiesced && enables == 24);
    assert(cam_cc_crm_transport_resume(&t) == -EALREADY && !t.fault);
    assert(cam_cc_crm_transport_vote(&t, 0, 0, 3) == 0);
    before = writes;
    assert(cam_cc_crm_transport_idle(&t, false) == -EBUSY && writes == before && !t.fault);
    assert(cam_cc_crm_transport_vote(&t, 0, 0, 0) == 0);
    assert(cam_cc_crm_transport_idle(&t, true) == 0 && freed == 1 && !t.irq_owned && t.released);
    assert(cam_cc_crm_transport_vote(&t, 0, 0, 1) == -ENODEV);
    assert(cam_cc_crm_transport_resume(&t) == -ENODEV);
    assert(initialize(&t) == -EALREADY);
    for (kind = 0; kind < 2; kind++) {
        for (resource = 0; resource < 8; resource++) {
            if (kind == 0 ? !owned_perf(resource) : resource != 0) continue;
            for (i = 0; i < 3; i++) {
                reset_model(&t); assert(initialize(&t) == 0);
                memory[((kind == 0 ? 0x1060 : 0x1400) + resource * 4 + i * 0x40) / 4] = 3;
                before = writes;
                assert(cam_cc_crm_transport_idle(&t, false) == -EBUSY);
                assert(writes == before && !t.fault && t.ready && drains == 0);
            }
        }
    }
    reset_model(&t); assert(initialize(&t) == 0);
    t.transaction.locked = true; before = reads;
    assert(cam_cc_crm_transport_idle(&t, true) == -EBUSY && reads == before && !freed);
    t.transaction.locked = false; t.pending = true;
    assert(cam_cc_crm_transport_idle(&t, false) == -EBUSY && !t.fault);
    for (i = 0; i < 8; i++) {
        reset_model(&t); assert(initialize(&t) == 0); enable_failure = 8 + (int)i;
        assert(cam_cc_crm_transport_idle(&t, true) == -EIO);
        assert(t.fault == -EIO && t.irq_owned && masks == 1 && !freed && !drains);
        before = writes;
        assert(cam_cc_crm_transport_idle(&t, true) == -EIO && writes == before && !freed);
        reset_model(&t); assert(initialize(&t) == 0);
        assert(cam_cc_crm_transport_idle(&t, false) == 0); enable_failure = 16 + (int)i;
        assert(cam_cc_crm_transport_resume(&t) == -EIO);
        assert(t.fault == -EIO && t.irq_owned && masks == 1 && !freed && !t.ready);
    }
    for (scenario = 0; scenario < 5; scenario++) {
        reset_model(&t); assert(initialize(&t) == 0);
        if (scenario == 0) memory[0x1060 / 4] = 8;
        if (scenario == 1) memory[0x1400 / 4] = 1U << 28;
        if (scenario == 2) memory[0x1160 / 4] = 1;
        if (scenario == 3) memory[0x11e0 / 4] = 0;
        if (scenario == 4) powered = false;
        before = writes;
        expected = scenario == 4 ? -EHOSTDOWN : -EUCLEAN;
        assert(cam_cc_crm_transport_idle(&t, true) == expected);
        assert(t.fault == expected && writes == before && t.irq_owned && !freed);
    }
    for (scenario = 0; scenario < 6; scenario++) {
        reset_model(&t); assert(initialize(&t) == 0);
        assert(cam_cc_crm_transport_idle(&t, false) == 0);
        if (scenario == 0) memory[0] ^= 0x10000;
        if (scenario == 1) memory[1] ^= 1U << 8;
        if (scenario == 2) memory[3] = 0;
        if (scenario == 3) memory[0x1160 / 4] = 1;
        if (scenario == 4) memory[0x11e0 / 4] = 1;
        if (scenario == 5) powered = false;
        before = writes;
        expected = scenario == 5 ? -EHOSTDOWN : -EUCLEAN;
        assert(cam_cc_crm_transport_resume(&t) == expected);
        assert(t.fault == expected && writes == before && !t.ready && !freed);
    }
    reset_model(&t); assert(initialize(&t) == 0);
    assert(cam_cc_crm_transport_idle(&t, false) == 0);
    powered = false; before = reads;
    assert(cam_cc_crm_transport_idle(&t, true) == 0 && freed == 1 && reads == before);
    for (scenario = 0; scenario < 3; scenario++) {
        reset_model(&t); assert(initialize(&t) == 0);
        if (scenario == 1) assert(cam_cc_crm_transport_idle(&t, false) == 0);
        before_lock_hook = release_before_lock;
        if (scenario == 0) expected = cam_cc_crm_transport_idle(&t, true);
        else if (scenario == 1) expected = cam_cc_crm_transport_resume(&t);
        else expected = cam_cc_crm_transport_vote(&t, 0, 0, 1);
        assert(expected == -ENODEV && freed == 1 && !registered && !t.base);
    }
    puts("Actual CRM lifecycle: idle-vote refusal, owned IRQ disable/readback/drain/release, powered-off quiescence, resume identity and all16 partial-transition failures passed");
}

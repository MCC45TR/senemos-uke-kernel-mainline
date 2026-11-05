/* SPDX-License-Identifier: GPL-2.0-only */
#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <errno.h>

#define IRQCHIP_STATE_LINE_LEVEL 1
#define IRQ_HANDLED 1
typedef int irqreturn_t;
struct mutex { bool held; };
struct work_struct { unsigned int unused; };
struct delayed_work { struct work_struct work; bool pending; };
struct device { bool wake; void *data; };
struct input_dev { int state; unsigned int reports, syncs; };
static int read_error, error_irq, wakes, warnings, cancels;
static bool open_level, closed_level, report_locked;
static void *system_freezable_wq = (void *)1;
#define container_of(p, type, member) ((type *)((char *)(p) - offsetof(type, member)))
#define to_delayed_work(p) container_of(p, struct delayed_work, work)
#define DEFINE_SIMPLE_DEV_PM_OPS(name, suspend, resume) \
    int (*name[])(struct device *) __attribute__((unused)) = {suspend, resume}
#define dev_warn(dev, message) do { assert(dev); ++warnings; } while (0)
static void mutex_lock(struct mutex *lock) { assert(!lock->held); lock->held = true; report_locked = true; }
static void mutex_unlock(struct mutex *lock) { assert(lock->held); lock->held = false; report_locked = false; }
static unsigned long msecs_to_jiffies(unsigned long delay) { return delay; }
static bool queue_delayed_work(void *queue, struct delayed_work *work, unsigned long delay)
{
    assert(queue == system_freezable_wq && delay == 250);
    assert(!work->pending);
    work->pending = true;
    return true;
}
static bool cancel_delayed_work_sync(struct delayed_work *work)
{
    bool pending = work->pending;
    work->pending = false;
    ++cancels;
    return pending;
}
static void *dev_get_drvdata(struct device *dev) { return dev->data; }
static int device_init_wakeup(struct device *dev, bool wake) { dev->wake = wake; return 0; }
static bool device_may_wakeup(struct device *dev) { return dev->wake; }
static void pm_wakeup_event(struct device *dev, unsigned int ms) { assert(dev->wake && ms == 500); ++wakes; }
static int irq_get_irqchip_state(int irq, int which, bool *state)
{
    assert(report_locked && which == IRQCHIP_STATE_LINE_LEVEL);
    if (read_error && (error_irq == 0 || error_irq == irq))
        return read_error;
    assert(irq == 10 || irq == 11);
    *state = irq == 10 ? open_level : closed_level;
    return 0;
}
static void input_report_switch(struct input_dev *input, unsigned int code, int state)
{
    assert(report_locked && code <= 1 && (state == 0 || state == 1));
    ++input->reports;
    input->state = state;
}
static void input_sync(struct input_dev *input) { assert(report_locked); ++input->syncs; }
#include "callbacks.h"

static void tick(struct smp2p_switch *sw)
{
    assert(sw->initial_work.pending);
    sw->initial_work.pending = false;
    smp2p_switch_initial_state(&sw->initial_work.work);
    assert(!sw->lock.held);
}

int main(void)
{
    struct input_dev input = {0};
    struct device dev = {.wake = true};
    struct smp2p_switch sw = {.dev = &dev, .input = &input, .open_irq = 10, .closed_irq = 11};
    dev.data = &sw;
    /* Probe before the remote entry exists; later stationary closure has no IRQ. */
    read_error = -ENODEV;
    smp2p_switch_start(&sw);
    assert(sw.initial_work.pending && !input.reports && !wakes);
    read_error = 0;
    tick(&sw); /* 00 is unknown. */
    assert(sw.initial_work.pending && !input.reports);
    open_level = closed_level = true;
    tick(&sw); /* 11 is contradictory. */
    assert(sw.initial_work.pending && !input.reports);
    open_level = false;
    tick(&sw); /* 01: closed, without opening/closing the physical cover. */
    assert(!sw.initial_work.pending && input.state == 1 && input.reports == 1 && !wakes);
    /* Only a real valid open IRQ may wake, including after initial resync. */
    open_level = true; closed_level = false;
    assert(smp2p_switch_irq(10, &sw) == IRQ_HANDLED && input.state == 0 && wakes == 1);
    closed_level = true;
    smp2p_switch_irq(10, &sw);
    assert(wakes == 1 && input.reports == 2);
    open_level = false;
    smp2p_switch_irq(11, &sw);
    assert(input.state == 1 && wakes == 1);
    smp2p_switch_irq(10, &sw); /* Wrong IRQ while pair says closed. */
    assert(input.state == 1 && wakes == 1);
    /* Resume retries without falsely reopening the retained closed state. */
    assert(smp2p_switch_suspend(&dev) == 0);
    read_error = -EIO;
    assert(smp2p_switch_resume(&dev) == 0 && sw.initial_work.pending && input.state == 1);
    read_error = 0; open_level = true; closed_level = false;
    tick(&sw);
    assert(!sw.initial_work.pending && input.state == 0 && wakes == 1);
    /* Disabled wake, non-open IRQ, and startup open never cause wake. */
    dev.wake = false;
    smp2p_switch_irq(10, &sw);
    assert(wakes == 1);
    dev.wake = true;
    smp2p_switch_start(&sw);
    assert(!sw.initial_work.pending && input.state == 0 && wakes == 1);
    /* Bound persistent unavailable state; no fabricated input or timer left. */
    unsigned int reports = input.reports;
    read_error = -ENODEV;
    smp2p_switch_start(&sw);
    for (int i = 1; i < 120; ++i) tick(&sw);
    assert(!sw.initial_work.pending && warnings == 1 && reports == input.reports);
    read_error = 0; open_level = false; closed_level = true;
    smp2p_switch_irq(11, &sw);
    assert(input.state == 1 && wakes == 1);
    /* Both line-read failures and tablet-mode code retain the same contract. */
    for (int irq = 10; irq <= 11; ++irq) {
        read_error = -EIO; error_irq = irq;
        smp2p_switch_start(&sw);
        assert(sw.initial_work.pending);
        assert(smp2p_switch_suspend(&dev) == 0 && !sw.initial_work.pending);
    }
    error_irq = read_error = 0;
    sw.code = 1;
    smp2p_switch_start(&sw);
    assert(input.state == 1 && !sw.initial_work.pending && wakes == 1);
    open_level = closed_level = false;
    smp2p_switch_start(&sw);
    assert(sw.initial_work.pending);
    smp2p_switch_work_cleanup(&sw);
    assert(!sw.initial_work.pending && cancels == 4);
    smp2p_switch_wake_cleanup(&dev);
    assert(!dev.wake && input.reports == input.syncs && !sw.lock.held);
}

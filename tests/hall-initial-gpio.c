/* SPDX-License-Identifier: GPL-2.0-only */
/* The unchanged legacy assertions run first with no optional GPIO property. */
#include <stdio.h>
#define main legacy_hall_main
#include "legacy-hall.c"
#undef main

static unsigned int cases;
static void reset(void)
{
    assert(!report_locked && !gpio_held);
    gpio_provider_reset();
    read_error = error_irq = wakes = warnings = cancels = 0;
    open_level = closed_level = false;
}
static void trial(int remote, int direction, int get_error, int first, int second,
                  bool active_low, int expected, unsigned int gets, unsigned int puts)
{
    reset();
    struct input_dev input = {0};
    struct device dev = {.wake = true};
    struct smp2p_switch sw = {.dev=&dev, .input=&input, .open_irq=10, .closed_irq=11};
    dev.data = &sw;
    read_error = remote;
    gpio_property = true; gpio_active_low = active_low;
    gpio_direction = direction; gpio_get_error = get_error;
    gpio_samples[0] = first; gpio_samples[1] = second;
    smp2p_switch_start(&sw);
    assert(!gpio_held && gpio_gets == gets && gpio_puts == puts && !wakes);
    if (expected >= 0) {
        assert(!sw.initial_work.pending && input.reports == 1 && input.state == expected);
    } else {
        assert(sw.initial_work.pending && !input.reports);
        assert(smp2p_switch_suspend(&dev) == 0 && !sw.initial_work.pending);
    }
    assert(input.reports == input.syncs);
    cases++;
}
int main(void)
{
    assert(legacy_hall_main() == 0);
    if (!CONFIG_GPIOLIB) {
        reset();
        struct input_dev input={0};struct device dev={.wake=true};
        struct smp2p_switch sw={.dev=&dev,.input=&input,.open_irq=10,.closed_irq=11};
        dev.data=&sw;gpio_property=true;
        smp2p_switch_start(&sw);
        assert(sw.initial_work.pending&&!gpio_gets&&!gpio_held&&!input.reports);
        assert(smp2p_switch_suspend(&dev)==0&&!sw.initial_work.pending);
        puts("Actual Hall optional-GPIOLIB off: legacy callbacks and no GPIO calls passed.");
        return 0;
    }
    for (int remote = 0; remote < 3; ++remote) {
        const int errors[] = {-EAGAIN,-ENODEV,-EIO};
        for (int polarity=0; polarity<2; ++polarity)
            for (int level=0; level<2; ++level)
                trial(errors[remote],1,0,level,level,polarity,level ^ polarity,1,1);
        trial(errors[remote],1,-EBUSY,0,0,true,-EBUSY,1,0);
        trial(errors[remote],1,-EAGAIN,0,0,true,-EAGAIN,1,0);
        trial(errors[remote],1,-ENODEV,0,0,true,-ENODEV,1,0);
        trial(errors[remote],0,0,0,0,true,-EINVAL,1,1);
        trial(errors[remote],-EIO,0,0,0,true,-EIO,1,1);
        trial(errors[remote],1,0,-EIO,0,true,-EIO,1,1);
        trial(errors[remote],1,0,0,-EIO,true,-EIO,1,1);
        trial(errors[remote],1,0,0,1,true,-EAGAIN,1,1);
        trial(errors[remote],1,0,1,0,true,-EAGAIN,1,1);
        trial(errors[remote],1,0,2,2,true,-EIO,1,1);
    }
    /* Valid remote state retains precedence and does not acquire a GPIO. */
    for (int closed=0; closed<2; ++closed) {
        reset();
        struct input_dev input = {0}; struct device dev = {.wake=true};
        struct smp2p_switch sw = {.dev=&dev,.input=&input,.open_irq=10,.closed_irq=11};
        dev.data=&sw;gpio_property=true;
        open_level=!closed;closed_level=closed;
        smp2p_switch_start(&sw);
        assert(input.reports==1&&input.state==closed&&!gpio_gets&&!gpio_held&&!wakes);
        cases++;
    }
    /* Real interrupts never fall back to the physical startup sampler. */
    for (int irq=10;irq<=11;++irq) {
        reset();
        struct input_dev input={0};struct device dev={.wake=true};
        struct smp2p_switch sw={.dev=&dev,.input=&input,.open_irq=10,.closed_irq=11};
        gpio_property=true;
        smp2p_switch_irq(irq,&sw);
        assert(!input.reports&&!wakes&&!gpio_gets&&!gpio_held);
        cases++;
    }
    /* An unavailable GPIO supplier can become ready without a physical edge. */
    {
        reset();
        struct input_dev input={0};struct device dev={.wake=true};
        struct smp2p_switch sw={.dev=&dev,.input=&input,.open_irq=10,.closed_irq=11};
        dev.data=&sw;gpio_property=true;gpio_get_error=-ENODEV;
        smp2p_switch_start(&sw);
        assert(sw.initial_work.pending&&!input.reports&&!gpio_held);
        gpio_get_error=0;
        tick(&sw);
        assert(!sw.initial_work.pending&&input.state==1&&input.reports==1);
        assert(gpio_gets==2&&gpio_puts==1&&!gpio_held&&!wakes);
        cases++;
        /* Resume resamples an unknown remote entry without waking itself. */
        assert(smp2p_switch_suspend(&dev)==0);
        gpio_reads=0;gpio_samples[0]=gpio_samples[1]=1;
        assert(smp2p_switch_resume(&dev)==0);
        assert(!sw.initial_work.pending&&input.state==0&&input.reports==2);
        assert(gpio_gets==3&&gpio_puts==2&&!gpio_held&&!wakes);
        cases++;
    }
    /* A permanently busy physical line preserves the existing bounded retry. */
    {
        reset();
        struct input_dev input={0};struct device dev={.wake=true};
        struct smp2p_switch sw={.dev=&dev,.input=&input,.open_irq=10,.closed_irq=11};
        dev.data=&sw;gpio_property=true;gpio_get_error=-EBUSY;
        smp2p_switch_start(&sw);
        for(int n=1;n<120;++n)tick(&sw);
        assert(!sw.initial_work.pending&&!input.reports&&warnings==1);
        assert(gpio_gets==120&&!gpio_puts&&!gpio_held&&!wakes);
        cases++;
    }
    reset();
    printf("Actual initial Hall GPIO: %u provider/polarity/error/IRQ cases and unchanged legacy assertions passed.\n",cases);
    return 0;
}

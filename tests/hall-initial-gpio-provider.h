/* SPDX-License-Identifier: GPL-2.0-only */
/* Independent fake GPIO provider; never accesses a real line. */
#include <stdint.h>
#include <string.h>
#ifndef CONFIG_GPIOLIB
#define CONFIG_GPIOLIB 1
#endif
#define IS_ENABLED(option) (option)
#define GPIOD_ASIS 0
#define GPIOD_IN 1
#define IS_ERR(pointer) ((intptr_t)(pointer) < 0 && (intptr_t)(pointer) > -4096)
#define PTR_ERR(pointer) ((int)(intptr_t)(pointer))
struct gpio_desc { int unused; };
static struct gpio_desc gpio_descriptor;
static bool gpio_property, gpio_active_low = true, gpio_held;
static int gpio_get_error, gpio_direction = 1, gpio_samples[2];
static unsigned int gpio_gets, gpio_puts, gpio_reads, gpio_sleeps;
static inline bool device_property_present(struct device *dev, const char *name)
{
    assert(dev && report_locked && !strcmp(name, "state-gpios"));
    return gpio_property;
}
static inline struct gpio_desc *gpiod_get(struct device *dev, const char *name, int flags)
{
    assert(dev && report_locked && !strcmp(name, "state") && flags == GPIOD_ASIS);
    assert(gpio_property && !gpio_held);
    ++gpio_gets;
    if (gpio_get_error) return (struct gpio_desc *)(intptr_t)gpio_get_error;
    gpio_held = true;
    return &gpio_descriptor;
}
static inline int gpiod_get_direction(struct gpio_desc *gpio)
{
    assert(gpio == &gpio_descriptor && gpio_held && report_locked);
    return gpio_direction;
}
static inline int gpiod_get_raw_value_cansleep(struct gpio_desc *gpio)
{
    assert(gpio == &gpio_descriptor && gpio_held && report_locked && gpio_reads < 2);
    return gpio_samples[gpio_reads++];
}
static inline int gpiod_get_value_cansleep(struct gpio_desc *gpio)
{
    int raw = gpiod_get_raw_value_cansleep(gpio);
    return raw < 0 || raw > 1 ? raw : raw ^ gpio_active_low;
}
static inline void usleep_range(unsigned long low, unsigned long high)
{
    assert(report_locked && gpio_held && low == 1000 && high == 2000);
    ++gpio_sleeps;
}
static inline void gpiod_put(struct gpio_desc *gpio)
{
    assert(gpio == &gpio_descriptor && gpio_held && report_locked);
    gpio_held = false;
    ++gpio_puts;
}
static inline void gpio_provider_reset(void)
{
    assert(!gpio_held);
    gpio_property = false; gpio_active_low = true;
    gpio_get_error = 0; gpio_direction = 1;
    gpio_samples[0] = gpio_samples[1] = 0;
    gpio_gets = gpio_puts = gpio_reads = gpio_sleeps = 0;
}

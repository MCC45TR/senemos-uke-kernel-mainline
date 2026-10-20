#!/usr/bin/env bash
# Actual native probe/carrier/duty functions; no SPI transmission is executed.
set -Eeuo pipefail
source_file=${1:?Pass native ir-spi.c}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
#define EPROBE_DEFER 517
#define GFP_KERNEL 0
#define RC_DRIVER_IR_RAW_TX 1
#define ERR_PTR(e) ((void *)(intptr_t)(e))
#define IS_ERR(p) ((uintptr_t)(p) >= (uintptr_t)-4095)
#define PTR_ERR(p) ((int)(intptr_t)(p))
#define GENMASK(h, l) ((UINT64_MAX >> (63 - (h))) & (UINT64_MAX << (l)))
struct device { int unused; };
struct spi_device { struct device dev; u32 max_speed_hz; };
struct regulator { int unused; };
struct rc_dev {
    int (*tx_ir)(struct rc_dev *, unsigned int *, unsigned int);
    int (*s_tx_carrier)(struct rc_dev *, u32);
    int (*s_tx_duty_cycle)(struct rc_dev *, u32);
    const char *device_name, *driver_name;
    void *priv;
};
C
awk '/^#define IR_SPI_/ { print } /^struct ir_spi_data \{/ { emit=1 } emit { print } emit && /^};/ { exit }' \
    "$source_file" >> "$work/check.c"
cat >> "$work/check.c" <<'C'
static struct ir_spi_data storage;
static struct rc_dev rc;
static struct regulator regulator;
static int fault, registered, read_error, supply_calls;
static bool standard_supply, duty_present, negated;
static u8 duty;
static const char *supply;
static void *devm_kzalloc(struct device *dev, size_t size, int flags) {
    (void)dev; (void)flags; assert(size == sizeof(storage)); memset(&storage, 0, sizeof(storage));
    return fault == 1 ? NULL : &storage;
}
static struct regulator *devm_regulator_get(struct device *dev, const char *name) {
    (void)dev; supply_calls++; supply = name; return fault == 2 ? ERR_PTR(-EPROBE_DEFER) : &regulator;
}
static struct rc_dev *devm_rc_allocate_device(struct device *dev, int type) {
    (void)dev; assert(type == RC_DRIVER_IR_RAW_TX); memset(&rc, 0, sizeof(rc)); return fault == 3 ? NULL : &rc;
}
static int devm_rc_register_device(struct device *dev, struct rc_dev *r) {
    (void)dev; assert(r == &rc); registered++; return fault == 4 ? -EBUSY : 0;
}
static bool device_property_read_bool(struct device *dev, const char *name) {
    (void)dev; assert(!strcmp(name, "led-active-low")); return negated;
}
static inline bool device_property_present(struct device *dev, const char *name) {
    (void)dev; return !strcmp(name, "power-supply") ? standard_supply : duty_present;
}
static int device_property_read_u8(struct device *dev, const char *name, u8 *value) {
    (void)dev; assert(!strcmp(name, "duty-cycle"));
    if (!duty_present) return -EINVAL;
    if (read_error) return read_error;
    *value = duty; return 0;
}
static int ir_spi_tx(struct rc_dev *dev, unsigned int *buffer, unsigned int count) {
    (void)dev; (void)buffer; (void)count; assert(false); return -EIO;
}
C
awk '/^static int ir_spi_(set_tx_carrier|set_duty_cycle|probe)\(/ { emit=1 } \
    emit { print } emit && /^}/ { emit=0 }' "$source_file" >> "$work/check.c"
cat >> "$work/check.c" <<'C'
static void reset(void) {
    fault = registered = read_error = supply_calls = 0; standard_supply = true;
    duty_present = negated = false; duty = 50; supply = NULL;
}
int main(void) {
    struct spi_device spi = {.max_speed_hz = 19200000};
    reset(); assert(ir_spi_probe(&spi) == 0 && registered == 1 && !strcmp(supply, "power"));
    assert(storage.freq == 38000 && storage.pulse == 0xff && storage.space == 0);
    reset(); fault = 2;
    assert(ir_spi_probe(&spi) == -EPROBE_DEFER && !registered && supply_calls == 1 && !strcmp(supply, "power"));
    reset(); standard_supply = false;
    assert(ir_spi_probe(&spi) == 0 && !strcmp(supply, "irda_regulator"));
    for (fault = 1; fault <= 4; fault++) {
        registered = 0;
        assert(ir_spi_probe(&spi) == (fault == 2 ? -EPROBE_DEFER : fault == 4 ? -EBUSY : -ENOMEM));
        assert(registered == (fault == 4));
    }
    for (unsigned int value = 0; value <= 255; value++) {
        reset(); duty_present = true; duty = value;
        int ret = ir_spi_probe(&spi);
        assert(ret == (value && value < 100 ? 0 : -EINVAL));
        assert(registered == (value && value < 100));
    }
    reset(); duty_present = true; read_error = -EILSEQ;
    assert(ir_spi_probe(&spi) == -EILSEQ && !registered);
    reset(); spi.max_speed_hz = 38000 * 16 - 1;
    assert(ir_spi_probe(&spi) == -EINVAL && !registered);
    spi.max_speed_hz++; assert(ir_spi_probe(&spi) == 0 && registered == 1);
    assert(ir_spi_set_tx_carrier(&rc, 0) == -EINVAL && storage.freq == 38000);
    assert(ir_spi_set_tx_carrier(&rc, 38001) == -EINVAL && storage.freq == 38000);
    assert(ir_spi_set_tx_carrier(&rc, 10000) == 0 && storage.freq == 10000);
    for (int active_low = 0; active_low <= 1; active_low++) {
        storage.negated = active_low;
        for (unsigned int value = 1; value < 100; value++) {
            assert(ir_spi_set_duty_cycle(&rc, value) == 0);
            u16 expected = (u16)((1U << ((value * 15) / 100 + 1)) - 1);
            if (active_low) expected = ~expected;
            assert(storage.pulse == expected && storage.space == (active_low ? 0xffff : 0));
        }
        const u32 invalid[] = {0, 100, 255, UINT32_MAX};
        for (unsigned int i = 0; i < sizeof(invalid) / sizeof(invalid[0]); i++) {
            u16 old_pulse = storage.pulse, old_space = storage.space;
            assert(ir_spi_set_duty_cycle(&rc, invalid[i]) == -EINVAL);
            assert(storage.pulse == old_pulse && storage.space == old_space);
        }
    }
    puts("Actual IR probe/duty/carrier: standard/legacy supply, failures and invalid defaults rejected; no SPI output");
}
C
"${CC:-gcc}" -std=gnu11 -O2 -Wall -Wextra -Werror ${IR_TEST_CFLAGS:-} \
    "$work/check.c" -o "$work/check"
"$work/check"

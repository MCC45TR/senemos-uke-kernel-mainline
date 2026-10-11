#!/usr/bin/env bash
# Host faults in the actual KTZ8866 write paths; no device or I2C access.
set -Eeuo pipefail
source_file=${1:?Pass the prepared ktz8866.c}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
{
    cat <<'CPP'
#include <cassert>
#include <cerrno>
#include <cstring>
#define BIT(n) (1U << (n))
enum { BL_CFG2 = 3, BL_BRT_LSB = 4, BL_BRT_MSB = 5, BL_EN = 8,
       LCD_BIAS_CFG1 = 9, BL_DIMMING = 20, BL_EN_BIT = BIT(6),
       LCD_BIAS_EN = 0x9f, PWM_HYST = 5 };
struct device { void *of_node = this; };
struct i2c_client { device dev; };
struct ktz8866 { i2c_client *client; bool led_on = false; };
struct backlight_device { ktz8866 *data; unsigned int brightness; };
int fail_at = -1, writes = 0;
unsigned int regs[22];
bool have_sinks = true, have_ramp = true, have_dimming = true, have_bias = true;
unsigned int ramp = 128, dimming = 1;
ktz8866 *bl_get_data(backlight_device *bl) { return bl->data; }
unsigned int backlight_get_brightness(backlight_device *bl) { return bl->brightness; }
int ktz8866_write(ktz8866 *, unsigned int reg, unsigned int value) {
    assert(reg < 22);
    if (writes++ == fail_at) return -EIO;
    regs[reg] = value; return 0;
}
int ktz8866_update_bits(ktz8866 *ktz, unsigned int reg, unsigned int mask, unsigned int value) {
    return ktz8866_write(ktz, reg, (regs[reg] & ~mask) | value);
}
int of_property_read_u32(void *, const char *name, unsigned int *value) {
    if (!std::strcmp(name, "current-num-sinks")) { *value = 5; return have_sinks ? 0 : -EINVAL; }
    if (!std::strcmp(name, "kinetic,current-ramp-delay-ms")) { *value = ramp; return have_ramp ? 0 : -EINVAL; }
    assert(!std::strcmp(name, "kinetic,led-enable-ramp-delay-ms"));
    *value = dimming; return have_dimming ? 0 : -EINVAL;
}
bool of_property_read_bool(void *, const char *) { return have_bias; }
unsigned int ilog2(unsigned int n) { assert(n); return 31U - __builtin_clz(n); }
CPP
    awk '/^static int ktz8866_backlight_update_status/ { emit=1 } /^static const struct backlight_ops/ { emit=0 } emit { print }' "$source_file"
    awk '/^static (int|void) ktz8866_init/ { emit=1 } /^static int ktz8866_probe/ { emit=0 } emit { print }' "$source_file"
    cat <<'CPP'
void reset() { writes = 0; fail_at = -1; std::memset(regs, 0, sizeof(regs)); }
int main() {
    i2c_client client;
    ktz8866 ktz{&client};
    backlight_device bl{&ktz, 1500};
    for (bool on : {false, true}) {
        for (unsigned int level : {0U, 1U, 7U, 8U, 1500U, 2047U}) {
            reset(); ktz.led_on = on; bl.brightness = level;
            const int count = !level || !on ? 3 : 2;
            for (int failure = 0; failure < count; ++failure) {
                reset(); ktz.led_on = on; fail_at = failure;
                assert(ktz8866_backlight_update_status(&bl) == -EIO);
                assert(writes == failure + 1);
                if (count == 3 && failure == 0) assert(ktz.led_on == on);
            }
            reset(); ktz.led_on = on;
            assert(ktz8866_backlight_update_status(&bl) == 0);
            assert(ktz.led_on == (level != 0));
            assert((regs[BL_BRT_MSB] << 3 | regs[BL_BRT_LSB]) == level);
        }
    }
    for (unsigned int ramp_value : {1U, 128U, 192U, 640U}) {
        for (unsigned int dimming_value : {0U, 1U, 16384U}) {
            ramp = ramp_value; dimming = dimming_value;
            for (int failure = 0; failure < 4; ++failure) {
                reset(); fail_at = failure;
                assert(ktz8866_init(&ktz) == -EIO && writes == failure + 1);
            }
            reset(); assert(ktz8866_init(&ktz) == 0 && writes == 4);
        }
    }
    have_sinks = have_ramp = have_dimming = have_bias = false;
    reset(); assert(ktz8866_init(&ktz) == 0 && writes == 1 && regs[BL_EN] == 63);
}
CPP
} > "$work/check.cpp"
grep -F 'ret = ktz8866_init(ktz);' "$source_file" >/dev/null
grep -F 'return backlight_update_status(backlight_dev);' "$source_file" >/dev/null
g++ -std=c++20 -O2 -Wall -Wextra -Werror -include initializer_list "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Brightness and initialization write faults, boundary levels and LED state: passed\n'

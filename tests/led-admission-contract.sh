#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
if (($# != 1)); then echo 'Usage: led-admission-contract.sh LINUX_SOURCE' >&2; exit 2; fi
source_tree=$1
testdir=$(mktemp -d)
trap 'rm -rf "$testdir"' EXIT
mkdir -p "$testdir/drivers/leds/rgb"
file=drivers/leds/rgb/leds-qcom-lpg.c
cp "$source_tree/$file" "$testdir/$file"
patch -s -d "$testdir" -p1 < src/leds/pmxr2230-driver.patch
awk '
 /static int lpg_pmxr2230_validate/ { active=1 }
 active { print }
 active && /^}/ { exit }
' "$testdir/$file" > "$testdir/guard.inc"
test -s "$testdir/guard.inc"
guard_line=$(grep -n 'ret = lpg_pmxr2230_validate(lpg)' "$testdir/$file" | cut -d: -f1)
write_line=$(grep -n 'ret = lpg_parse_dtest(lpg)' "$testdir/$file" | cut -d: -f1)
((guard_line < write_line))
! grep -Eq 'regmap_(write|update)|nvmem|gpio|pwm_apply' "$testdir/guard.inc"
cat > "$testdir/test.c" <<'EOF'
#include <assert.h>
#include <errno.h>
#include <stdarg.h>
#define LPG_SUBTYPE_REG 5
#define LPG_SUBTYPE_PWM 0xb
#define LPG_SUBTYPE_HI_RES_PWM 0xc
#define LPG_SUBTYPE_LPG_LITE 0x11
struct regmap { unsigned int values[0x10000], fail; int error; };
struct lpg_channel_data { unsigned int base; };
struct lpg_data { unsigned int num_channels; const struct lpg_channel_data *channels; };
struct lpg { struct regmap *map; void *dev; const struct lpg_data *data; };
static int regmap_read(struct regmap *map, unsigned int address, unsigned int *value)
{
    if (map->error && address == map->fail) return map->error;
    *value = map->values[address];
    return 0;
}
static int dev_err_probe(void *dev, int error, const char *format, ...)
{ (void)dev; (void)format; return error; }
#include "guard.inc"
int main(void)
{
    struct regmap map = {0};
    const struct lpg_channel_data channels[] = {{0xe800}, {0xe900}, {0xea00}, {0xeb00}};
    const struct lpg_data data = {4, channels};
    struct lpg lpg = {&map, 0, &data};
    map.values[0xef04] = 0x19;
    for (unsigned int i = 0; i < 4; i++) map.values[channels[i].base + 5] = 0xb;
    for (unsigned int subtype = 2; subtype <= 4; subtype += 2) {
        map.values[0xef05] = subtype;
        assert(lpg_pmxr2230_validate(&lpg) == 0);
    }
    const unsigned int rejected[] = {0, 1, 3, 5, 255};
    for (unsigned int i = 0; i < 5; i++) {
        map.values[0xef05] = rejected[i];
        assert(lpg_pmxr2230_validate(&lpg) == -ENODEV);
    }
    map.values[0xef05] = 4;
    map.values[0xef04] = 0;
    assert(lpg_pmxr2230_validate(&lpg) == -ENODEV);
    map.values[0xef04] = 0x19;
    for (unsigned int i = 0; i < 4; i++) {
        map.values[channels[i].base + 5] = 0;
        assert(lpg_pmxr2230_validate(&lpg) == -ENODEV);
        map.values[channels[i].base + 5] = 0xc;
        assert(lpg_pmxr2230_validate(&lpg) == 0);
        map.values[channels[i].base + 5] = 0x11;
        assert(lpg_pmxr2230_validate(&lpg) == 0);
    }
    const unsigned int reads[] = {0xef04, 0xef05, 0xe805, 0xe905, 0xea05, 0xeb05};
    for (unsigned int i = 0; i < 6; i++) {
        map.fail = reads[i]; map.error = -EIO;
        assert(lpg_pmxr2230_validate(&lpg) == -EIO);
    }
    return 0;
}
EOF
cc -std=gnu11 -O2 -Wall -Wextra -Werror "$testdir/test.c" -o "$testdir/test"
"$testdir/test"
printf '%s\n' 'PMXR2230 read-only admission accepts reviewed subtypes and rejects unknown, PBS-dependent and failed reads'

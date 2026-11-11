#!/usr/bin/env bash
# COPR only: actual IRQ transport and read-only LUT implementation bodies.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 ]]
project=$(cd -- "$(dirname -- "$0")/.." && pwd)
references=$(realpath "${1:?Pinned OEM reference directory}")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cc=${CC:-gcc}
cxx=${CXX:-g++}
extra=()
[[ -z ${CAMERA_CRM_TEST_FLAGS:-} ]] || read -r -a extra <<< "$CAMERA_CRM_TEST_FLAGS"
printf '%s  %s\n' 87b1645f20fd2ddbe07344ad707c74f81df9871bb53902b9243c1f617584da20 \
    "$references/oem571-clk-rcg2.c" | sha256sum -c --strict -
mkdir -p "$work/include/linux"
cat > "$work/include/linux/types.h" <<'C'
#include <stdbool.h>
#include <stdint.h>
typedef uint32_t u32;
typedef uint64_t u64;
C
for header in core transport; do
    sed '/^#include <linux\//d' "$project/src/camera/provider/camcc-sm7675-crm-$header.h" \
        > "$work/camcc-sm7675-crm-$header.h"
done
cp "$work/camcc-sm7675-crm-transport.h" "$work/crm-transport.h"
sed -n '70,78p' "$references/oem571-clk-rcg2.c" > "$work/oem-crmc-registers.h"
grep -q '^#define CLK_RCG_CRMC_CFG_RCGR_OFFSET' "$work/oem-crmc-registers.h"
cat > "$work/oracle.c" <<'C'
#include <assert.h>
#include <errno.h>
#include <linux/types.h>
#include "oem-crmc-registers.h"
#define BIT(n) (1U << (n))
#define CFG_SRC_SEL_MASK (7U << 8)
#define CFG_SRC_SEL_SHIFT 8
#define PLL_L_VAL_MASK 0xff
#define PLL_ALPHA_VAL_MASK 0xffff0000U
#define PLL_ALPHA_VAL_SHIFT 16
#define pr_err(...) ((void)0)
#define mult_frac(x, n, d) (((x) / (d)) * (n) + (((x) % (d)) * (n)) / (d))
struct freq_tbl { unsigned long freq; u32 pre_div, src; };
struct clk_hw { int unused; };
struct parent_map { u32 cfg, src; };
struct clk_crm { void *regmap_crmc; };
struct clk_rcg2 {
    struct { struct clk_hw hw; struct clk_crm *crm; u32 crm_vcd; } clkr;
    u32 hid_width;
    const struct parent_map *parent_map;
};
struct clk_regmap_ops { unsigned long (*calc_pll)(struct clk_hw *, u32, u64); };
struct clk_regmap { const struct clk_regmap_ops *ops; };
static struct clk_rcg2 rcg;
static struct clk_hw parent;
static struct clk_regmap rclk;
static unsigned read_calls;
static int first_error;
static struct clk_rcg2 *to_clk_rcg2(struct clk_hw *hw) { assert(hw); return &rcg; }
static unsigned clk_hw_get_num_parents(struct clk_hw *hw) { assert(hw); return 1; }
static struct clk_hw *clk_hw_get_parent_by_index(struct clk_hw *hw, unsigned i)
{ assert(hw && i == 0); return &parent; }
static unsigned long clk_hw_get_rate(struct clk_hw *hw) { assert(hw == &parent); return 19200000; }
static bool clk_is_regmap_clk(struct clk_hw *hw) { assert(hw); return false; }
static struct clk_regmap *to_clk_regmap(struct clk_hw *hw) { assert(hw); return &rclk; }
static int regmap_read(void *map, u32 offset, u32 *out)
{
    assert(map && read_calls < 2);
    assert(offset == (read_calls ? 0x13cU : 0x114U));
    *out = read_calls ? 0 : 1;
    return read_calls++ ? 0 : first_error;
}
C
printf 'static unsigned long\n' >> "$work/oracle.c"
awk '/^calc_rate\(/ {emit=1} emit {print} emit && /^}/ {exit}' \
    "$references/oem571-clk-rcg2.c" >> "$work/oracle.c"
awk '/^static int clk_rcg2_crmc_populate_freq\(/ {emit=1} emit {print} \
    emit && /^}/ {exit}' "$references/oem571-clk-rcg2.c" >> "$work/oracle.c"
cat >> "$work/oracle.c" <<'C'
int oem_lut_read_error(int error, unsigned *reads, unsigned long *rate)
{
    static const struct parent_map parents[] = {{ .cfg = 0, .src = 0 }};
    struct clk_crm crm = { .regmap_crmc = &crm };
    struct freq_tbl frequency = {0};
    int result;
    rcg.clkr.crm = &crm; rcg.clkr.crm_vcd = 0;
    rcg.hid_width = 5; rcg.parent_map = parents;
    read_calls = 0; first_error = error;
    result = clk_rcg2_crmc_populate_freq(&rcg.clkr.hw, 1, &frequency);
    *reads = read_calls; *rate = frequency.freq;
    return result;
}
C
[[ $(grep -c '^static int clk_rcg2_crmc_populate_freq(' "$work/oracle.c") == 1 ]]
flags=(-Wall -Wextra -Werror -O1 -g "${extra[@]}")
include=(-I"$work/include" -I"$work" -I"$project/src/camera/provider")
"$cc" -std=gnu11 "${flags[@]}" "${include[@]}" -c "$work/oracle.c" -o "$work/oracle.o"
"$cc" -std=gnu11 "${flags[@]}" -I"$work" \
    "$project/tests/fixtures/camera-crm-transport-check.c" -o "$work/transport"
"$work/transport"
"$cxx" -std=c++17 "${flags[@]}" "${include[@]}" \
    "$project/tests/fixtures/camera-crm-lut-check.cpp" "$work/oracle.o" -o "$work/lut"
"$work/lut"
ulimit -c 0
if ("$work/lut" --oem-negative > "$work/negative.log" 2>&1) 2>/dev/null; then
    printf 'OEM ignored LUT read-error negative control incorrectly passed\n' >&2; exit 1
else
    rc=$?
fi
[[ $rc == 134 ]]
grep -q 'rc == -EIO && reads == 1' "$work/negative.log"
printf 'Actual OEM LUT ignored-read-error negative control reproduced assertion134\n'
if [[ ${CAMERA_CRM_MUTATIONS:-0} == 1 ]]; then
    for mutation in timeout-units wrong-resource stale-completion no-drain inherited-vote unpowered-irq; do
        case $mutation in
            timeout-units) sed 's/msecs_to_jiffies(CAM_CC_CRM_TIMEOUT_MS)/CAM_CC_CRM_TIMEOUT_MS/' \
                "$work/camcc-sm7675-crm-transport.h";;
            wrong-resource) sed 's/t->pending_resource != resource/false/' \
                "$work/camcc-sm7675-crm-transport.h";;
            stale-completion) sed 's/if (t->pending || status)/if (t->pending || (status \&\& false))/' \
                "$work/camcc-sm7675-crm-transport.h";;
            no-drain) sed 's/synchronize_irq(t->irq);/if (false) synchronize_irq(t->irq);/' \
                "$work/camcc-sm7675-crm-transport.h";;
            inherited-vote) sed 's/if (value)$/if (value \&\& false)/' \
                "$work/camcc-sm7675-crm-transport.h";;
            unpowered-irq) sed 's/if (t->quiesced)$/if (t->quiesced \&\& false)/' \
                "$work/camcc-sm7675-crm-transport.h";;
        esac > "$work/crm-transport.h"
        if cmp -s "$work/camcc-sm7675-crm-transport.h" "$work/crm-transport.h"; then exit 1; fi
        "$cc" -std=gnu11 "${flags[@]}" -I"$work" \
            "$project/tests/fixtures/camera-crm-transport-check.c" -o "$work/mutant"
        if ("$work/mutant" > "$work/mutant.log" 2>&1) 2>/dev/null; then
            printf 'CRM transport mutation survived: %s\n' "$mutation" >&2; exit 1
        else
            rc=$?
        fi
        [[ $rc == 134 ]]
    done
    printf 'All6 timeout/resource/stale IRQ and drain/inherited-vote/quiescence mutants refused\n'
fi

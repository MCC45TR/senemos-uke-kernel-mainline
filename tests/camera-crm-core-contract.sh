#!/usr/bin/env bash
# COPR only: compile production C and compare immutable OEM function bodies.
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
while IFS=$'\t' read -r file digest; do
    printf '%s  %s\n' "$digest" "$references/$file" | sha256sum -c --strict -
done < <(jq -er '.oracle_inputs[] | [.reference_file,.sha256] | @tsv' \
    "$project/manifests/camera-crm-core-20261105.json")
mkdir -p "$work/include/linux"
cat > "$work/include/linux/types.h" <<'C'
#include <stdint.h>
#include <stdbool.h>
typedef uint32_t u32;
C
cat > "$work/oracle.c" <<'C'
#include <assert.h>
#include <errno.h>
#include <stddef.h>
#include <linux/types.h>
#define cpu_to_le32(value) ((u32)(value))
#include "oem571-tcs.h"
#define PERF_OL_VCD 0
#define BW_VOTE_VCD 1
C
# Preserve the actual enum, register arrays and offset implementation verbatim.
awk '/^enum \{/ {emit=1} emit {print} emit && /^};/ {exit}' \
    "$references/oem571-crm.c" >> "$work/oracle.c"
for array in sw_drv_perf_ol_vcd_regs sw_drv_bw_vote_vcd_regs; do
    awk -v name="$array" '$0=="static u32 " name "[] = {" {emit=1} \
        emit {print} emit && /^};/ {exit}' "$references/oem571-crm.c" >> "$work/oracle.c"
done
cat >> "$work/oracle.c" <<'C'
struct crm_vcd { u32 num_resources; u32 *offsets; };
struct crm_drv { u32 drv_id; struct crm_vcd vcd[2]; };
C
awk '/^static inline u32 crm_get_offset\(/ {emit=1} emit {print} \
    emit && /^}/ {exit}' "$references/oem571-crm.c" >> "$work/oracle.c"
cat >> "$work/oracle.c" <<'C'
u32 oem_offset(unsigned kind, unsigned role, unsigned state, u32 resource)
{
    struct crm_drv drv = { .drv_id = 0, .vcd = {
        { .num_resources = 9, .offsets = sw_drv_perf_ol_vcd_regs },
        { .num_resources = 3, .offsets = sw_drv_bw_vote_vcd_regs },
    }};
    u32 reg = role == 0 ? PWR_ST0 + state : IRQ_STATUS + role - 1;
    return crm_get_offset(&drv, reg, 0, kind, resource);
}
u32 oem_bw_word(u32 value)
{
    return BCM_TCS_CMD(1, 1, 0, value) | (1U << 31);
}
#define MAX_PERF_LEVEL_PER_VCD 8
#define MAX_CRM_SW_DRV_STATE 3
#define CRM_SW_DRV 1
#define pr_err(...) ((void)0)
struct device { int unused; };
struct clk_crm { bool initialized; struct device *dev; };
struct clk_rcg2 {
    struct { struct clk_crm *crm; u32 crm_vcd; } clkr;
    const int *freq_tbl;
};
struct clk_hw { struct clk_rcg2 *rcg; };
struct crm_cmd { union { unsigned sw; } pwr_state; u32 resource_idx, data; bool wait; };
static int errors[3];
static unsigned calls;
static struct clk_rcg2 *to_clk_rcg2(struct clk_hw *hw) { return hw->rcg; }
static int qcom_find_crm_freq_index(const int *table, unsigned long rate)
{ assert(table && rate == 100); return 3; }
static int crm_write_perf_ol(const struct device *dev, unsigned drv, u32 drv_id,
                            const struct crm_cmd *cmd)
{
    assert(dev && drv == CRM_SW_DRV && drv_id == 0);
    assert(cmd->resource_idx == 0 && cmd->data == 3 && cmd->wait);
    assert(cmd->pwr_state.sw == calls && calls < 3);
    return errors[calls++];
}
C
awk '/^static int clk_rcg2_vote_perf_level\(/ {emit=1} emit {print} \
    emit && /^}/ {exit}' "$references/oem571-clk-rcg2.c" >> "$work/oracle.c"
cat >> "$work/oracle.c" <<'C'
int oem_vote(int active, int sleep, int wake, unsigned *count)
{
    struct device device = {0};
    struct clk_crm crm = { .initialized = true, .dev = &device };
    const int table[] = {1};
    struct clk_rcg2 rcg = { .clkr = { .crm = &crm, .crm_vcd = 0 }, .freq_tbl = table };
    struct clk_hw hw = { .rcg = &rcg };
    int result;
    calls = 0; errors[0] = active; errors[1] = sleep; errors[2] = wake;
    result = clk_rcg2_vote_perf_level(&hw, 100);
    *count = calls;
    return result;
}
C
[[ $(grep -c '^static inline u32 crm_get_offset(' "$work/oracle.c") == 1 ]]
[[ $(grep -c '^static int clk_rcg2_vote_perf_level(' "$work/oracle.c") == 1 ]]
[[ $(grep -c '^static u32 sw_drv_.*_regs\[\] = {' "$work/oracle.c") == 2 ]]
include=(-I"$work/include" -I"$project/src/camera/provider" -I"$references")
flags=(-Wall -Wextra -Werror -O1 -g "${extra[@]}")
"$cc" -std=gnu11 "${flags[@]}" "${include[@]}" -c "$work/oracle.c" -o "$work/oracle.o"
# Also compile the production header as C, independently of the C++ harness.
printf '#include "camcc-sm7675-crm-core.h"\n' > "$work/header.c"
"$cc" -std=gnu11 "${flags[@]}" "${include[@]}" -c "$work/header.c" -o "$work/header.o"
"$cxx" -std=c++17 "${flags[@]}" "${include[@]}" \
    "$project/tests/fixtures/camera-crm-core-check.cpp" "$work/oracle.o" -o "$work/check"
"$work/check"
ulimit -c 0
if ("$work/check" --oem-negative > "$work/negative.log" 2>&1) 2>/dev/null; then
    printf 'OEM first-error negative control incorrectly passed\n' >&2
    exit 1
else
    rc=$?
fi
[[ $rc == 134 ]]
grep -q 'result == -EIO && calls == 1' "$work/negative.log"
printf 'Actual OEM three-state error-overwrite negative control reproduced assertion134\n'
if [[ ${CAMERA_CRM_MUTATIONS:-0} == 1 ]]; then
    mkdir -p "$work/override"
    for mutation in ignore-early-error permit-poison-retry clear-zero-valid own-unmapped-vcd; do
        case $mutation in
            ignore-early-error)
                sed 's/if (ret) {/if (ret \&\& i == CAM_CC_CRM_WAKE) {/' \
                    "$project/src/camera/provider/camcc-sm7675-crm-core.h";;
            permit-poison-retry)
                sed 's/vote->poisoned = true;/vote->poisoned = false;/' \
                    "$project/src/camera/provider/camcc-sm7675-crm-core.h";;
            clear-zero-valid)
                sed 's/(1U << 29) |/(value ? (1U << 29) : 0) |/' \
                    "$project/src/camera/provider/camcc-sm7675-crm-core.h";;
            own-unmapped-vcd)
                sed 's/resource < 8 \&\& resource != 5/resource < 8/' \
                    "$project/src/camera/provider/camcc-sm7675-crm-core.h";;
        esac > "$work/override/camcc-sm7675-crm-core.h"
        if cmp -s "$project/src/camera/provider/camcc-sm7675-crm-core.h" \
                  "$work/override/camcc-sm7675-crm-core.h"; then
            printf 'Mutation did not change source: %s\n' "$mutation" >&2; exit 1
        fi
        "$cxx" -std=c++17 "${flags[@]}" -I"$work/override" "${include[@]}" \
            "$project/tests/fixtures/camera-crm-core-check.cpp" "$work/oracle.o" -o "$work/mutant"
        if ("$work/mutant" > "$work/mutant.log" 2>&1) 2>/dev/null; then
            printf 'CRM mutation survived: %s\n' "$mutation" >&2; exit 1
        else
            rc=$?
        fi
        [[ $rc == 134 ]]
    done
    printf 'All4 early-error, poison, zero-vote and ownership mutants refused\n'
fi

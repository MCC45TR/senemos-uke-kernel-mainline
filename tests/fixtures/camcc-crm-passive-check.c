// SPDX-License-Identifier: GPL-2.0-only
/* Actual passive attachment; powered register and CCF boundaries are modeled. */
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
typedef uint32_t u32;
typedef uint64_t u64;
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#define BIT(n) (1U << (n))
#define READ_ONCE(x) (x)
#define __maybe_unused
#define container_of(p, t, m) ((t *)((char *)(p) - offsetof(t, m)))
#define CLK_SET_RATE_PARENT BIT(2)
#define CLK_GET_RATE_NOCACHE BIT(3)
enum { PLL_OFF_L_VAL, PLL_OFF_ALPHA_VAL, PLL_OFF_USER_CTL };
static const unsigned char regs[] = {4, 8, 12};
struct clk_hw { int unused; };
struct clk_ops {
	int (*prepare)(struct clk_hw *);
	void (*unprepare)(struct clk_hw *);
	int (*enable)(struct clk_hw *);
	void (*disable)(struct clk_hw *);
	int (*is_enabled)(struct clk_hw *);
	int (*set_rate)(struct clk_hw *, unsigned long, unsigned long);
	unsigned long (*recalc_rate)(struct clk_hw *, unsigned long);
};
struct clk_regmap { struct clk_hw hw; u32 enable_reg, enable_mask; bool enable_is_inverted; };
struct clk_div_table { unsigned val, div; };
static const struct clk_div_table div_table[] = {{1, 2}, {0, 0}};
struct clk_alpha_pll { u32 offset; const unsigned char *regs; struct clk_regmap clkr; };
struct clk_alpha_pll_postdiv {
	u32 offset, post_div_shift, width, num_post_div;
	const unsigned char *regs;
	const struct clk_div_table *post_div_table;
	struct clk_regmap clkr;
};
struct clk_branch { u32 halt_reg; struct clk_regmap clkr; };
static const struct clk_ops clk_alpha_pll_lucid_evo_ops = {0};
static const struct clk_ops clk_alpha_pll_postdiv_lucid_ole_ops = {0};
static const struct clk_ops clk_branch2_ops = {0};
struct clk_init_data { unsigned long flags; };
struct cam_cc_crm_clock { int unused; };
struct cam_cc_clock {
	struct clk_regmap *clock;
	const struct clk_ops *native;
	struct clk_ops ops;
	struct clk_init_data init;
	bool prepared, voted;
	struct cam_cc_crm_clock *crm;
	bool crm_passive;
	int (*disable_check)(struct cam_cc_clock *);
};
/* Independent pinned OEM declarations generate these objects. */
#include "passive-catalog.h"
static struct cam_cc_clock states[30];
static struct { void *map; bool publication_started, fault; } cam_cc_power;
static bool cam_cc_clocks_ready, powered;
static unsigned reads, fail_read, attaches;
static int ccf_error;
static u32 words[0x16000 / 4];
static struct cam_cc_clock *cam_cc_clock_find(struct clk_hw *hw)
{
	for (unsigned i = 0; i < ARRAY_SIZE(states); i++)
		if (states[i].clock && &states[i].clock->hw == hw) return &states[i];
	return NULL;
}
static int cam_cc_power_access(void *context, unsigned offset)
{
	assert(context == &cam_cc_power && offset == 0);
	return cam_cc_power.fault ? -EIO : powered ? 0 : -EHOSTDOWN;
}
static int regmap_read(void *map, u32 offset, u32 *value)
{
	assert(map == words && powered && !(offset & 3) && offset < sizeof(words));
	reads++;
	if (fail_read && reads == fail_read) return -EIO;
	*value = words[offset / 4];
	return 0;
}
static int cam_cc_clock_fail(int error, unsigned uncertain)
{
	assert(error < 0 && !uncertain);
	cam_cc_power.fault = true;
	return -EIO;
}
static int cam_cc_crm_ccf_attach(struct cam_cc_crm_clock clients[8])
{
	assert(clients);
	attaches++;
	return ccf_error;
}
#include "passive.h"

static int forbidden(struct clk_hw *hw) { (void)hw; assert(!"native write callback"); return -EIO; }
static void forbidden_void(struct clk_hw *hw) { (void)forbidden(hw); }
static int forbidden_rate(struct clk_hw *hw, unsigned long r, unsigned long p)
{ (void)r; (void)p; return forbidden(hw); }
static int disable_check(struct cam_cc_clock *c) { (void)c; assert(!"native disable check"); return -EIO; }
static void reset(void)
{
	memset(states, 0, sizeof(states));
	memset(words, 0, sizeof(words));
	memset(cam_cc_crm_passive_cache, 0, sizeof(cam_cc_crm_passive_cache));
	cam_cc_power.map = words;
	cam_cc_power.publication_started = cam_cc_power.fault = false;
	cam_cc_clocks_ready = powered = true;
	cam_cc_crm_passive_attached = false;
	reads = fail_read = attaches = 0; ccf_error = 0;
	reset_catalog();
	assert(ARRAY_SIZE(cam_cc_crm_passive) == 30);
	for (unsigned i = 0; i < 30; i++) {
		states[i].clock = oracle[i].clock;
		states[i].native = oracle[i].ops;
		states[i].ops = (struct clk_ops){
			.prepare=forbidden, .unprepare=forbidden_void,
			.enable=forbidden, .disable=forbidden_void, .set_rate=forbidden_rate,
		};
		states[i].init.flags = CLK_SET_RATE_PARENT;
		states[i].disable_check = disable_check;
		if (oracle[i].kind == 0) {
			words[(oracle[i].offset + 4) / 4] = 0x21;
			words[(oracle[i].offset + 8) / 4] = 0xf555;
			words[oracle[i].offset / 4] = 1;
		} else if (oracle[i].kind == 1) {
			words[(oracle[i].offset + 12) / 4] = 1 << 10;
		} else words[oracle[i].offset / 4] = 1;
	}
}
static void unchanged(void)
{
	for (unsigned i = 0; i < 30; i++) {
		assert(!states[i].crm_passive);
		assert(states[i].ops.enable == forbidden);
		assert(states[i].ops.set_rate == forbidden_rate);
	}
	assert(!cam_cc_crm_passive_attached);
}
int main(void)
{
	struct cam_cc_crm_clock clients[8] = {{0}};
	u64 rate = 123;
	assert(!cam_cc_crm_passive_pll_rate(19200000, 0x21, 0xf555, &rate) && rate == 652000000);
	assert(!cam_cc_crm_passive_pll_rate(19200000, 104, 0x2aaa, &rate) && rate == 2000000000);
	assert(cam_cc_crm_passive_pll_rate(19200000, 105, 0, &rate) == -ERANGE);
	assert(cam_cc_crm_passive_pll_rate(24000000, 33, 0, &rate) == -EINVAL);
	assert(cam_cc_crm_passive_pll_rate(19200000, 0, 0, &rate) == -EINVAL);
	assert(cam_cc_crm_passive_pll_rate(19200000, 33, 0x10000, &rate) == -EINVAL);
	reset(); cam_cc_clocks_ready = false;
	assert(cam_cc_crm_managed_attach(clients) == -EINVAL && !reads && !attaches); unchanged();
	reset(); cam_cc_power.publication_started = true;
	assert(cam_cc_crm_managed_attach(clients) == -EINVAL && !reads && !attaches); unchanged();
	reset(); powered = false;
	assert(cam_cc_crm_managed_attach(clients) == -EHOSTDOWN && !reads && !attaches); unchanged();
	for (unsigned i = 0; i < 30; i++) {
		reset(); states[i].prepared = true;
		assert(cam_cc_crm_managed_attach(clients) == -EINVAL && !reads && !attaches); unchanged();
		reset(); states[i].native = NULL;
		assert(cam_cc_crm_managed_attach(clients) == -EINVAL && !reads && !attaches); unchanged();
	}
	reset(); assert(!cam_cc_crm_managed_attach(clients));
	unsigned total_reads = reads;
	assert(total_reads == 40 && attaches == 1);
	for (unsigned fail = 1; fail <= total_reads; fail++) {
		reset(); fail_read = fail;
		assert(cam_cc_crm_managed_attach(clients) == -EIO && reads == fail && !attaches); unchanged();
	}
	reset(); ccf_error = -ERANGE;
	assert(cam_cc_crm_managed_attach(clients) == -ERANGE && attaches == 1); unchanged();
	for (unsigned i = 1; i < 10; i += 2) {
		reset(); words[(oracle[i].offset + 12) / 4] = 0;
		assert(cam_cc_crm_managed_attach(clients) == -EOPNOTSUPP && !attaches); unchanged();
	}
	reset(); assert(!cam_cc_crm_managed_attach(clients));
	for (unsigned i = 0; i < 30; i++) {
		struct cam_cc_clock *c = &states[i];
		assert(c->crm_passive && !c->ops.enable && !c->ops.disable && !c->ops.prepare &&
			!c->ops.unprepare && !c->ops.set_rate && !c->disable_check);
		assert(!!(c->init.flags & CLK_SET_RATE_PARENT) == (oracle[i].kind == 2));
		unsigned long r = c->ops.recalc_rate(&c->clock->hw, 652000000);
		assert(r == (oracle[i].kind == 1 ? 326000000 : 652000000));
		if (c->ops.is_enabled) assert(c->ops.is_enabled(&c->clock->hw) == 1);
		unsigned old_reads = reads; powered = false;
		assert(c->ops.recalc_rate(&c->clock->hw, 652000000) == r && reads == old_reads);
		if (c->ops.is_enabled) assert(c->ops.is_enabled(&c->clock->hw) == 1 && reads == old_reads);
		powered = true;
	}
	assert(cam_cc_crm_managed_attach(clients) == -EINVAL);
	reset(); assert(!cam_cc_crm_managed_attach(clients)); fail_read = reads + 1;
	assert(!states[0].ops.recalc_rate(&states[0].clock->hw, 19200000) && cam_cc_power.fault);
	puts("Actual CRM passive attachment: all30 OEM objects,40 read faults, atomic refusal, no native writes, asleep no-MMIO and rate propagation passed");
	return 0;
}

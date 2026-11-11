// SPDX-License-Identifier: GPL-2.0-only
/* Actual CCF adapter; framework topology is modeled, no MMIO or kernel execution. */
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
typedef uint8_t u8;
typedef uint32_t u32;
typedef uint64_t u64;
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#define READ_ONCE(x) (x)
#define CLK_SET_RATE_PARENT 4UL
#define CLK_HOLD_STATE 16UL
#define CLK_GET_RATE_NOCACHE 32UL
#define __maybe_unused
struct clk_hw { unsigned long rate; struct clk_hw *parents[2]; };
struct clk_rate_request {
	unsigned long rate, min_rate, max_rate, best_parent_rate;
	struct clk_hw *best_parent_hw;
};
struct clk_ops {
	int (*prepare)(struct clk_hw *);
	void (*unprepare)(struct clk_hw *);
	int (*enable)(struct clk_hw *);
	void (*disable)(struct clk_hw *);
	int (*is_enabled)(struct clk_hw *);
	int (*init)(struct clk_hw *);
	int (*set_rate_and_parent)(struct clk_hw *, unsigned long, unsigned long, u8);
	int (*set_parent)(struct clk_hw *, u8);
	u8 (*get_parent)(struct clk_hw *);
	unsigned long (*recalc_rate)(struct clk_hw *, unsigned long);
	int (*determine_rate)(struct clk_hw *, struct clk_rate_request *);
};
struct clk_init_data { u8 num_parents; unsigned long flags; };
struct clk_regmap { struct clk_hw hw; };
struct parent_map { u32 cfg; };
struct clk_rcg2 { struct clk_regmap clkr; const struct parent_map *parent_map; };
static struct clk_rcg2 cam_cc_ife_0_clk_src, cam_cc_ife_1_clk_src, cam_cc_ife_2_clk_src;
static struct clk_rcg2 cam_cc_sfe_0_clk_src, cam_cc_sfe_1_clk_src, cam_cc_csid_clk_src;
static struct clk_rcg2 cam_cc_cphy_rx_clk_src, cam_cc_camnoc_axi_rt_clk_src;
static const struct clk_ops clk_rcg2_shared_ops = {0};
#include "camcc-sm7675-crm-clock.h"
#include "ccf-clock-state.h"
static struct cam_cc_clock clocks[8];
static struct { bool fault, publication_started; } cam_cc_power;
static bool cam_cc_clocks_ready, powered;
static int accesses, sends;
static struct clk_hw parents[2];
static const struct parent_map parent_map[] = {{0}, {6}};
static struct cam_cc_crm_lut table = {
	.rates = {{100000000, 0}, {200000000, 6}, {400000000, 6}}, .count = 3,
};
static struct cam_cc_clock *cam_cc_clock_find(struct clk_hw *hw)
{
	for (unsigned i = 0; i < 8; i++) if (&clocks[i].clock->hw == hw) return &clocks[i];
	return NULL;
}
static struct clk_rcg2 *to_clk_rcg2(struct clk_hw *hw) { return (struct clk_rcg2 *)hw; }
static int cam_cc_power_access(void *context, unsigned reg)
{
	assert(context == &cam_cc_power && reg == 0); accesses++;
	return powered ? 0 : -EHOSTDOWN;
}
static int cam_cc_clock_access(struct cam_cc_clock *clock)
{ return !clock ? -ENODEV : cam_cc_power.fault ? -EIO : cam_cc_power_access(&cam_cc_power, 0); }
static int cam_cc_clock_fail(int error, unsigned uncertain)
{ assert(error < 0 && uncertain == 0); cam_cc_power.fault = true; return -EIO; }
static struct clk_hw *clk_hw_get_parent_by_index(struct clk_hw *hw, unsigned index)
{ return index < 2 ? hw->parents[index] : NULL; }
static unsigned long clk_hw_get_rate(struct clk_hw *hw) { return hw->rate; }
static int send_vote(void *context, u32 kind, u32 resource, u32 value)
{ (void)context; (void)kind; (void)resource; (void)value; sends++; return 0; }
#include "crm-ccf.h"

static void reset(struct cam_cc_crm_clock clients[8])
{
	memset(clocks, 0, sizeof(clocks));
	memset(clients, 0, 8 * sizeof(*clients));
	cam_cc_power.fault = cam_cc_power.publication_started = false;
	cam_cc_clocks_ready = powered = true;
	accesses = sends = 0;
	parents[0].rate = 19200000; parents[1].rate = 300000000;
	for (unsigned i = 0; i < 8; i++) {
		struct clk_rcg2 *rcg = cam_cc_crm_rcgs[i].rcg;
		rcg->parent_map = parent_map;
		rcg->clkr.hw.parents[0] = &parents[0]; rcg->clkr.hw.parents[1] = &parents[1];
		clocks[i].clock = &rcg->clkr;
		clocks[i].native = &clk_rcg2_shared_ops;
		clocks[i].init.num_parents = 2;
		clocks[i].init.flags = CLK_SET_RATE_PARENT | CLK_HOLD_STATE | CLK_GET_RATE_NOCACHE;
		clients[i] = (struct cam_cc_crm_clock) {
			.table = &table, .send = send_vote, .kind = cam_cc_crm_rcgs[i].kind,
			.resource = cam_cc_crm_rcgs[i].resource, .desired = 200000000,
		};
	}
}

int main(void)
{
	struct cam_cc_crm_clock clients[8];
	for (unsigned invalid = 0; invalid < 6; invalid++) {
		reset(clients);
		if (invalid == 0) cam_cc_clocks_ready = false;
		if (invalid == 1) cam_cc_power.publication_started = true;
		if (invalid == 2) powered = false;
		if (invalid == 3) clients[7].resource = 1;
		if (invalid == 4) clients[7].desired = 200000001;
		if (invalid == 5) table.rates[2].source = 7;
		assert(cam_cc_crm_ccf_attach(clients) < 0);
		for (unsigned i = 0; i < 8; i++) assert(!clocks[i].crm);
		table.rates[2].source = 6;
	}
	reset(clients);
	assert(cam_cc_crm_ccf_attach(clients) == 0 && sends == 0);
	powered = false; /* Cached queries must not acquire PM or read hardware. */
	int before = accesses;
	for (unsigned i = 0; i < 8; i++) {
		struct clk_hw *hw = &clocks[i].clock->hw;
		const struct clk_ops *ops = &clocks[i].ops;
		assert(!ops->enable && !ops->disable && !ops->is_enabled && !ops->init && !ops->set_rate_and_parent);
		assert(clocks[i].init.flags == (CLK_HOLD_STATE | CLK_GET_RATE_NOCACHE));
		assert(ops->recalc_rate(hw, 999999999) == 200000000 && ops->get_parent(hw) == 1);
		struct clk_rate_request req = {.rate = 100000001, .max_rate = 400000000};
		assert(ops->determine_rate(hw, &req) == 0 && req.rate == 200000000);
		assert(req.best_parent_hw == &parents[1] && req.best_parent_rate == parents[1].rate);
		req = (struct clk_rate_request){.rate = 200000000, .max_rate = 199999999};
		assert(ops->determine_rate(hw, &req) == -ERANGE);
		req = (struct clk_rate_request){.rate = 1, .min_rate = 200000000, .max_rate = 400000000};
		assert(ops->determine_rate(hw, &req) == -ERANGE);
		hw->parents[1] = NULL;
		req = (struct clk_rate_request){.rate = 200000000, .max_rate = 400000000};
		assert(ops->determine_rate(hw, &req) == -ENODEV);
		hw->parents[1] = &parents[1];
	}
	assert(accesses == before && sends == 0);
	powered = true;
	assert(cam_cc_crm_ccf_set_parent(&clocks[0].clock->hw, 1) == -EIO);
	cam_cc_power.fault = false;
	clients[0].staged = true; clients[0].new_rate = 100000000;
	assert(cam_cc_crm_ccf_set_parent(&clocks[0].clock->hw, 0) == 0);
	assert(cam_cc_crm_ccf_set_parent(&clocks[0].clock->hw, 1) == -EIO && sends == 0);
	puts("CRM CCF adapter: all8 clients, complete preflight, software rate/parent cache, bounds and no-write topology pass");
	return 0;
}

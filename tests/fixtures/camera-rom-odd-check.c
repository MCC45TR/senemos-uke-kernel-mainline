// SPDX-License-Identifier: GPL-2.0-only
/* Production resolver; model only the powered regmap and unpublished catalog. */
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
typedef uint32_t u32;
typedef uint64_t u64;
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#define BIT(n) (1U << (n))
#define __maybe_unused __attribute__((unused))
#define container_of(p,t,m) ((t *)((char *)(p) - offsetof(t,m)))
#include "camcc-sm7675-crm-lut.h"

struct clk_hw { unsigned unused; };
struct clk { u64 rate; };
struct clk_ops { unsigned unused; };
static const struct clk_ops clk_alpha_pll_lucid_evo_ops = {1};
static const struct clk_ops clk_alpha_pll_postdiv_lucid_ole_ops = {2};
enum { DT_IFACE, DT_BI_TCXO };
struct clk_parent_data { const struct clk_hw *hw; const char *fw_name; unsigned index; };
struct clk_init_data {
	unsigned num_parents;
	const struct clk_parent_data *parent_data;
	const struct clk_hw **parent_hws;
};
struct clk_regmap { struct clk_hw hw; };
struct clk_alpha_pll { u32 offset; const unsigned char *regs; struct clk_regmap clkr; };
struct clk_div_table { unsigned val, div; };
struct clk_alpha_pll_postdiv {
	u32 offset, post_div_shift, width, num_post_div;
	const unsigned char *regs;
	const struct clk_div_table *post_div_table;
	struct clk_regmap clkr;
};
struct parent_map { unsigned src, cfg; };
struct clk_rcg2 { struct clk_regmap clkr; struct parent_map *parent_map; };
struct cam_cc_clock {
	struct clk_regmap *clock;
	const struct clk_ops *native;
	struct clk_init_data init;
	bool prepared, voted;
	void *crm;
};
enum { PLL_OFF_L_VAL, PLL_OFF_ALPHA_VAL, PLL_OFF_USER_CTL };
static const unsigned char regs[] = {4,8,12};
static const struct clk_div_table divisors[] = {{1,2},{2,3},{0,0}};
#include "actual-postdiv-tables.h"
static struct clk_alpha_pll pll = {.offset=0x3000,.regs=regs};
static struct clk_alpha_pll_postdiv divider = {
	.offset=0x3000,.post_div_shift=10,.width=4,.num_post_div=ARRAY_SIZE(divisors),
	.regs=regs,.post_div_table=divisors,
};
static struct clk_rcg2 rcgs[8];
static const struct {
	struct clk_rcg2 *rcg;
	u32 kind,resource;
} cam_cc_crm_rcgs[] = {
	{&rcgs[0],CAM_CC_CRM_PERF,0},{&rcgs[1],CAM_CC_CRM_PERF,1},
	{&rcgs[2],CAM_CC_CRM_PERF,2},{&rcgs[3],CAM_CC_CRM_PERF,3},
	{&rcgs[4],CAM_CC_CRM_PERF,4},{&rcgs[5],CAM_CC_CRM_PERF,6},
	{&rcgs[6],CAM_CC_CRM_PERF,7},{&rcgs[7],CAM_CC_CRM_BW,0},
};
static struct parent_map mapping[] = {{0,0},{1,1},{2,6}};
static struct clk_parent_data parents[] = {
	{.index=DT_BI_TCXO},{.hw=&pll.clkr.hw},{.hw=&divider.clkr.hw},
};
static const struct clk_parent_data pll_parent = {.index=DT_BI_TCXO};
static const struct clk_hw *divider_parent[] = {&pll.clkr.hw};
static struct clk xo = {19200000};
static struct {struct clk *parents[1];} cam_cc_native;
static struct {bool publication_started; void *map;} cam_cc_power;
static struct cam_cc_clock clocks[10];
static bool cam_cc_clocks_ready, powered;
static unsigned reads, fail_read, rom_reads, fail_rom_read, expected_vcd;
static u32 live_l, live_alpha, live_div, raw_user_ctl;
static bool use_raw_user_ctl;

static struct cam_cc_clock *cam_cc_clock_find(struct clk_hw *hw)
{
	for (unsigned i=0;i<ARRAY_SIZE(clocks);i++)
		if (clocks[i].clock && &clocks[i].clock->hw==hw) return &clocks[i];
	return NULL;
}
static int cam_cc_power_access(void *p,unsigned unused)
{ (void)p;(void)unused;return powered?0:-EHOSTDOWN; }
static u64 clk_get_rate(struct clk *clock) {return clock->rate;}
static int regmap_read(void *map,u32 offset,u32 *value)
{
	(void)map;assert(powered);++reads;
	if (reads==fail_read) return -EREMOTEIO;
	switch(offset) {
	case 0x3004:*value=live_l;break;
	case 0x3008:*value=live_alpha;break;
	case 0x300c:*value=use_raw_user_ctl?raw_user_ctl:live_div<<10;break;
	default:assert(false);
	}
	return 0;
}
/* Extracted byte-for-byte from the already qualified production passive code. */
#include "passive-pll.h"
#include "rom.h"

static void reset(void)
{
	memset(clocks,0,sizeof(clocks));
	for (unsigned i=0;i<8;i++) {
		rcgs[i].parent_map=mapping;
		clocks[i].clock=&rcgs[i].clkr;
		clocks[i].init=(struct clk_init_data){.num_parents=3,.parent_data=parents};
	}
	clocks[8]=(struct cam_cc_clock){.clock=&pll.clkr,.native=&clk_alpha_pll_lucid_evo_ops,
		.init={.num_parents=1,.parent_data=&pll_parent}};
	clocks[9]=(struct cam_cc_clock){.clock=&divider.clkr,.native=&clk_alpha_pll_postdiv_lucid_ole_ops,
		.init={.num_parents=1,.parent_hws=divider_parent}};
	cam_cc_native.parents[0]=&xo;xo.rate=19200000;
	cam_cc_clocks_ready=powered=true;cam_cc_power.publication_started=false;
	reads=fail_read=rom_reads=fail_rom_read=0;
	live_l=51;live_alpha=0x4000;live_div=1;use_raw_user_ctl=false;raw_user_ctl=0;
	divider.post_div_shift=10;divider.post_div_table=divisors;divider.num_post_div=ARRAY_SIZE(divisors);
	mapping[2].cfg=6;parents[2].fw_name=NULL;
	parents[0].index=DT_BI_TCXO;
}
static int read_rom(void *context,u32 offset,u32 *value)
{
	assert(context==&expected_vcd);assert(powered);
	unsigned slot=rom_reads/2;assert(slot<7);
	assert(offset==(rom_reads%2?0x138U:0x110U)+expected_vcd*0x200+(slot+1)*4);
	++rom_reads;if (rom_reads==fail_rom_read)return -EREMOTEIO;
	*value=rom_reads%2?(1U<<8)|1:20+slot;
	return 0;
}
int main(void)
{
	struct cam_cc_crm_rom_context rom={.rcg=&rcgs[0]};
	u64 rate;
	reset();assert(!cam_cc_crm_rom_parent(&rom,0,0,0xffff,&rate)&&rate==19200000&&!reads);
	assert(!cam_cc_crm_rom_parent(&rom,1,40,0xffff,&rate)&&rate==787200000&&!reads);
	assert(!cam_cc_crm_rom_parent(&rom,6,40,0xffff,&rate)&&rate==393600000&&reads==1);
	reset();assert(!cam_cc_crm_rom_parent(&rom,6,0,0xffff,&rate)&&rate==492000000&&reads==3);
	reset();live_div=2;
	assert(!cam_cc_crm_rom_parent(&rom,6,41,1,&rate)&&rate==262400333&&reads==1);
	/* Same raw USER_CTL contains different valid even and odd fields. */
	assert(ACTUAL_EVEN_SHIFT==10 && ACTUAL_ODD_SHIFT==14);
	reset();use_raw_user_ctl=true;raw_user_ctl=(1U<<10)|(2U<<14);
	divider.post_div_shift=ACTUAL_EVEN_SHIFT;
	divider.post_div_table=post_div_table_cam_cc_pll0_out_even;
	divider.num_post_div=ARRAY_SIZE(post_div_table_cam_cc_pll0_out_even);
	assert(!cam_cc_crm_rom_parent(&rom,6,40,0xffff,&rate)&&rate==393600000&&reads==1);
	reset();use_raw_user_ctl=true;raw_user_ctl=(1U<<10)|(2U<<14);
	divider.post_div_shift=ACTUAL_ODD_SHIFT;
	divider.post_div_table=post_div_table_cam_cc_pll0_out_odd;
	divider.num_post_div=ARRAY_SIZE(post_div_table_cam_cc_pll0_out_odd);
	assert(!cam_cc_crm_rom_parent(&rom,6,41,1,&rate)&&rate==262400333&&reads==1);
	reset();divider.post_div_shift=12;rate=123;
	assert(cam_cc_crm_rom_parent(&rom,6,40,0,&rate)==-EINVAL&&rate==123&&!reads);
	for(unsigned fault=1;fault<=3;fault++) {
		reset();fail_read=fault;rate=123;
		assert(cam_cc_crm_rom_parent(&rom,6,0,0,&rate)==-EREMOTEIO&&rate==123&&reads==fault);
	}
	reset();live_div=7;rate=123;
	assert(cam_cc_crm_rom_parent(&rom,6,40,0,&rate)==-EOPNOTSUPP&&rate==123);
	reset();mapping[2].cfg=1;rate=123;
	assert(cam_cc_crm_rom_parent(&rom,1,40,0,&rate)==-EINVAL&&rate==123&&!reads);
	reset();parents[2].fw_name="ambiguous";rate=123;
	assert(cam_cc_crm_rom_parent(&rom,6,40,0,&rate)==-EINVAL&&rate==123&&!reads);
	reset();powered=false;rate=123;
	assert(cam_cc_crm_rom_parent(&rom,1,40,0,&rate)==-EHOSTDOWN&&rate==123&&!reads);
	reset();cam_cc_power.publication_started=true;rate=123;
	assert(cam_cc_crm_rom_parent(&rom,1,40,0,&rate)==-EINVAL&&rate==123&&!reads);
	reset();xo.rate=24000000;rate=123;
	assert(cam_cc_crm_rom_parent(&rom,1,40,0,&rate)==-EINVAL&&rate==123&&!reads);
	reset();cam_cc_native.parents[0]=NULL;rate=123;
	assert(cam_cc_crm_rom_parent(&rom,0,0,0,&rate)==-EINVAL&&rate==123&&!reads);
	reset();rate=123;
	assert(cam_cc_crm_rom_parent(&rom,3,40,0,&rate)==-EINVAL&&rate==123&&!reads);
	assert(cam_cc_crm_rom_parent(&rom,1,256,0,&rate)==-EINVAL&&rate==123&&!reads);
	assert(cam_cc_crm_rom_parent(&rom,1,40,65536,&rate)==-EINVAL&&rate==123&&!reads);
	assert(cam_cc_crm_rom_parent(&rom,0,1,0,&rate)==-EINVAL&&rate==123&&!reads);
	reset();parents[0].index=DT_IFACE;rate=123;
	assert(cam_cc_crm_rom_parent(&rom,0,0,0,&rate)==-EINVAL&&rate==123&&!reads);
	for(unsigned client=0;client<8;client++) {
		struct cam_cc_crm_lut table, before;
		reset();expected_vcd=client==7?8:cam_cc_crm_rcgs[client].resource;
		assert(!cam_cc_crm_rom_load(client,read_rom,&expected_vcd,&table));
		assert(table.count==7&&table.rates[0].hz==384000000&&table.rates[6].hz==499200000);
		assert(rom_reads==14&&!reads);
		for(unsigned fault=1;fault<=14;fault++) {
			reset();fail_rom_read=fault;memset(&table,0x53,sizeof(table));before=table;
			assert(cam_cc_crm_rom_load(client,read_rom,&expected_vcd,&table)==-EREMOTEIO);
			assert(!memcmp(&table,&before,sizeof(table))&&rom_reads==fault);
		}
	}
	reset();struct cam_cc_crm_lut table;
	assert(cam_cc_crm_rom_load(8,read_rom,&expected_vcd,&table)==-EINVAL&&!rom_reads);
	assert(cam_cc_crm_rom_load(0,NULL,&expected_vcd,&table)==-EINVAL&&!rom_reads);
	puts("PASS: camera odd ROM: actual even/odd catalog tables and separate register fields, exact rounding, unknown-shift refusal and all 112 retained ROM faults; no hardware");
	return 0;
}

#!/usr/bin/env bash
# Host fault controls for the actual prepared-kernel set-rate operation.
set -Eeuo pipefail
kernel=${1:?Pass prepared kernel}
work=$(mktemp -d); trap 'rm -r -- "$work"' EXIT
{
cat <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <errno.h>
typedef uint32_t u32;
typedef uint64_t u64;
enum { CLK_ALPHA_PLL_TYPE_TRION, CLK_ALPHA_PLL_TYPE_LUCID_5LPE,
 CLK_ALPHA_PLL_TYPE_LUCID_EVO, CLK_ALPHA_PLL_TYPE_LUCID_OLE };
static const unsigned char clk_alpha_pll_regs[4][3]={{0},{1},{2},{3}};
#define PLL_RESET_N (1U<<2)
#define LUCID_EVO_PLL_L_VAL_MASK 0xffffU
#define PLL_MODE(p) 0
#define PLL_L_VAL(p) 1
#define PLL_ALPHA_VAL(p) 2
enum { latch=1U<<14, ack=1U<<13 };
struct regmap { u32 reg[3]; };
struct clk_alpha_pll { struct { struct regmap *regmap; } clkr; const unsigned char *regs; };
struct clk_hw { struct clk_alpha_pll *pll; bool enabled; };
#define to_clk_alpha_pll(hw) ((hw)->pll)
static unsigned latch_sets,latch_clears,locks,delays,warnings,reads;
static bool acknowledge;
static int margin_error,read_error,set_error,clear_error,lock_error,l_error,alpha_error;
static unsigned pll_alpha_width(struct clk_alpha_pll *p) { assert(p);return 16; }
static unsigned long alpha_pll_round_rate(unsigned long rate,unsigned long parent,u32 *l,u64 *a,unsigned width) {
 assert(parent==19200000 && width==16);*l=23;*a=123;return rate;
}
static int alpha_pll_check_rate_margin(struct clk_hw *hw,unsigned long rounded,unsigned long rate) {
 assert(hw && rounded==rate);return margin_error;
}
static int regmap_update_bits(struct regmap *m,unsigned offset,u32 mask,u32 value) {
 assert(offset<3);
 if(offset==1 && l_error)return l_error;
 if(!offset && value==latch) { latch_sets++;if(set_error)return set_error; }
 if(!offset && value==0) { latch_clears++;if(clear_error)return clear_error; }
 m->reg[offset]=(m->reg[offset]&~mask)|(value&mask);
 if(!offset && value==latch && acknowledge)m->reg[0]|=ack;
 return 0;
}
static int regmap_write(struct regmap *m,unsigned offset,u32 value) { assert(offset==2);if(alpha_error)return alpha_error;m->reg[offset]=value;return 0; }
static int regmap_read(struct regmap *m,unsigned offset,u32 *value) {
 assert(!offset);reads++;if(read_error)return read_error;*value=m->reg[0];return 0;
}
static bool clk_hw_is_enabled(struct clk_hw *hw) { return hw->enabled; }
static int wait_for_pll_enable_lock(struct clk_alpha_pll *p) { assert(p);locks++;return lock_error; }
static void udelay(unsigned n) { delays+=n; }
#define pr_err(...) (warnings++)
C
awk '/^static int __alpha_pll_trion_set_rate/ {emit=1;found=1} emit {print} emit && /^}/ {exit} END {if(!found)exit 1}' "$kernel/drivers/clk/qcom/clk-alpha-pll.c"
cat <<'C'
static struct regmap registers;
static struct clk_alpha_pll pll;
static struct clk_hw hw;
static void reset(unsigned type,bool out_of_reset) {
 registers=(struct regmap){.reg={out_of_reset ? PLL_RESET_N : 0,0xabcd0000,0}};
 pll=(struct clk_alpha_pll){.clkr={&registers},.regs=clk_alpha_pll_regs[type]};
 hw=(struct clk_hw){.pll=&pll};
 latch_sets=latch_clears=locks=delays=warnings=reads=0;
 margin_error=read_error=set_error=clear_error=lock_error=l_error=alpha_error=0;acknowledge=true;
}
static int run(void) { return __alpha_pll_trion_set_rate(&hw,440000000,19200000,latch,ack); }
int main(void) {
 for(unsigned type=0;type<4;type++)for(unsigned running=0;running<2;running++) {
  reset(type,running);assert(!run());
  bool skip=type>=CLK_ALPHA_PLL_TYPE_LUCID_EVO && !running;
  assert(latch_sets==!skip && latch_clears==!skip && !warnings && !locks);
  assert(delays==(skip ? 100U : 101U));
  assert(registers.reg[1]==0xabcd0017 && registers.reg[2]==123);
  assert(!(registers.reg[0]&latch));
 }
 reset(CLK_ALPHA_PLL_TYPE_LUCID_EVO,false);read_error=-EIO;
 assert(run()==-EIO && !latch_sets && !locks);
 reset(CLK_ALPHA_PLL_TYPE_LUCID_OLE,true);margin_error=-ERANGE;
 assert(run()==-ERANGE && !reads && !latch_sets && registers.reg[1]==0xabcd0000);
 for(unsigned type=0;type<4;type++) {
  reset(type,true);l_error=-EIO;assert(run()==-EIO && !reads && !latch_sets);
  reset(type,true);alpha_error=-EIO;assert(run()==-EIO && !reads && !latch_sets);
  reset(type,true);read_error=-EIO;assert(run()==-EIO && !warnings);
  reset(type,true);acknowledge=false;
  assert(run()==-EINVAL && warnings==1 && latch_sets==1 && !latch_clears);
  reset(type,true);set_error=-EIO;assert(run()==-EIO && !latch_clears);
  reset(type,true);clear_error=-EIO;assert(run()==-EIO && latch_clears==1);
  reset(type,true);hw.enabled=true;assert(!run() && locks==1);
  reset(type,true);hw.enabled=true;lock_error=-ETIMEDOUT;
  assert(run()==-ETIMEDOUT && locks==1 && delays==1);
 }
 return 0;
}
C
} > "$work/check.c"
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror "$work/check.c" -o "$work/check"
"$work/check"
echo 'Actual PLL operation: only EVO/OLE in reset bypass latch ACK; active, legacy, rate-margin and failure paths retain their checks'

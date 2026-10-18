#!/usr/bin/env bash
# Deferred host harness for the actual Qualcomm resume and UTMI helper functions.
set -Eeuo pipefail
kernel=${1:?Pass prepared kernel source}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
{
cat <<'C'
#include <assert.h>
#include <stdbool.h>
#include <errno.h>
struct dwc3_qcom { bool is_suspended, ignore_pipe_clk; int num_clocks, num_ports; void *clks, *dev, *qscratch_base; };
enum { QSCRATCH_GENERAL_CFG, PIPE_UTMI_CLK_DIS=1, PIPE_UTMI_CLK_SEL=2, PIPE3_PHYSTATUS_SW=4,
       PWR_EVNT_LPM_IN_L2_MASK=8, PWR_EVNT_LPM_OUT_L2_MASK=16 };
static unsigned int pwr_evnt_irq_stat_reg[3];
static unsigned int step, bits, selection_calls;
static int clock_error;
#define dev_warn(...) ((void)0)
static bool dwc3_qcom_is_host(struct dwc3_qcom *q) { (void)q; return false; }
static void dwc3_qcom_disable_interrupts(struct dwc3_qcom *q) { (void)q; }
static int clk_bulk_prepare_enable(int n, void *p) { (void)n; (void)p; assert(step++==0); return clock_error; }
static int dwc3_qcom_interconnect_enable(struct dwc3_qcom *q) { (void)q; assert(step++==1); return 0; }
static void dwc3_qcom_setbits(void *base, unsigned int reg, unsigned int mask) {
 (void)base; assert(reg==QSCRATCH_GENERAL_CFG && step>=2); bits|=mask; selection_calls++;
}
static void dwc3_qcom_clrbits(void *base, unsigned int reg, unsigned int mask) {
 (void)base; assert(reg==QSCRATCH_GENERAL_CFG && mask==PIPE_UTMI_CLK_DIS); bits&=~mask;
}
static void usleep_range(unsigned int low, unsigned int high) { assert(low==100 && high==1000); }
C
awk '/^static void dwc3_qcom_select_utmi_clk\(struct dwc3_qcom \*qcom\)$/ {emit=1}
     emit {print} emit && /^}/ {exit}' "$kernel/drivers/usb/dwc3/dwc3-qcom.c"
awk '/^static int dwc3_qcom_resume\(/ {emit=1} emit {print} emit && /^}/ {exit}' \
    "$kernel/drivers/usb/dwc3/dwc3-qcom.c"
cat <<'C'
int main(void) {
 struct dwc3_qcom q={.is_suspended=true,.ignore_pipe_clk=true};
 assert(dwc3_qcom_resume(&q,false)==0 && !q.is_suspended && step==2);
 assert(bits==(PIPE_UTMI_CLK_SEL|PIPE3_PHYSTATUS_SW) && selection_calls==2);
 step=bits=selection_calls=0;
 assert(dwc3_qcom_resume(&q,false)==0 && step==0);
 q.is_suspended=true; q.ignore_pipe_clk=false;
 assert(dwc3_qcom_resume(&q,false)==0 && step==2 && selection_calls==0);
 step=0; clock_error=-EIO; q.is_suspended=q.ignore_pipe_clk=true;
 assert(dwc3_qcom_resume(&q,false)==-EIO && q.is_suspended && step==1 && !selection_calls);
}
C
} > "$work/resume.c"
"${CC:-cc}" -std=gnu11 -Wall -Wextra -Werror "$work/resume.c" -o "$work/resume"
"$work/resume"

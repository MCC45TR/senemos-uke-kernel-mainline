#!/usr/bin/env bash
# Host-only fault controls for the actual Uke CPUCP resource and I/O functions.
set -Eeuo pipefail
kernel=${1:?Pass the prepared kernel source directory}
source=$kernel/drivers/mailbox/qcom-cpucp-mbox.c
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
{
cat <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#define __iomem
#define BIT(n) (1U << (n))
#define IORESOURCE_MEM 0
#define IRQ_HANDLED 1
#define container_of(p,t,m) ((t *)((char *)(p)-offsetof(t,m)))
typedef unsigned int irqreturn_t;
struct mbox_controller;
struct mbox_chan { struct mbox_controller *mbox; void *con_priv; int lock; };
struct mbox_controller { struct mbox_chan *chans; int num_chans; };
struct resource { unsigned long start, end; };
struct platform_device { struct resource *resources[2]; };
static bool uke;
static unsigned char tx[0x10], rx[0x2000];
static unsigned notices[2], barriers, writes;
static struct mbox_chan chans[2];
static bool of_machine_is_compatible(const char *name) { assert(!strcmp(name,"xiaomi,uke")); return uke; }
static struct resource *platform_get_resource(struct platform_device *p,int type,int i) { assert(type==0 && i>=0 && i<2); return p->resources[i]; }
static unsigned long resource_size(struct resource *r) { return r->end-r->start+1; }
static void check_address(const void *p) {
 uintptr_t a=(uintptr_t)p;
 assert((a>=(uintptr_t)tx && a<=(uintptr_t)tx+sizeof(tx)-4) ||
        (a>=(uintptr_t)rx && a<=(uintptr_t)rx+sizeof(rx)-4));
}
static uint32_t readl(const void *p) { uint32_t v; check_address(p); memcpy(&v,p,4); return v; }
static void writel(uint32_t v,void *p) {
 check_address(p); memcpy(p,&v,4); writes++;
 for(unsigned i=0;i<2;i++) if(p==rx+i*0x1000+0x308) {
  uint32_t status=readl(rx+i*0x1000+0x30c)&~v;
  memcpy(rx+i*0x1000+0x30c,&status,4);
 }
}
#define mb() (barriers++)
#define spin_lock_irqsave(p,f) do { (f)=0; assert(!*(p)); *(p)=1; } while(0)
#define spin_unlock_irqrestore(p,f) do { (void)(f); assert(*(p)==1); *(p)=0; } while(0)
static void mbox_chan_received_data(struct mbox_chan *c,void *data) {
 assert(!data && c->lock && c->con_priv); notices[c-chans]++;
}
C
awk '/^#define UKE_CPUCP_/ {print}' "$source"
awk '/^struct qcom_cpucp_mbox \{/ {emit=1} emit {print} emit && /^};/ {exit}' "$source"
awk '/^static bool qcom_cpucp_uke_resources/ {emit=1}
     emit && /^static const struct mbox_chan_ops qcom_cpucp_uke_ops/ {exit}
     emit {print}' "$source"
cat <<'C'
int main(void) {
 struct resource txr={0x17400000,0x1740000f}, rxr={0x17d90000,0x17d91fff};
 struct platform_device p={{&txr,&rxr}};
 uke=true; assert(qcom_cpucp_uke_resources(&p));
 uke=false; assert(!qcom_cpucp_uke_resources(&p)); uke=true;
 for(unsigned i=0;i<2;i++) {
  struct resource *r=p.resources[i]; unsigned long start=r->start,end=r->end;
  p.resources[i]=NULL; assert(!qcom_cpucp_uke_resources(&p)); p.resources[i]=r;
  r->start++; assert(!qcom_cpucp_uke_resources(&p)); r->start=start;
  r->end--; assert(!qcom_cpucp_uke_resources(&p)); r->end=end+1;
  assert(!qcom_cpucp_uke_resources(&p)); r->end=end;
 }
 struct qcom_cpucp_mbox cp={.chans=chans,.tx_base=tx,.rx_base=rx};
 for(unsigned i=0;i<2;i++) chans[i].mbox=&cp.mbox;
 assert(UKE_CPUCP_CHANNELS==2 && qcom_cpucp_uke_startup(&chans[0])==0);
 uint32_t bit=BIT(3); memcpy(rx+0x30c,&bit,4); memcpy(rx+0x130c,&bit,4);
 assert(qcom_cpucp_uke_irq_fn(0,&cp)==IRQ_HANDLED);
 assert(notices[0]==1 && notices[1]==0 && barriers==2 && writes==2);
 qcom_cpucp_uke_irq_fn(0,&cp); assert(notices[0]==1 && writes==2);
 assert(qcom_cpucp_uke_startup(&chans[1])==0);
 for(unsigned i=0;i<2;i++) {
  assert(qcom_cpucp_uke_send_data(&chans[i],NULL)==0);
  assert(readl(tx+0xc)==BIT(28));
 }
 qcom_cpucp_uke_shutdown(&chans[0]); assert(!chans[0].con_priv);
 memcpy(rx+0x30c,&bit,4); memcpy(rx+0x130c,&bit,4);
 qcom_cpucp_uke_irq_fn(0,&cp); assert(notices[0]==1 && notices[1]==1);
 qcom_cpucp_uke_shutdown(&chans[1]); assert(!chans[1].con_priv);
 return 0;
}
C
} > "$work/check.c"
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -Wno-unused-parameter "$work/check.c" -o "$work/check"
"$work/check"
echo 'CPUCP: exact Uke resources and two-channel I/O accepted; foreign/missing/shifted/truncated/oversized resources and unclaimed notifications refused'

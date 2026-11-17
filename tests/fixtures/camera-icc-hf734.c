/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual native functions are included by the contract runner. Hardware is modeled. */
#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <errno.h>
typedef uint64_t u64;
typedef uint32_t u32;
typedef uint16_t u16;
#define ARRAY_SIZE(a) (sizeof(a)/sizeof((a)[0]))
#define BIT(n) (1U<<(n))
#define GENMASK(h,l) (((~0U)>>(31-(h)))&(~0U<<(l)))
#define FIELD_PREP(m,v) (((u32)(v)<<__builtin_ctz(m))&(m))
#define max_t(t,a,b) ((t)(a)>(t)(b)?(t)(a):(t)(b))
#define QCOM_ICC_NUM_BUCKETS 3
#define QCOM_ICC_TAG_ALWAYS 7
#define EXPORT_SYMBOL_GPL(x)
#define le32_to_cpu(x) (x)
#define le16_to_cpu(x) (x)
#define IS_ERR(p) ((uintptr_t)(p)>(uintptr_t)-4096)
#define PTR_ERR(p) ((int)(intptr_t)(p))
#define dev_err(dev,...) ((void)(dev))
#define WARN_ON(v) (v)
struct list_head { int unused; };
#define INIT_LIST_HEAD(p) ((p)->unused=0)
#define list_add_tail(n,h) ((void)(n),(void)(h))
static int icc_lock,icc_bw_lock;
static void mutex_lock(int *l) { assert(!*l);*l=1; }
static void mutex_unlock(int *l) { assert(*l);*l=0; }
struct device { int unused; };
struct icc_node;
struct icc_provider {
 struct list_head nodes;
 void (*get_bw)(struct icc_node *,u32 *,u32 *);
 void (*pre_aggregate)(struct icc_node *);
 int (*aggregate)(struct icc_node *,u32,u32,u32,u32 *,u32 *);
 int (*set)(struct icc_node *,struct icc_node *);
};
struct icc_node {
 struct icc_provider *provider;
 struct list_head node_list;
 void *data;
 u32 init_avg,init_peak,avg_bw,peak_bw;
};
struct qcom_icc_bcm;
struct qcom_icc_qosbox { u32 prio;bool urg_fwd,prio_fwd_disable;u32 num_ports,port_offsets[4]; };
struct qcom_icc_node {
 const char *name;
 struct icc_node *node;
 u16 num_links,channels,buswidth;
 u64 sum_avg[3],max_peak[3];
 struct qcom_icc_bcm *bcms[3];
 size_t num_bcms;
 const struct qcom_icc_qosbox *qosbox;
 struct qcom_icc_node *link_nodes[16];
};
struct bcm_db { u32 unit;u16 width;unsigned char vcd,reserved; };
struct qcom_icc_bcm {
 const char *name;u32 addr;u64 vote_scale;u32 enable_mask;bool keepalive;
 struct bcm_db aux_data;struct list_head list,ws_list;
 size_t num_nodes;struct qcom_icc_node *nodes[16];
};
struct qcom_icc_desc {
 const void *config;struct qcom_icc_node *const *nodes;size_t num_nodes;
 struct qcom_icc_bcm *const *bcms;size_t num_bcms;
 bool qos_required;
};
static int cliffs_icc_regmap_config;
static struct qcom_icc_node qns_gem_noc_cnoc,qns_llcc;
#include "cliffs-display-icc.h"
struct bcm_voter {
 struct qcom_icc_bcm *pending[8];size_t count;
 bool mm0,mm1;
};
struct qcom_icc_provider {
 struct icc_provider provider;struct device *dev;
 struct qcom_icc_bcm *const *bcms;size_t num_bcms;
 struct bcm_voter *voter;struct qcom_icc_node *const *nodes;size_t num_nodes;
 void *regmap,*clks;int num_clks;
};
#define to_qcom_provider(p) ((struct qcom_icc_provider *)((char *)(p)-offsetof(struct qcom_icc_provider,provider)))
static int commit_calls,commit_failure,register_calls,register_failure;
static int clock_failure,clock_enable_calls,clock_disable_calls,clocks_held;
static int db_fault;
static struct bcm_db aux={.unit=1000,.width=16};
static u32 cmd_db_read_addr(const char *name) { (void)name;return db_fault==1?0:0x1234; }
static const struct bcm_db *cmd_db_read_aux_data(const char *name,size_t *n) {
 (void)name;*n=db_fault==3?0:1;
 return db_fault==2?(const struct bcm_db *)(intptr_t)-EAGAIN:&aux;
}
static void qcom_icc_bcm_voter_add(struct bcm_voter *v,struct qcom_icc_bcm *b) {
 for(size_t i=0;i<v->count;i++)if(v->pending[i]==b)return;
 assert(v->count<ARRAY_SIZE(v->pending));v->pending[v->count++]=b;
}
static int qcom_icc_bcm_voter_commit(struct bcm_voter *v) {
 commit_calls++;
 if(commit_calls==commit_failure){v->count=0;return -ETIMEDOUT;}
 for(size_t i=0;i<v->count;i++) {
  struct qcom_icc_bcm *b=v->pending[i];bool active=b->keepalive;
  for(size_t j=0;j<b->num_nodes;j++)
   for(size_t k=0;k<3;k++)active|=b->nodes[j]->sum_avg[k]||b->nodes[j]->max_peak[k];
  if(!strcmp(b->name,"MM0"))v->mm0=active;
  else if(!strcmp(b->name,"MM1"))v->mm1=active;
  else assert(false);
 }
 v->count=0;return 0;
}
static int clk_bulk_prepare_enable(int n,void *clks) {
 (void)n;(void)clks;clock_enable_calls++;
 if(clock_failure)return -EAGAIN;
 clocks_held++;return 0;
}
static void clk_bulk_disable_unprepare(int n,void *clks) {
 (void)n;(void)clks;assert(clocks_held==1);clocks_held--;clock_disable_calls++;
}
static struct {u32 offset,mask,value;} trace[32];
static struct bcm_voter voter;
static int regmap_update_bits(void *map,u32 offset,u32 mask,u32 value) {
 (void)map;assert(voter.mm0&&voter.mm1&&clocks_held==1);
 assert(register_calls<(int)ARRAY_SIZE(trace));
 trace[register_calls].offset=offset;trace[register_calls].mask=mask;trace[register_calls].value=value;
 register_calls++;return register_calls==register_failure?-EIO:0;
}
#include "actual-functions.c"
static struct icc_node nodes[600];
static struct device device;
static struct qcom_icc_provider qp;
static void setup(void) {
 memset(&voter,0,sizeof(voter));memset(nodes,0,sizeof(nodes));memset(&qp,0,sizeof(qp));
 commit_calls=commit_failure=register_calls=register_failure=clock_failure=0;
 clock_enable_calls=clock_disable_calls=clocks_held=db_fault=0;
 qp=(struct qcom_icc_provider){.dev=&device,.bcms=mmss_noc_bcms,.num_bcms=ARRAY_SIZE(mmss_noc_bcms),
 .nodes=mmss_noc_nodes,.num_nodes=ARRAY_SIZE(mmss_noc_nodes),.voter=&voter};
 qp.provider.pre_aggregate=qcom_icc_pre_aggregate;qp.provider.aggregate=qcom_icc_aggregate;qp.provider.set=qcom_icc_set;
 for(size_t i=0;i<qp.num_nodes;i++)if(qp.nodes[i]){
  struct qcom_icc_node *n=qp.nodes[i];n->num_bcms=0;n->node=&nodes[i];
  memset(n->sum_avg,0,sizeof(n->sum_avg));memset(n->max_peak,0,sizeof(n->max_peak));nodes[i].data=n;
 }
 for(size_t i=0;i<qp.num_bcms;i++){
  qp.bcms[i]->addr=0;assert(!qp.bcms[i]->keepalive);
  assert(qcom_icc_bcm_init(qp.bcms[i],&device)==0);
 }
 for(size_t i=0;i<qp.num_nodes;i++)if(qp.nodes[i])icc_node_add(&nodes[i],&qp.provider);
 assert(voter.mm0&&voter.mm1);assert(!register_calls);
 for(size_t i=0;i<qp.num_nodes;i++)if(qp.nodes[i]){
  assert(nodes[i].init_avg==INT_MAX&&nodes[i].init_peak==INT_MAX);
  assert(!nodes[i].avg_bw&&!nodes[i].peak_bw);
 }
}
static void demand(struct qcom_icc_node *n,u32 avg,u32 peak,u32 tag) {
 struct icc_node *node=n->node;node->init_avg=node->init_peak=0;
 node->avg_bw=node->peak_bw=0;qcom_icc_pre_aggregate(node);
 assert(!qcom_icc_aggregate(node,tag,avg,peak,&node->avg_bw,&node->peak_bw));
}
static bool reaches(struct qcom_icc_node *from,struct qcom_icc_node *to,unsigned depth) {
 if(from==to)return true;
 if(!depth)return false;
 for(unsigned i=0;i<from->num_links;i++)if(reaches(from->link_nodes[i],to,depth-1))return true;
 return false;
}
int main(void) {
 setup();assert(CONFIGURE(&qp)==0);assert(register_calls==15);
#ifdef ICC_LEGACY_TRACE
 for(int i=6;i<register_calls;i++)printf("%08x %08x %08x\n",trace[i].offset,trace[i].mask,trace[i].value);
 return 0;
#endif
 assert(cliffs_mmss_noc.nodes[MASTER_CAMNOC_HF]==&qnm_camnoc_hf&&cliffs_mmss_noc.qos_required);
 assert(qhs_display_cfg.buswidth==4&&qhs_venus_cfg.buswidth==4);
 assert(clock_enable_calls==1&&clock_disable_calls==1&&!clocks_held);
 assert(qnm_camnoc_hf.channels==OEM_CHANNELS&&qnm_camnoc_hf.buswidth==OEM_BUSWIDTH);
 assert(qnm_camnoc_hf.qosbox->port_offsets[0]==OEM_PORT0&&qnm_camnoc_hf.qosbox->port_offsets[1]==OEM_PORT1);
 assert(qnm_camnoc_hf.qosbox->prio==0&&qnm_camnoc_hf.qosbox->urg_fwd&&!qnm_camnoc_hf.qosbox->prio_fwd_disable);
 assert(bcm_mm1.num_nodes==2&&bcm_mm1.nodes[0]==&qns_mem_noc_sf&&bcm_mm1.nodes[1]==&qnm_camnoc_hf&&bcm_mm1.enable_mask==1);
 assert(reaches(&qnm_camnoc_hf,&qns_llcc,4)&&reaches(&qnm_mdp,&qns_llcc,4)&&reaches(&qnm_video,&qns_llcc,4));
 const u32 ports[]={OEM_PORT0+8,OEM_PORT1+8,0xad008,0xae008,0x30008};
 for(size_t i=0;i<ARRAY_SIZE(ports);i++){
  for(size_t j=0;j<3;j++)assert(trace[i*3+j].offset==ports[i]);
  assert(trace[i*3].mask==0x1000000&&trace[i*3].value==0);
  assert(trace[i*3+1].mask==0x70&&trace[i*3+1].value==0);
  assert(trace[i*3+2].mask==8&&trace[i*3+2].value==8);
 }
 for(int failure=1;failure<=15;failure++) {
  setup();register_failure=failure;assert(CONFIGURE(&qp)==-EIO);
  assert(register_calls==failure&&clock_disable_calls==1&&!clocks_held);
 }
 setup();commit_failure=commit_calls+1;assert(CONFIGURE(&qp)==-ETIMEDOUT);
 assert(!register_calls&&!clock_enable_calls&&!clock_disable_calls);
 setup();clock_failure=1;assert(CONFIGURE(&qp)==-EAGAIN);
 assert(!register_calls&&!clock_disable_calls&&!clocks_held);
 for(int failure=1;failure<=3;failure++){
  setup();bcm_mm1.addr=0;db_fault=failure;
  assert(qcom_icc_bcm_init(&bcm_mm1,&device)==(failure==2?-EAGAIN:-EINVAL));
  assert(!bcm_mm1.addr);
  /* A failed aux lookup cannot turn the retry into a cached success. */
  assert(qcom_icc_bcm_init(&bcm_mm1,&device)<0);
 }
 setup();commit_failure=commit_calls+1;assert(qcom_icc_set(qnm_camnoc_hf.node,NULL)==-ETIMEDOUT);
 setup();commit_failure=commit_calls+1;assert(qcom_icc_set(NULL,qnm_camnoc_hf.node)==-ETIMEDOUT);
 for(unsigned cycle=0;cycle<256;cycle++){
  setup();assert(!CONFIGURE(&qp));
  for(size_t i=0;i<qp.num_nodes;i++)if(qp.nodes[i])demand(qp.nodes[i],0,0,0);
  demand(&qns_mem_noc_sf,100,100,7);demand(&qnm_camnoc_hf,0,3000000,7);demand(&qns_mem_noc_hf,0,3000000,7);
  assert(!qcom_icc_set(qnm_camnoc_hf.node,NULL)&&voter.mm0&&voter.mm1);
  demand(&qnm_camnoc_hf,0,0,7);demand(&qns_mem_noc_hf,0,0,7);
  assert(!qcom_icc_set(qnm_camnoc_hf.node,NULL)&&!voter.mm0&&voter.mm1);
  demand(&qns_mem_noc_sf,0,0,7);assert(!qcom_icc_set(NULL,qns_mem_noc_sf.node)&&!voter.mm0&&!voter.mm1);
  assert(!clocks_held&&!bcm_mm1.keepalive&&!bcm_mm0.keepalive);
 }
 puts("Camera HF ICC: actual initial-node/set/aggregate/BCM/QoS callbacks; 15 register faults, vote/clock/aux refusals, 256 shared-video idle cycles passed.");
}

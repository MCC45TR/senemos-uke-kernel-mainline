/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual APR, AudioReach and GLINK callbacks with a deterministic fake peer. */
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
typedef uint16_t __le16;
typedef uint32_t __le32;
typedef uint32_t u32;
#define __packed __attribute__((packed))
#include "actual-gpr-header.h"
struct gpr_pkt { struct gpr_hdr hdr; unsigned char payload[]; };
struct gpr_ibasic_rsp_result_t { u32 opcode,status; };
#define GPR_PKT_VER 0
#define GPR_PKT_HEADER_WORD_SIZE 6
#define GPR_PKT_HEADER_BYTE_SIZE 24
#define GPR_HDR_SIZE 24
#define APM_CMD_SET_CFG 0x01001006
#define PR_TYPE_GPR 1
#define HZ 1
#define SZ_8K 8192
#define GLINK_CMD_TX_DATA 9
#define GLINK_CMD_TX_DATA_CONT 12
#define cpu_to_le16(v) (v)
#define cpu_to_le32(v) (v)
#define READ_ONCE(v) (v)
#define WRITE_ONCE(v,x) ((v)=(x))
#define dev_err(...) ((void)0)
#define trace_qcom_glink_cmd_tx_data_tx(...) ((void)0)
static unsigned atomic_depth;
struct mutex { bool held; };
static void mutex_lock(struct mutex *m){assert(!atomic_depth&&!m->held);m->held=true;}
static void mutex_unlock(struct mutex *m){assert(!atomic_depth&&m->held);m->held=false;}
static void spin_lock(int *l){assert(!*l);*l=1;++atomic_depth;}
static void spin_unlock(int *l){assert(*l&&atomic_depth);*l=0;--atomic_depth;}
#define spin_lock_irqsave(l,f) do{(f)=0;spin_lock(l);}while(0)
#define spin_unlock_irqrestore(l,f) do{(void)(f);spin_unlock(l);}while(0)
struct glink_core_rx_intent { unsigned size,id;bool in_use; };
struct intent_map { struct glink_core_rx_intent *entry[2];unsigned count; };
struct qcom_glink { bool intentless; };
struct glink_channel { struct qcom_glink *glink;int intent_lock;struct intent_map riids;unsigned lcid,rcid; };
struct glink_msg_hdr { __le16 cmd,param1;__le32 param2; } __packed;
#define idr_for_each_entry(map,item,i) for((i)=0;(unsigned)(i)<(map)->count&&((item)=(map)->entry[i]);++(i))
struct packet_router;
struct pkt_router_svc { struct packet_router *pr;int lock;unsigned id;void *callback; };
struct service_map { struct pkt_router_svc *service; };
struct packet_router { struct mutex callback_lock;int svcs_lock,type;struct service_map svcs_idr;struct glink_channel *ch; };
struct device { void *data;struct device *parent; };
struct apr_device { struct device dev;struct pkt_router_svc svc; };
typedef struct apr_device gpr_device_t;
typedef struct pkt_router_svc gpr_port_t;
typedef int wait_queue_head_t;
static struct packet_router router;
static struct qcom_glink glink;
static struct glink_channel channel;
static struct glink_core_rx_intent peer_intent;
static struct pkt_router_svc *idr_find(struct service_map *map,unsigned id){
 assert(router.callback_lock.held&&router.svcs_lock);
 return map->service&&map->service->id==id?map->service:NULL;
}
static void *dev_get_drvdata(struct device *d){return d->data;}
static unsigned requests,frames,nonblocking,blocking;
static int request_error,tx_error;
static u32 peer_status;
static bool with_ack=true;
static unsigned char delivered[16384];
static size_t delivered_bytes;
static struct gpr_ibasic_rsp_result_t *active_result;
static int qcom_glink_request_intent(struct qcom_glink *g,struct glink_channel *c,size_t bytes){
 assert(g==&glink&&c==&channel&&!atomic_depth&&router.callback_lock.held);
 ++requests;if(request_error)return request_error;
 peer_intent=(struct glink_core_rx_intent){.size=bytes,.id=23};
 c->riids.entry[0]=&peer_intent;c->riids.count=1;return 0;
}
static int qcom_glink_tx(struct qcom_glink *g,const void *header,size_t hbytes,const void *data,size_t bytes,bool wait){
 struct data_header {struct glink_msg_hdr msg;__le32 chunk_size,left_size;} __packed;
 const struct data_header *h=header;
 assert(g==&glink&&hbytes==sizeof(*h)&&bytes==h->chunk_size);
 if(wait)assert(!atomic_depth&&router.callback_lock.held);
 if(tx_error)return tx_error;
 assert(delivered_bytes+bytes<=sizeof(delivered));
 memcpy(delivered+delivered_bytes,data,bytes);delivered_bytes+=bytes;++frames;
 return 0;
}
#include "actual-glink-send.h"
static int rpmsg_trysend(struct glink_channel *c,const void *p,int bytes){
 ++nonblocking;assert(c==&channel);return __qcom_glink_send(c,p,bytes,false);
}
static int rpmsg_send(struct glink_channel *c,const void *p,int bytes){
 ++blocking;assert(c==&channel&&!atomic_depth&&router.callback_lock.held);
 int ret=__qcom_glink_send(c,p,bytes,true);
 if(!ret&&active_result&&with_ack){active_result->opcode=((const struct gpr_pkt *)p)->hdr.opcode;active_result->status=peer_status;}
 return ret;
}
#include "actual-apr-send.h"
#define wait_event_timeout(q,condition,t) ({(void)(q);(void)(t);(condition)?1:0;})
#include "actual-audioreach-sync.h"
static void reset(gpr_device_t *device){
 assert(!atomic_depth&&!router.callback_lock.held);
 memset(&router,0,sizeof(router));glink=(struct qcom_glink){0};
 channel=(struct glink_channel){.glink=&glink,.lcid=4,.rcid=7};
 router.type=PR_TYPE_GPR;router.ch=&channel;
 device->svc=(struct pkt_router_svc){.pr=&router,.id=1,.callback=device};
 router.svcs_idr.service=&device->svc;device->dev.parent->data=&router;
 requests=frames=nonblocking=blocking=0;request_error=tx_error=0;peer_status=0;
 delivered_bytes=0;active_result=NULL;with_ack=true;
}
static struct gpr_pkt *packet(size_t bytes,u32 opcode){
 assert(bytes>=GPR_HDR_SIZE&&bytes<=sizeof(delivered));
 struct gpr_pkt *p=malloc(bytes);assert(p);memset(p,0x5a,bytes);
 p->hdr=(struct gpr_hdr){.hdr_size=6,.pkt_size=bytes,.opcode=opcode};return p;
}
int main(void){
 struct device parent={0};gpr_device_t device={.dev={.parent=&parent}};
 struct mutex command_lock={0};struct gpr_ibasic_rsp_result_t result={0};int queue=0;
 struct gpr_pkt *p=packet(5416,APM_CMD_SET_CFG);
 reset(&device);
 assert(gpr_send_pkt(&device,p)==-EBUSY&&!requests&&!frames&&nonblocking==1);
 reset(&device);active_result=&result;
 int ret=audioreach_send_cmd_sync(&device.dev,&device,&result,&command_lock,NULL,&queue,p,0);
 if(ret)fprintf(stderr,"5416-byte static configuration failed: %d\n",ret);
 assert(!ret&&!command_lock.held&&requests==1&&blocking==1&&!nonblocking&&frames==1);
 assert(delivered_bytes==5416&&!memcmp(p,delivered,5416));
 for(unsigned bytes=24;bytes<=12056;bytes+=752){
  reset(&device);struct gpr_pkt *q=packet(bytes,APM_CMD_SET_CFG);
  assert(gpr_send_pkt_wait(&device,q)==(int)bytes&&requests==1&&delivered_bytes==bytes);
  assert(!memcmp(q,delivered,bytes));assert(frames==(bytes>8192?2U:1U));free(q);
 }
 for(unsigned kind=0;kind<3;kind++){
  reset(&device);request_error=(int[]){-EAGAIN,-ETIMEDOUT,-ECANCELED}[kind];
  assert(gpr_send_pkt_wait(&device,p)==request_error&&requests==1&&!frames);
  assert(!router.callback_lock.held&&!router.svcs_lock);
 }
 reset(&device);tx_error=-EPIPE;
 assert(gpr_send_pkt_wait(&device,p)==-EPIPE&&!peer_intent.in_use);
 reset(&device);gpr_quiesce_service(&device);
 assert(gpr_send_pkt_wait(&device,p)==-ENODEV&&!requests&&!blocking);
 reset(&device);router.svcs_idr.service=NULL;
 assert(gpr_send_pkt_wait(&device,p)==-ENODEV&&!requests&&!blocking);
 for(unsigned kind=0;kind<4;kind++){
  reset(&device);struct gpr_pkt *q=packet(64,APM_CMD_SET_CFG);
  if(kind==0)q->hdr.version=1;else if(kind==1)q->hdr.hdr_size=5;
  else if(kind==2)q->hdr.pkt_size=23;else router.type=0;
  assert(gpr_send_pkt_wait(&device,q)==-EINVAL&&!blocking&&!requests);free(q);
 }
 reset(&device);assert(gpr_send_pkt_wait(NULL,p)==-EINVAL&&gpr_send_pkt_wait(&device,NULL)==-EINVAL);
 reset(&device);result=(struct gpr_ibasic_rsp_result_t){0};
 assert(audioreach_send_cmd_sync(&device.dev,&device,&result,&command_lock,&device.svc,&queue,p,0)==-EBUSY);
 assert(!blocking&&!requests&&nonblocking==1&&!command_lock.held);
 reset(&device);p->hdr.opcode=0x01001000;
 assert(audioreach_send_cmd_sync(&device.dev,&device,&result,&command_lock,NULL,&queue,p,0)==-EBUSY);
 assert(!blocking&&!requests&&nonblocking==1);p->hdr.opcode=APM_CMD_SET_CFG;
 reset(&device);active_result=&result;with_ack=false;
 assert(audioreach_send_cmd_sync(&device.dev,&device,&result,&command_lock,NULL,&queue,p,0)==-ETIMEDOUT);
 assert(!command_lock.held&&!router.callback_lock.held);
 reset(&device);active_result=&result;peer_status=9;
 assert(audioreach_send_cmd_sync(&device.dev,&device,&result,&command_lock,NULL,&queue,p,0)==-EINVAL);
 assert(!command_lock.held&&!router.callback_lock.held);
 free(p);
 puts("Actual APR/AudioReach/GLINK:5416-byte intent negotiation, exact records, transport fragmentation, refusal/error cleanup and unchanged nonblocking paths passed.");
 return 0;
}

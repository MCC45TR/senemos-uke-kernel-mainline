#!/usr/bin/env bash
# Actual QRTR worker, SMD probe and name-server paths; host memory only.
# shellcheck disable=SC2129
set -euo pipefail
kernel=${1:?Pass prepared kernel source}
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
core=$kernel/net/qrtr/af_qrtr.c
smd=$kernel/net/qrtr/smd.c
ns=$kernel/net/qrtr/ns.c
cat > "$stage/check.c" <<'C'
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#define AF_QIPCRTR 42
#define QRTR_PORT_CTRL 0xfffffffeU
#define QRTR_TYPE_HELLO 2
#define QRTR_EP_NID_AUTO (-1)
#define GFP_KERNEL 0
#define READ_ONCE(x) (x)
#define cpu_to_le32(x) (x)
#define container_of(p,t,m) ((t *)((char *)(p)-offsetof(t,m)))
#define to_delayed_work(p) container_of(p,struct delayed_work,work)
#define EXPORT_SYMBOL_GPL(x)
#define dev_dbg(...) ((void)0)
#define pr_err(...) ((void)0)
struct work_struct {int unused;};
struct delayed_work {struct work_struct work;};
struct sockaddr_qrtr {unsigned sq_family,sq_node,sq_port;};
struct qrtr_server {unsigned node;};
struct qrtr_endpoint;
struct qrtr_node {int ep_lock;struct qrtr_endpoint *ep;unsigned nid;struct delayed_work say_hello;int servers;};
struct qrtr_endpoint {struct qrtr_node *node;int (*xmit)(struct qrtr_endpoint *,void *);};
struct qrtr_sock {int unused;};
struct qrtr_ctrl_pkt {unsigned cmd;};
struct sk_buff {struct qrtr_ctrl_pkt packet;};
static struct qrtr_node node;
static struct qrtr_sock control;
static struct sk_buff buffer;
static unsigned qrtr_local_nid=1,scheduled,delay,sends,put_count,locks,announcements;
static bool ns_ready,alloc_fail,uke,device_alloc_fail;
static int send_result,register_error;
static void mutex_lock(int *p){assert(p==&node.ep_lock && !locks++);}
static void mutex_unlock(int *p){assert(p==&node.ep_lock && locks--==1);}
static int schedule_delayed_work(struct delayed_work *work,unsigned ms)
{assert(work==&node.say_hello);scheduled++;delay=ms;return 1;}
static unsigned msecs_to_jiffies(unsigned ms){return ms;}
static struct qrtr_sock *qrtr_port_lookup(unsigned port)
{assert(port==QRTR_PORT_CTRL);return ns_ready?&control:NULL;}
static void qrtr_port_put(struct qrtr_sock *sock){assert(sock==&control);put_count++;}
static struct sk_buff *qrtr_alloc_ctrl_packet(struct qrtr_ctrl_pkt **p,int flags)
{assert(flags==GFP_KERNEL);if(alloc_fail)return NULL;*p=&buffer.packet;return &buffer;}
static int qrtr_node_enqueue(struct qrtr_node *n,struct sk_buff *b,int type,
 struct sockaddr_qrtr *from,struct sockaddr_qrtr *to)
{assert(n==&node && b==&buffer && type==QRTR_TYPE_HELLO && !locks);
 assert(b->packet.cmd==QRTR_TYPE_HELLO && from->sq_node==1 && to->sq_node==5);
 assert(from->sq_port==QRTR_PORT_CTRL && to->sq_port==QRTR_PORT_CTRL);
 sends++;return send_result;}
C
awk '/^static void qrtr_hello_work\(/ {emit=1} /^void qrtr_endpoint_hello\(/ {emit=1}
 emit {print} emit && /^}/ {emit=0}' "$core" >> "$stage/check.c"
cat >> "$stage/check.c" <<'C'
struct device {void *data;};
struct rpmsg_device {struct device dev;void *ept;};
struct qrtr_smd_dev {struct qrtr_endpoint ep;void *channel;struct device *dev;};
static struct qrtr_smd_dev storage;
static struct rpmsg_device *probing;
static void *devm_kzalloc(struct device *dev,size_t size,int flags)
{assert(dev==&probing->dev && size==sizeof(storage) && flags==GFP_KERNEL);
 memset(&storage,0,sizeof(storage));return device_alloc_fail?NULL:&storage;}
static int qcom_smd_qrtr_send(struct qrtr_endpoint *ep,void *skb){(void)ep;(void)skb;return 0;}
static int qrtr_endpoint_register(struct qrtr_endpoint *ep,int nid)
{assert(ep==&storage.ep && ep->xmit==qcom_smd_qrtr_send && nid==QRTR_EP_NID_AUTO);
 assert(storage.channel==probing->ept && storage.dev==&probing->dev);
 ep->node=&node;return register_error;}
static void dev_set_drvdata(struct device *dev,void *data){dev->data=data;}
static bool of_machine_is_compatible(const char *s)
{assert(!strcmp(s,"xiaomi,uke") && probing->dev.data==&storage);return uke;}
C
awk '/^static int qcom_smd_qrtr_probe\(/ {emit=1} emit {print} emit && /^}/ {emit=0}' "$smd" >> "$stage/check.c"
cat >> "$stage/check.c" <<'C'
struct list_head {int index;};
struct qrtr_lookup {struct list_head li;unsigned service,instance;struct sockaddr_qrtr sq;};
static struct qrtr_lookup lookups[3];
static unsigned notifications;
static struct {unsigned local_node;struct sockaddr_qrtr bcast_sq;struct list_head lookups;} qrtr_ns={.local_node=1};
static struct qrtr_server servers[3];
static struct qrtr_node *node_get(unsigned id){assert(id==1);return &node;}
#define xa_for_each(array,index,srv) for((index)=0;(index)<3 && ((srv)=&servers[index]);(index)++)
static int service_announce_new(struct sockaddr_qrtr *sq,struct qrtr_server *srv)
{if(sq==&qrtr_ns.bcast_sq)return -EAGAIN;
 assert(srv==&servers[announcements++]);return announcements==1?-EAGAIN:0;}
static struct qrtr_server *server_add(unsigned service,unsigned instance,unsigned nid,unsigned port)
{assert(service==64 && instance==1 && nid==1 && port==100);servers[0].node=nid;return &servers[0];}
#define list_for_each(li,head) for(unsigned i=0; i<3 && ((li)=&lookups[i].li);i++)
static void lookup_notify(struct sockaddr_qrtr *sq,struct qrtr_server *srv,bool add)
{assert(srv==&servers[0] && add && (sq==&lookups[0].sq || sq==&lookups[1].sq));notifications++;}
C
awk '/^static int announce_servers\(/ {emit=1} emit {print} emit && /^}/ {emit=0}' "$ns" >> "$stage/check.c"
awk '/^static int ctrl_cmd_new_server\(/ {emit=1} emit {print} emit && /^}/ {emit=0}' "$ns" >> "$stage/check.c"
cat >> "$stage/check.c" <<'C'
static void reset(void)
{memset(&node,0,sizeof(node));node.nid=5;node.ep=&storage.ep;
 scheduled=delay=sends=put_count=locks=0;ns_ready=true;alloc_fail=false;send_result=0;}
int main(void)
{
 reset();ns_ready=false;qrtr_hello_work(&node.say_hello.work);
 assert(scheduled==1 && delay==100 && !sends && !put_count && !locks);
 reset();alloc_fail=true;qrtr_hello_work(&node.say_hello.work);
 assert(scheduled==1 && delay==100 && !sends && put_count==1 && !locks);
 const int results[]={0,-EAGAIN,-ENOMEM,-ENODEV,-EIO};
 for(unsigned i=0;i<sizeof(results)/sizeof(results[0]);i++) {
  reset();send_result=results[i];qrtr_hello_work(&node.say_hello.work);
  assert(sends==1 && put_count==1 && !locks);
  assert(scheduled==(send_result==-EAGAIN || send_result==-ENOMEM));
  if(scheduled)assert(delay==100);
 }
 reset();node.ep=NULL;ns_ready=false;qrtr_hello_work(&node.say_hello.work);
 assert(!scheduled && !sends && !put_count && !locks);
 reset();struct qrtr_endpoint ep={.node=&node};qrtr_endpoint_hello(&ep);
 assert(scheduled==1 && !delay);
 struct rpmsg_device dev={.ept=&buffer};probing=&dev;
 for(unsigned foreign=0;foreign<2;foreign++) {
  reset();dev.dev.data=NULL;uke=!foreign;register_error=0;device_alloc_fail=false;
  assert(!qcom_smd_qrtr_probe(&dev) && dev.dev.data==&storage);
  assert(scheduled==uke && !delay);
 }
 reset();register_error=-EIO;dev.dev.data=NULL;
 assert(qcom_smd_qrtr_probe(&dev)==-EIO && !scheduled && !dev.dev.data);
 register_error=0;device_alloc_fail=true;
 assert(qcom_smd_qrtr_probe(&dev)==-ENOMEM && !scheduled && !dev.dev.data);
 struct sockaddr_qrtr dest={0};announcements=0;
 assert(!announce_servers(&dest) && announcements==3);
 dest.sq_node=1;dest.sq_port=100;lookups[1].service=64;lookups[2].service=400;
 assert(ctrl_cmd_new_server(&dest,64,1,99,99)==-EAGAIN && notifications==2);
 puts("Actual QRTR HELLO worker: readiness, allocation, transient/permanent send failures, teardown and Uke-only SMD publication passed; failed announcement preserves remaining servers. Host only.");
}
C
"${CC:-cc}" -std=gnu11 -Wall -Wextra -Werror -fsanitize=address,undefined \
    -fno-omit-frame-pointer "$stage/check.c" -o "$stage/check"
"$stage/check"
# Require the existing handshake policy and ungated enqueue for each source base.
if grep -q '^static int say_hello(' "$ns"; then
    grep -Fq 'ret = say_hello(sq);' "$ns"
else
    awk '/^int qrtr_endpoint_register\(/ {emit=1}
     emit && /schedule_delayed_work\(&node->say_hello, 0\)/ {found=1}
     emit && /^}/ {emit=0} END {exit !found}' "$core"
fi
if grep -q 'hello_sent\|tx_backlog' "$core"; then exit 1; fi
awk '/^void qrtr_endpoint_unregister\(/ {emit=1}
 emit && /cancel_delayed_work_sync/ {cancel=1}
 emit && /qrtr_node_release\(node\)/ {exit !cancel}
 END {if (!emit) exit 1}' "$core"

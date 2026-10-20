#!/usr/bin/env bash
# shellcheck disable=SC2129
# Host-only actual kernel C functions with fake DMA, components and VB2.
set -Eeuo pipefail
iris=${1:?Pass the prepared Iris directory}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/include/linux" "$work/include/media"
cat > "$work/include/linux/types.h" <<'H'
#pragma once
#include <stdint.h>
typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef u64 dma_addr_t;
H
cat > "$work/include/media/videobuf2-v4l2.h" <<'H'
#pragma once
struct vb2_v4l2_buffer { int unused; };
H
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <linux/types.h>
#define BIT(n) (1U << (n))
#define DMA_BIT_MASK(n) ((1ULL << (n))-1)
#define ALIGN(v, a) (((v)+(a)-1)&~((a)-1))
#define ERR_PTR(e) ((void *)(long)(e))
#define PTR_ERR(p) ((int)(long)(p))
#define IS_ERR(p) ((unsigned long)(p) >= (unsigned long)-4095)
#define EPROBE_DEFER 517
#define MODULE_DEVICE_TABLE(a, b)
struct list_head { struct list_head *next, *prev; };
#define INIT_LIST_HEAD(p) ((p)->next = (p)->prev = (p))
static void list_add_tail(struct list_head *p, struct list_head *h) {
    p->prev=h->prev; p->next=h; h->prev->next=p; h->prev=p;
}
static void list_del(struct list_head *p) { p->prev->next=p->next; p->next->prev=p->prev; }
#include "iris_buffer.h"
#include "iris_hfi_gen2_defines.h"
enum domain_type { DECODER, ENCODER };
enum { IOMMU_DOMAIN_DMA=1, IOMMU_DOMAIN_DMA_FQ, IOMMU_DOMAIN_IDENTITY };
enum { MASK=1, COMPONENT, MATCH, CREATE, ACTION, MASTER, BIND, VIDEO, ALLOC, OBJECT, VB2 };
struct device_node { bool available, compatible; int refs; };
struct iommu_domain { int type; };
struct device { struct device *parent; struct device_node *of_node; void *data;
                struct iommu_domain *domain; unsigned refs; };
struct platform_device { struct device dev; };
struct platform_data { bool split_dma; u64 dma_mask; };
struct iris_core { struct device *dev, *pixel_dev; const struct platform_data *iris_platform_data;
                   void *iris_vb2_ops; };
struct iris_inst { struct iris_core *core; enum domain_type domain;
                   struct iris_buffers buffers[BUF_TYPE_MAX]; int ctx_q_lock; u32 session_id; };
struct component_ops { int (*bind)(struct device *, struct device *, void *);
                       void (*unbind)(struct device *, struct device *, void *); };
struct component_master_ops { int (*bind)(struct device *); void (*unbind)(struct device *); };
struct component_match { struct device_node *node; };
struct of_device_id { const char *compatible; };
struct platform_driver { int (*probe)(struct platform_device *); void (*remove)(struct platform_device *);
                        struct { const char *name; const struct of_device_id *of_match_table; } driver; };
static int fault, video_nodes, component_count, unbinds, destroys, queue_calls, packet_calls, writes;
static u64 observed_mask;
static bool child_present=true;
static struct device_node parent_node={true,true,0}, child_node={true,true,0};
static struct platform_device child;
static struct component_match match_record;
static void (*destroy_action)(void *);
static void *destroy_data;
static bool of_device_is_compatible(struct device_node *n, const char *s) {
    assert(!strcmp(s,"qcom,sm7675-iris") || !strcmp(s,"qcom,sm7675-iris-pixel"));
    return n && n->compatible;
}
static void *dev_get_drvdata(struct device *d) { return d->data; }
static struct iommu_domain *iommu_get_domain_for_dev(struct device *d) { return d->domain; }
static int dma_set_mask_and_coherent(struct device *d, u64 mask) {
    assert(d==&child.dev); observed_mask=mask; return fault==MASK ? -EREMOTEIO : 0;
}
static void dma_set_max_seg_size(struct device *d, unsigned long size) { assert(d==&child.dev && size==DMA_BIT_MASK(32)); }
static void dma_set_seg_boundary(struct device *d, unsigned long size) { assert(d==&child.dev && size==DMA_BIT_MASK(32)); }
static int component_add(struct device *d, const struct component_ops *ops) {
    assert(d==&child.dev && ops); if (fault==COMPONENT) return -EREMOTEIO; ++component_count; return 0;
}
static void component_del(struct device *d, const struct component_ops *ops) { assert(d==&child.dev && ops); --component_count; }
static int component_bind_all(struct device *d, void *data);
static void component_unbind_all(struct device *d, void *data);
static int iris_register_video_devices(struct iris_core *c) { assert(c->pixel_dev); if (fault==VIDEO) return -EREMOTEIO; video_nodes=2; return 0; }
static void iris_unregister_video_devices(struct iris_core *c) { assert(c->pixel_dev); video_nodes=0; }
static int of_platform_device_destroy(struct device *d, void *data) { assert(d==&child.dev && !data); ++destroys; return 0; }
static struct device_node *of_get_child_by_name(struct device_node *n, const char *s) {
    assert(n==&parent_node && !strcmp(s,"pixel")); if (!child_present) return NULL; ++child_node.refs; return &child_node;
}
static bool of_device_is_available(struct device_node *n) { return n->available; }
static void of_node_put(struct device_node *n) { assert(n->refs>0); --n->refs; }
static void component_release_of(struct device *d, void *n) { assert(d); of_node_put(n); }
static int component_compare_of(struct device *d, void *n) { return d->of_node==n; }
static void component_match_add_release(struct device *d, struct component_match **m,
        void (*release)(struct device *, void *), int (*compare)(struct device *, void *), void *n) {
    assert(d && release && compare); if (fault==MATCH) { *m=ERR_PTR(-ENOMEM); return; }
    match_record.node=n; *m=&match_record;
}
static struct platform_device *of_platform_device_create(struct device_node *n, const char *name, struct device *parent) {
    assert(n==&child_node && !name && parent==child.dev.parent); return fault==CREATE ? NULL : &child;
}
static int devm_add_action_or_reset(struct device *d, void (*action)(void *), void *data) {
    assert(d); if (fault==ACTION) { action(data); return -EREMOTEIO; }
    destroy_action=action; destroy_data=data; return 0;
}
static int component_master_add_with_match(struct device *d, const struct component_master_ops *ops, struct component_match *m) {
    assert(d && ops && m==&match_record); return fault==MASTER ? -EREMOTEIO : 0;
}
static void component_master_del(struct device *d, const struct component_master_ops *ops) { assert(d && ops); }
C
sed '/^#include /d' "$iris/iris_dma.c" >> "$work/check.c"
cat >> "$work/check.c" <<'C'
static int component_bind_all(struct device *d, void *data) {
    return fault==BIND ? -EREMOTEIO : iris_pixel_bind(&child.dev,d,data);
}
static void component_unbind_all(struct device *d, void *data) { ++unbinds; iris_pixel_unbind(&child.dev,d,data); }
enum { DMA_ATTR_WRITE_COMBINE=1, DMA_ATTR_NO_KERNEL_MAPPING=2, GFP_KERNEL=0 };
static struct device *allocation_owner;
static void *allocation_cpu;
static unsigned allocations, frees;
static struct device *get_device(struct device *d) { ++d->refs; return d; }
static void put_device(struct device *d) { assert(d->refs); --d->refs; }
#define kzalloc_obj(obj) (fault==OBJECT ? NULL : calloc(1,sizeof(obj)))
#define kfree(p) free(p)
static void *dma_alloc_attrs(struct device *d, size_t size, dma_addr_t *addr, int gfp, unsigned long attrs) {
    assert(!allocation_cpu && size && !gfp && attrs==3); ++allocations;
    if (fault==ALLOC) return NULL;
    allocation_owner=d; allocation_cpu=malloc(size); assert(allocation_cpu); *addr=0x12345000; return allocation_cpu;
}
static void dma_free_attrs(struct device *d, size_t size, void *cpu, dma_addr_t addr, unsigned long attrs) {
    assert(d==allocation_owner && cpu==allocation_cpu && size && addr==0x12345000 && attrs==3);
    free(cpu); allocation_cpu=NULL; ++frees;
}
C
for name in iris_create_internal_buffer iris_destroy_internal_buffer; do
    awk -v name="$name" '$0 ~ "^(static )?int " name "\\(" {emit=1} emit {print} emit && /^}/ {exit}' \
        "$iris/iris_buffer.c" >> "$work/check.c"
done
cat >> "$work/check.c" <<'C'
enum { V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE=1, V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE,
       VB2_MMAP=1, VB2_DMABUF=2, V4L2_BUF_FLAG_TIMESTAMP_COPY=4, MIN_BUFFERS=4 };
struct vb2_queue { unsigned type, io_modes, timestamp_flags; void *ops; const void *mem_ops;
                   void *drv_priv; size_t buf_struct_size; unsigned min_reqbufs_allocation;
                   struct device *dev; bool bidirectional; void *lock; };
static int vb2_dma_contig_memops;
static int vb2_queue_init(struct vb2_queue *q) { assert(q->dev && q->drv_priv); ++queue_calls; return fault==VB2 ? -EIO : 0; }
C
sed -n '/^static int$/,/^int iris_open/ p' "$iris/iris_vidc.c" | sed '$d' >> "$work/check.c"
awk '/^struct iris_hfi_(buffer|header) \{/ {emit=1} emit {print} emit && /^};/ {emit=0}' \
    "$iris/iris_hfi_gen2_packet.h" >> "$work/check.c"
awk '/^enum hfi_packet_(port_type|payload_info|host_flags) \{/ {emit=1} emit {print} emit && /^};/ {emit=0}' \
    "$iris/iris_hfi_common.h" >> "$work/check.c"
cat >> "$work/check.c" <<'C'
struct iris_inst_hfi_gen2 { struct iris_inst inst; struct iris_hfi_header *packet; };
#define to_iris_inst_hfi_gen2(inst) ((struct iris_inst_hfi_gen2 *)(inst))
static struct iris_hfi_buffer sent;
static int iris_hfi_gen2_set_num_comv(struct iris_inst *inst) { assert(inst); return 0; }
static u32 iris_hfi_gen2_get_port_from_buf_type(struct iris_inst *inst, enum iris_buffer_type t) { assert(inst && t); return HFI_PORT_RAW; }
static void iris_hfi_gen2_packet_session_command(struct iris_inst *inst, u32 cmd, u32 flags,
        u32 port, u32 session, u32 payload, void *data, size_t size) {
    assert(inst && cmd==HFI_CMD_BUFFER && flags && port && session==9 && payload==HFI_PAYLOAD_STRUCTURE && size==sizeof(sent));
    memcpy(&sent,data,size); ++packet_calls;
}
static int iris_hfi_queue_cmd_write(struct iris_core *c, void *packet, u32 size) {
    assert(c && packet && size); ++writes; return 0;
}
C
for name in iris_hfi_gen2_buf_type_from_driver iris_hfi_gen2_get_buffer iris_hfi_gen2_session_queue_buffer iris_hfi_gen2_session_release_buffer; do
    awk -v name="$name" '$0 ~ "^(static )?(int|u32) " name "\\(" {emit=1} emit {print} emit && /^}/ {exit}' \
        "$iris/iris_hfi_gen2_command.c" >> "$work/check.c"
done
cat >> "$work/check.c" <<'C'
static void clean_resources(struct device *d) {
    if (destroy_action) { destroy_action(destroy_data); destroy_action=NULL; }
    if (match_record.node) { component_release_of(d,match_record.node); match_record.node=NULL; }
    assert(!child_node.refs);
}
int main(void) {
    struct iommu_domain control={IOMMU_DOMAIN_DMA}, pixel={IOMMU_DOMAIN_DMA_FQ};
    struct device parent={.of_node=&parent_node,.domain=&control};
    struct platform_data pd={true,0xdfffffff};
    struct iris_core core={.dev=&parent,.pixel_dev=&child.dev,.iris_platform_data=&pd};
    struct iris_inst_hfi_gen2 ext={.inst={.core=&core,.domain=DECODER,.session_id=9}};
    struct iris_inst *inst=&ext.inst;
    struct iris_hfi_header hdr={.size=32}; ext.packet=&hdr; parent.data=&core;
    child.dev=(struct device){.parent=&parent,.of_node=&child_node,.domain=&pixel};
    for (int domain=DECODER; domain<=ENCODER; ++domain) {
        inst->domain=domain;
        for (int t=BUF_INPUT; t<BUF_TYPE_MAX; ++t) {
            struct device *dev=iris_buffer_dma_device(inst,t);
            if (t==BUF_SCRATCH_1 || t==BUF_SCRATCH_2) { assert(PTR_ERR(dev)==-EINVAL); continue; }
            bool raw=t==BUF_DPB || t==BUF_VPSS || t==BUF_PARTIAL ||
                     (t==BUF_INPUT && domain==ENCODER) || (t==BUF_OUTPUT && domain==DECODER);
            assert(dev==(raw ? &child.dev : &parent));
            struct iris_buffer buf={.type=t,.index=7,.buffer_size=257,.data_offset=3,.data_size=11,
                                    .device_addr=0x12345000,.dma_dev=dev,.timestamp=123456,.attr=BUF_ATTR_PENDING_RELEASE};
            struct iris_hfi_buffer hfi;
            assert(!iris_hfi_gen2_get_buffer(inst,&buf,&hfi));
            assert(hfi.flags==((raw ? 0x2000U : 0x200U)|HFI_BUF_HOST_FLAG_RELEASE));
            assert(hfi.type && hfi.index==7 && hfi.base_address==buf.device_addr && !hfi.addr_offset);
            assert(hfi.buffer_size==(domain==DECODER && t==BUF_INPUT ? 512U : 257U));
            assert(hfi.data_offset==3 && hfi.data_size==11 && hfi.timestamp==123456);
            assert(!iris_hfi_gen2_session_queue_buffer(inst,&buf));
            assert(sent.flags==hfi.flags && !iris_hfi_gen2_session_release_buffer(inst,&buf));
            int old_packets=packet_calls, old_writes=writes;
            buf.dma_dev=raw ? &parent : &child.dev; memset(&hfi,0xa5,sizeof(hfi));
            assert(iris_hfi_gen2_get_buffer(inst,&buf,&hfi)==-EXDEV && hfi.index==0xa5a5a5a5);
            assert(iris_hfi_gen2_session_queue_buffer(inst,&buf)==-EXDEV);
            assert(iris_hfi_gen2_session_release_buffer(inst,&buf)==-EXDEV);
            assert(packet_calls==old_packets && writes==old_writes);
            struct iris_buffers *buffers=&inst->buffers[t]; buffers->size=4096; INIT_LIST_HEAD(&buffers->list);
            for (int f=0; f<=2; ++f) {
                fault=f==1 ? OBJECT : f==2 ? ALLOC : 0;
                assert(iris_create_internal_buffer(inst,t,7)==(fault ? -ENOMEM : 0));
                if (!fault) {
                    struct iris_buffer *b=(void *)((char *)buffers->list.next - offsetof(struct iris_buffer,list));
                    assert(b->dma_dev==dev && dev->refs==1 && b->index==7);
                    inst->domain=domain==DECODER ? ENCODER : DECODER;
                    assert(!iris_destroy_internal_buffer(inst,b)); inst->domain=domain;
                }
                assert(!parent.refs && !child.dev.refs && buffers->list.next==&buffers->list);
            }
            fault=0;
        }
        struct vb2_queue src={0}, dst={0}; queue_calls=0;
        assert(!iris_m2m_queue_init(inst,&src,&dst) && queue_calls==2);
        assert(src.dev==(domain==ENCODER ? &child.dev : &parent));
        assert(dst.dev==(domain==DECODER ? &child.dev : &parent) && src.bidirectional && dst.bidirectional);
        fault=VB2; queue_calls=0; assert(iris_m2m_queue_init(inst,&src,&dst)==-EIO && queue_calls==1); fault=0;
    }
    core.pixel_dev=NULL; queue_calls=0; struct vb2_queue src={0}, dst={0};
    assert(PTR_ERR(iris_buffer_dma_device(inst,BUF_INPUT))==-ENODEV);
    assert(iris_m2m_queue_init(inst,&src,&dst)==-ENODEV && !queue_calls && !src.dev && !dst.dev);
    struct iris_buffer missing={.type=BUF_INPUT};
    int before_packets=packet_calls, before_writes=writes;
    assert(iris_hfi_gen2_session_queue_buffer(inst,&missing)==-ENODEV);
    assert(iris_hfi_gen2_session_release_buffer(inst,&missing)==-ENODEV);
    assert(before_packets==packet_calls && before_writes==writes);
    pd.split_dma=false;
    assert(iris_buffer_dma_device(inst,BUF_SCRATCH_1)==&parent);
    assert(!iris_m2m_queue_init(inst,&src,&dst) && src.dev==&parent && dst.dev==&parent && !src.bidirectional && !dst.bidirectional);
    pd.split_dma=true; core.pixel_dev=&child.dev; inst->domain=7;
    assert(PTR_ERR(iris_buffer_dma_device(inst,BUF_INPUT))==-EINVAL); inst->domain=DECODER;
    assert(!iris_pixel_probe(&child) && component_count==1 && observed_mask==pd.dma_mask);
    iris_pixel_remove(&child); assert(!component_count);
    for (int f=MASK; f<=COMPONENT; ++f) { fault=f; assert(iris_pixel_probe(&child)==-EREMOTEIO && !component_count); }
    fault=0; parent.data=NULL; assert(iris_pixel_probe(&child)==-EPROBE_DEFER); parent.data=&core;
    parent_node.compatible=false; assert(iris_pixel_probe(&child)==-EINVAL); parent_node.compatible=true;
    for (int type=0; type<=IOMMU_DOMAIN_IDENTITY; ++type) {
        pixel.type=type; int expected=(type==IOMMU_DOMAIN_DMA || type==IOMMU_DOMAIN_DMA_FQ) ? 0 : -ENODEV;
        assert(iris_pixel_probe(&child)==expected); if (!expected) iris_pixel_remove(&child);
        assert(iris_pixel_bind(&child.dev,&parent,&core)==(expected ? -EINVAL : 0));
    }
    pixel.type=IOMMU_DOMAIN_DMA_FQ; child.dev.domain=&control;
    assert(iris_pixel_bind(&child.dev,&parent,&core)==-EINVAL); child.dev.domain=&pixel;
    parent.domain=NULL; assert(iris_pixel_bind(&child.dev,&parent,&core)==-EINVAL); parent.domain=&control;
    control.type=IOMMU_DOMAIN_IDENTITY; assert(iris_pixel_bind(&child.dev,&parent,&core)==-EINVAL); control.type=IOMMU_DOMAIN_DMA;
    child.dev.domain=NULL; assert(iris_pixel_probe(&child)==-ENODEV); child.dev.domain=&pixel;
    for (int f=0; f<3; ++f) {
        fault=f==1 ? BIND : f==2 ? VIDEO : 0; core.pixel_dev=NULL; video_nodes=0; unbinds=0;
        assert(iris_pixel_master_bind(&parent)==(fault ? -EREMOTEIO : 0));
        if (!fault) { assert(video_nodes==2 && core.pixel_dev); iris_pixel_master_unbind(&parent); }
        assert(!video_nodes && !core.pixel_dev && unbinds==(fault==BIND ? 0 : 1));
    }
    fault=0; child_present=false; assert(iris_pixel_master_add(&core)==-EINVAL); child_present=true;
    child_node.available=false; assert(iris_pixel_master_add(&core)==-EINVAL && !child_node.refs); child_node.available=true;
    child_node.compatible=false; assert(iris_pixel_master_add(&core)==-EINVAL && !child_node.refs); child_node.compatible=true;
    for (int f=MATCH; f<=MASTER; ++f) {
        fault=f; destroys=0;
        assert(iris_pixel_master_add(&core)==((f==MATCH || f==CREATE) ? -ENOMEM : -EREMOTEIO));
        clean_resources(&parent); assert(destroys==(f==ACTION || f==MASTER ? 1 : 0));
    }
    fault=0; assert(!iris_pixel_master_add(&core) && !video_nodes);
    iris_pixel_master_del(&core); clean_resources(&parent);
    assert(!allocation_cpu && !parent.refs && !child.dev.refs && allocations==2*frees);
    puts("Actual split DMA: decode/encode roles, allocation owners, VB2, HFI flags, domains and component failures passed");
}
C
${CC:-cc} -std=gnu11 -Wall -Wextra -Werror -Wno-unused-parameter \
    -I"$work/include" -I"$iris" "$work/check.c" -o "$work/check"
"$work/check"

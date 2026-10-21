#!/usr/bin/env bash
# Actual return/dispatch/free functions; host-only lists, DMA and VB2 providers.
set -Eeuo pipefail
iris=${1:?Pass the prepared Iris directory}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
{
cat <<'CPP'
#include <algorithm>
#include <cassert>
#include <cerrno>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <initializer_list>
#include <map>
#include <memory>
#include <new>
#include <set>
#include <vector>
using u8=std::uint8_t;
using u32=std::uint32_t;
using u64=std::uint64_t;
#define BIT(n) (1U << (n))
enum { DECODER=1, ENCODER=2, IRIS_INST_INIT=1, IRIS_INST_ERROR=2 };
CPP
for item in 'iris_buffer.h:iris_buffer_type' 'iris_buffer.h:iris_buffer_attributes' \
            'iris_hfi_common.h:hfi_packet_port_type' 'iris_hfi_common.h:hfi_packet_payload_info' \
            'iris_hfi_gen2_defines.h:hfi_buffer_type'; do
    file=${item%%:*}; name=${item#*:}
    awk -v name="$name" '$0 ~ "^enum " name " \\{" {emit=1} emit {print} emit && /^};/ {exit}' "$iris/$file"
done
for name in iris_hfi_packet iris_hfi_buffer; do
    awk -v name="$name" '$0 ~ "^struct " name " \\{" {emit=1} emit {print} emit && /^};/ {exit}' "$iris/iris_hfi_gen2_packet.h"
done
{
sed -n '/^#define HFI_CMD_BUFFER[[:space:]]/p' "$iris/iris_hfi_gen2_defines.h"
cat <<'CPP'
struct iris_buffer;
struct list_head { std::vector<iris_buffer *> items; list_head *head{}; iris_buffer *owner{}; };
struct device { unsigned refs{}; };
struct iris_buffer {
    list_head list;
    u32 type,attr;
    device *dma_dev;
    std::size_t buffer_size;
    void *kvaddr;
    u64 device_addr;
    unsigned long dma_attrs;
};
struct iris_buffers { list_head list; };
struct iris_inst { u32 domain,state; iris_buffers buffers[BUF_TYPE_MAX]; };
struct allocation { device *dev; std::size_t size; u64 address; unsigned long attrs; };
static std::map<void *,allocation> memory;
static std::set<iris_buffer *> live;
static unsigned frees,inputs,outputs;
static u64 next_address=0x100000;
#define list_for_each_entry(pos,head,member) \
    for (auto cursor=(head)->items.begin(); cursor!=(head)->items.end() && ((pos=*cursor),true); ++cursor)
static void list_del(list_head *node) {
    auto &v=node->head->items; auto p=std::find(v.begin(),v.end(),node->owner);
    assert(p!=v.end()); v.erase(p); node->head=nullptr;
}
static void dma_free_attrs(device *dev,std::size_t size,void *data,u64 address,unsigned long attrs) {
    auto p=memory.find(data); assert(p!=memory.end());
    assert(dev==p->second.dev && dev->refs && size==p->second.size);
    assert(address==p->second.address && attrs==p->second.attrs);
    delete[] static_cast<std::byte *>(data); memory.erase(p); ++frees;
}
static void put_device(device *dev) { assert(dev->refs); --dev->refs; }
static void kfree(iris_buffer *buf) { assert(live.erase(buf)==1); delete buf; }
static int iris_inst_change_state(iris_inst *i,u32 state) { i->state=state; return 0; }
static int iris_hfi_gen2_handle_input_buffer(iris_inst *,iris_hfi_buffer *) { ++inputs; return 0; }
static int iris_hfi_gen2_handle_output_buffer(iris_inst *,iris_hfi_buffer *) { ++outputs; return 0; }
CPP
}
{
    awk '/^int iris_destroy_internal_buffer\(/ {emit=1} emit {print} emit && /^}/ {exit}' "$iris/iris_buffer.c"
    awk '/^static u32 iris_hfi_gen2_get_port_from_buf_type\(/ {emit=1} emit {print} emit && /^}/ {exit}' "$iris/iris_hfi_gen2_command.c"
    for name in iris_hfi_gen2_buf_type_to_driver iris_hfi_gen2_is_valid_hfi_buffer_type \
                iris_hfi_gen2_is_valid_hfi_port iris_hfi_gen2_validate_packet_payload \
                iris_hfi_gen2_handle_release_internal_buffer iris_hfi_gen2_handle_session_buffer; do
        awk -v name="$name" '$0 ~ "^static (int|u32|bool) " name "\\(" {emit=1} emit {print} emit && /^}/ {exit}' "$iris/iris_hfi_gen2_response.c"
    done
} | sed 's/enum hfi_buffer_type buf_type/u32 buf_type/'
cat <<'CPP'
static iris_buffer *add(iris_inst &i,device &dev,u32 type,u32 attr) {
    auto *b=new iris_buffer{}; assert(live.insert(b).second);
    b->type=type; b->attr=attr; b->dma_dev=&dev; b->buffer_size=256;
    b->kvaddr=new std::byte[b->buffer_size]; b->device_addr=next_address; next_address+=0x1000;
    b->dma_attrs=0x42; ++dev.refs;
    assert(memory.emplace(b->kvaddr,allocation{&dev,b->buffer_size,b->device_addr,b->dma_attrs}).second);
    b->list.head=&i.buffers[type].list; b->list.owner=b; b->list.head->items.push_back(b);
    return b;
}
static int dispatch(iris_inst &i,u32 type,u32 port,u32 payload_info,std::size_t bytes,
                    const iris_hfi_buffer &buffer) {
    auto data=std::make_unique<std::byte[]>(sizeof(iris_hfi_packet)+bytes);
    auto *p=new(data.get()) iris_hfi_packet{};
    p->size=sizeof(*p)+bytes; p->type=HFI_CMD_BUFFER; p->port=port; p->payload_info=payload_info;
    std::memcpy(data.get()+sizeof(*p),&buffer,std::min(bytes,sizeof(buffer)));
    if (bytes>=sizeof(u32)) std::memcpy(data.get()+sizeof(*p),&type,sizeof(type));
    return iris_hfi_gen2_handle_session_buffer(&i,p);
}
int main() {
    for (u32 domain:{DECODER,ENCODER}) {
        iris_inst i{}; i.domain=domain; i.state=IRIS_INST_INIT; device owner{};
        for (auto hfi:{HFI_BUFFER_BIN,HFI_BUFFER_ARP,HFI_BUFFER_COMV,HFI_BUFFER_NON_COMV,
                      HFI_BUFFER_LINE,HFI_BUFFER_DPB,HFI_BUFFER_PERSIST,HFI_BUFFER_PARTIAL_DATA,HFI_BUFFER_VPSS}) {
            u32 type=iris_hfi_gen2_buf_type_to_driver(&i,hfi);
            auto *b=add(i,owner,type,BUF_ATTR_QUEUED);
            iris_hfi_buffer reply{}; reply.type=hfi; reply.base_address=b->device_addr;
            unsigned old=frees;
            // A STOP return relinquishes firmware ownership without requesting destruction.
            assert(!iris_hfi_gen2_handle_release_internal_buffer(&i,&reply));
            assert(live.contains(b) && frees==old && owner.refs==1 && !(b->attr & BUF_ATTR_QUEUED));
            assert(!iris_hfi_gen2_handle_release_internal_buffer(&i,&reply) && live.contains(b));
            b->attr|=BUF_ATTR_QUEUED|BUF_ATTR_PENDING_RELEASE;
            assert(!iris_hfi_gen2_handle_release_internal_buffer(&i,&reply));
            assert(!live.contains(b) && frees==old+1 && !owner.refs);
            assert(iris_hfi_gen2_handle_release_internal_buffer(&i,&reply)==-EINVAL && frees==old+1);
        }
        for (auto hfi:{HFI_BUFFER_PERSIST,HFI_BUFFER_ARP}) {
            u32 type=iris_hfi_gen2_buf_type_to_driver(&i,hfi);
            auto *b=add(i,owner,type,BUF_ATTR_QUEUED|BUF_ATTR_PENDING_RELEASE);
            iris_hfi_buffer reply{}; reply.base_address=b->device_addr;
            u32 port=iris_hfi_gen2_get_port_from_buf_type(&i,static_cast<iris_buffer_type>(type));
            assert(port==HFI_PORT_NONE && iris_hfi_gen2_is_valid_hfi_port(port,hfi));
            assert(!dispatch(i,hfi,port,HFI_PAYLOAD_STRUCTURE,sizeof(reply),reply));
            assert(!live.contains(b) && !owner.refs);
        }
        for (auto hfi:{HFI_BUFFER_BITSTREAM,HFI_BUFFER_RAW,HFI_BUFFER_BIN,HFI_BUFFER_DPB,HFI_BUFFER_VPSS})
            assert(!iris_hfi_gen2_is_valid_hfi_port(HFI_PORT_NONE,hfi));
        for (u32 type=1;type<=HFI_BUFFER_VPSS;++type) {
            assert(!iris_hfi_gen2_is_valid_hfi_port(3,type));
            assert(iris_hfi_gen2_is_valid_hfi_port(HFI_PORT_RAW,type));
            assert(iris_hfi_gen2_is_valid_hfi_port(HFI_PORT_BITSTREAM,type));
        }
        for (auto hfi:{HFI_BUFFER_BITSTREAM,HFI_BUFFER_RAW,HFI_BUFFER_METADATA}) {
            auto *b=add(i,owner,BUF_INPUT,BUF_ATTR_QUEUED|BUF_ATTR_PENDING_RELEASE);
            iris_hfi_buffer reply{}; reply.type=hfi; reply.base_address=b->device_addr;
            assert(iris_hfi_gen2_handle_release_internal_buffer(&i,&reply)==-EINVAL && live.contains(b));
            iris_destroy_internal_buffer(&i,b);
        }
        auto *b=add(i,owner,BUF_BIN,BUF_ATTR_QUEUED|BUF_ATTR_PENDING_RELEASE);
        iris_hfi_buffer reply{}; reply.type=HFI_BUFFER_BIN; reply.base_address=b->device_addr+1;
        unsigned old=frees; u32 attr=b->attr;
        assert(iris_hfi_gen2_handle_release_internal_buffer(&i,&reply)==-EINVAL);
        assert(frees==old && b->attr==attr && live.contains(b)); reply.base_address=b->device_addr;
        for (u32 payload:std::initializer_list<u32>{HFI_PAYLOAD_U32,HFI_PAYLOAD_U64,HFI_PAYLOAD_U32_ENUM,99U}) {
            i.state=IRIS_INST_INIT;
            assert(dispatch(i,HFI_BUFFER_BIN,HFI_PORT_BITSTREAM,payload,sizeof(u32),reply)==-EINVAL);
            assert(i.state==IRIS_INST_ERROR && frees==old && b->attr==attr);
        }
        for (std::size_t bytes=0;bytes<sizeof(reply);++bytes) {
            i.state=IRIS_INST_INIT;
            assert(dispatch(i,HFI_BUFFER_BIN,HFI_PORT_BITSTREAM,HFI_PAYLOAD_STRUCTURE,bytes,reply)==-EINVAL);
            assert(i.state==IRIS_INST_ERROR && frees==old && b->attr==attr);
        }
        i.state=IRIS_INST_INIT;
        assert(!dispatch(i,HFI_BUFFER_BIN,HFI_PORT_BITSTREAM,HFI_PAYLOAD_NONE,0,reply));
        assert(i.state==IRIS_INST_INIT && frees==old && b->attr==attr);
        for (auto hfi:{HFI_BUFFER_BITSTREAM,HFI_BUFFER_RAW}) {
            unsigned in=inputs,out=outputs;
            assert(!dispatch(i,hfi,HFI_PORT_BITSTREAM,HFI_PAYLOAD_STRUCTURE,sizeof(reply),reply));
            bool input=(domain==DECODER)==(hfi==HFI_BUFFER_BITSTREAM);
            assert(inputs==in+unsigned(input) && outputs==out+unsigned(!input) && frees==old);
        }
        assert(!dispatch(i,HFI_BUFFER_BIN,HFI_PORT_BITSTREAM,HFI_PAYLOAD_STRUCTURE,sizeof(reply),reply));
        assert(!owner.refs && live.empty() && memory.empty());
    }
}
CPP
} > "$work/check.cpp"
"${CXX:-g++}" -std=c++20 -O2 -Wall -Wextra -Werror -Wno-unused-parameter "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Actual Iris buffer returns: STOP reuse, requested free, control ports and payload rejection passed\n'

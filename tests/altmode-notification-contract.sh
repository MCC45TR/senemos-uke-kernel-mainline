#!/usr/bin/env bash
# Exercise the real callback with the observed DP header and strict ACK routing.
set -Eeuo pipefail
ulimit -c 0
source_file=${1:?Pass prepared drivers/soc/qcom/pmic_glink_altmode.c}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
cat > "$work/check.cpp" <<'CPP'
#include <cassert>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <initializer_list>
using u16=uint16_t;
using u32=uint32_t;
#define PMIC_GLINK_REQ_RESP 1
#define PMIC_GLINK_NOTIFY 2
#define USBC_CMD_WRITE_REQ 0x15
#define USBC_NOTIFY_IND 0x16
#define USBC_SC8180X_NOTIFY_IND 0x13
#define le32_to_cpu(value) (value)
#define spin_lock_irqsave(lock,flags) do {(void)(lock);(flags)=0;} while(0)
#define spin_unlock_irqrestore(lock,flags) do {(void)(lock);(void)(flags);} while(0)
struct pmic_glink_hdr { u32 owner,type,opcode; };
struct pmic_glink_altmode {
    u32 owner_id=32780;
    int event_lock=0,request_error=-1,pan_ack=0;
    bool pending=true,stopping=false,quarantined=false,online=true;
};
static unsigned modern=0,legacy=0,acks=0;
static u16 last_svid=0;
static size_t last_length=0;
static void complete(int *) { ++acks; }
static void pmic_glink_altmode_sc8280xp_notify(pmic_glink_altmode *,u16 svid,const void *,size_t len) {
    ++modern;last_svid=svid;last_length=len;
}
static void pmic_glink_altmode_sc8180xp_notify(pmic_glink_altmode *,const void *,size_t) { ++legacy; }
CPP
awk '/^static void pmic_glink_altmode_callback\(/ {emit=1} emit {print} emit && /^}/ {exit}' "$source_file" |
    sed -e 's/\*altmode = priv;/\*altmode = static_cast<pmic_glink_altmode *>(priv);/' \
        -e 's/\*hdr = data;/\*hdr = static_cast<const pmic_glink_hdr *>(data);/' >> "$work/check.cpp"
cat >> "$work/check.cpp" <<'CPP'
int main() {
    pmic_glink_altmode state;
    struct { pmic_glink_hdr hdr; unsigned char payload[20]; } packet{{32780,2,0xff010016},{}};
    static_assert(sizeof(packet)==32);
    pmic_glink_altmode_callback(&packet,sizeof(packet),&state);
    assert(modern==1 && last_svid==0xff01 && last_length==32 && !acks);
    packet.hdr.type=1;pmic_glink_altmode_callback(&packet,sizeof(packet),&state);
    assert(modern==2);
    for(u32 type:{0u,3u,UINT32_MAX}) {
        packet.hdr.type=type;pmic_glink_altmode_callback(&packet,sizeof(packet),&state);
    }
    packet.hdr.type=2;
    for(size_t len=0;len<sizeof(pmic_glink_hdr);len++)pmic_glink_altmode_callback(&packet,len,&state);
    pmic_glink_altmode_callback(nullptr,0,&state);
    packet.hdr.owner=32779;pmic_glink_altmode_callback(&packet,sizeof(packet),&state);
    assert(modern==2 && !acks);
    packet.hdr.owner=32780;packet.hdr.opcode=USBC_SC8180X_NOTIFY_IND;
    for(u32 type:{1u,2u}) { packet.hdr.type=type;pmic_glink_altmode_callback(&packet,sizeof(packet),&state); }
    packet.hdr.type=3;pmic_glink_altmode_callback(&packet,sizeof(packet),&state);
    assert(legacy==2);
    packet.hdr.opcode=USBC_CMD_WRITE_REQ;packet.hdr.type=2;
    pmic_glink_altmode_callback(&packet,sizeof(pmic_glink_hdr),&state);
    assert(!acks && state.pending && state.request_error==-1);
    packet.hdr.type=1;
    state.online=false;pmic_glink_altmode_callback(&packet,sizeof(packet),&state);
    state.online=true;state.stopping=true;pmic_glink_altmode_callback(&packet,sizeof(packet),&state);
    state.stopping=false;state.quarantined=true;pmic_glink_altmode_callback(&packet,sizeof(packet),&state);
    state.quarantined=false;state.pending=false;pmic_glink_altmode_callback(&packet,sizeof(packet),&state);
    assert(!acks);
    state.pending=true;packet.hdr.opcode=0xff010015;
    pmic_glink_altmode_callback(&packet,sizeof(packet),&state);assert(!acks);
    packet.hdr.opcode=USBC_CMD_WRITE_REQ;pmic_glink_altmode_callback(&packet,sizeof(pmic_glink_hdr),&state);
    assert(acks==1 && !state.pending && state.request_error==0);
    packet.hdr.opcode=0xff;pmic_glink_altmode_callback(&packet,sizeof(packet),&state);
    assert(acks==1 && modern==2 && legacy==2);
    puts("Actual type-2 DP notification, header admission and strict ACK lifecycle: passed");
}
CPP
"${CXX:-clang++}" -std=c++20 -O2 -Wall -Wextra -Werror "$work/check.cpp" -o "$work/check"
"$work/check"

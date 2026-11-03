#!/usr/bin/env bash
# Actual protocol and I2C/upload functions; synthetic image only, COPR execution.
set -Eeuo pipefail
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
mkdir -p "$work/linux"
cat > "$work/common.h" <<'C'
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
#define ARRAY_SIZE(a) (sizeof(a)/sizeof((a)[0]))
#define min_t(t,a,b) ((t)(a)<(t)(b)?(t)(a):(t)(b))
static inline u16 get_unaligned_le16(const void *p) { const u8 *b=p;return b[0]|((u16)b[1]<<8); }
static inline u32 get_unaligned_le32(const void *p) { const u8 *b=p;return b[0]|((u32)b[1]<<8)|((u32)b[2]<<16)|((u32)b[3]<<24); }
static inline u32 get_unaligned_be32(const void *p) { const u8 *b=p;return b[3]|((u32)b[2]<<8)|((u32)b[1]<<16)|((u32)b[0]<<24); }
static inline void put_unaligned_le16(u16 v,void *p) { u8 *b=p;b[0]=v;b[1]=v>>8; }
static inline void put_unaligned_le32(u32 v,void *p) { u8 *b=p;for(int i=0;i<4;i++)b[i]=v>>(8*i); }
static inline void put_unaligned_be32(u32 v,void *p) { u8 *b=p;for(int i=0;i<4;i++)b[3-i]=v>>(8*i); }
C
for name in errno minmax string types unaligned; do : > "$work/linux/$name.h"; done
printf '#include <asm-generic/errno.h>\n' > "$work/linux/errno.h"
cat > "$work/check.c" <<'C'
#include "common.h"
#include "nanosic-uke-protocol.h"
#define I2C_M_RD 1
struct i2c_adapter {};
struct i2c_client { struct i2c_adapter *adapter; u16 addr; };
struct i2c_msg { u16 addr,flags,len; u8 *buf; };
struct uke_nanosic { struct i2c_client *client; };
static unsigned transfers,writes,pace,start_commands,code_bytes;
static int fail_at,short_at,corrupt_state,boot_state,selected;
static const struct nanosic_firmware *active_fw;
static void memzero_explicit(void *p,size_t n) { memset(p,0,n); }
static bool fault(void) { return (int)transfers++==fail_at; }
static int i2c_master_send(struct i2c_client *c,const u8 *buf,size_t len) {
    assert(c->addr==0x4c&&len>=2&&len<=513&&buf[0]==0x5c);
    writes++;
    if(fault())return -EREMOTEIO;
    if((int)transfers-1==short_at)return len-1;
    const u8 *p=buf+1;
    switch(p[0]) {
    case 4: case 5: selected=p[0];assert(len==2);break;
    case 6: assert(len==66&&get_unaligned_le16(p+8)==0x8140);boot_state=1;break;
    case 7: {
        assert(len==513&&boot_state==1);
        u32 offset=get_unaligned_be32(p+1),count=get_unaligned_be32(p+5);
        assert(offset==code_bytes&&count<=503&&count&&offset+count<=active_fw->size);
        assert(!memcmp(p+9,active_fw->code+offset,count));
        for(unsigned i=9+count;i<512;i++)assert(!p[i]);
        code_bytes+=count;break;
    }
    case 8: assert(code_bytes==active_fw->size);boot_state=3;break;
    case 9: assert(boot_state==3);start_commands++;break;
    default: assert(false);
    }
    return len;
}
static int i2c_transfer(struct i2c_adapter *a,struct i2c_msg *msg,int count) {
    (void)a;
    assert(count==2&&msg[0].addr==0x4c&&msg[1].addr==0x4c);
    assert(msg[0].len==1&&msg[0].buf[0]==0x5c&&!msg[0].flags);
    assert(msg[1].len==1&&msg[1].flags==I2C_M_RD);
    if(fault())return -EREMOTEIO;
    if((int)transfers-1==short_at)return 1;
    msg[1].buf[0]=selected==4?0xc8:(corrupt_state?0xff:boot_state);
    return 2;
}
static void usleep_range(unsigned a,unsigned b) { assert(a==3000&&b==4000);pace++; }
static void msleep(unsigned n) { assert(n==10||n==50); }
C
for f in uke_nano_write uke_nano_read uke_nano_boot_cmd uke_nano_boot_value uke_nano_upload; do
    awk -v f="$f" '$0 ~ "^static int " f "\\(" {p=1} p{print} p&&/^}/{exit}' \
        "$owner/src/pogo/hid-nanosic-uke.c" >> "$work/check.c"
done
cat >> "$work/check.c" <<'C'
static void reset(void) {
    transfers=writes=pace=start_commands=code_bytes=0;
    fail_at=short_at=-1;corrupt_state=boot_state=selected=0;
}
int main(void) {
    const size_t bytes=0x8000+49972;
    u8 *image=calloc(1,bytes);assert(image);
    u8 *header=image+0x7fc0;memcpy(header,"NANO IC",7);
    put_unaligned_le16(0x8030,header+7);put_unaligned_le32(49972,header+48);
    u32 sum=0;for(unsigned i=0x8000;i<bytes;i++){image[i]=i;sum+=image[i];}
    put_unaligned_le32(sum,header+52);
    for(int i=0;i<63;i++)header[63]+=header[i];
    struct nanosic_firmware fw;assert(!nanosic_firmware_parse(image,bytes,&fw));active_fw=&fw;
    for(size_t size=0;size<0x8000;size+=37)assert(nanosic_firmware_parse(image,size,&fw)==-EINVAL);
    image[0x8000]^=1;assert(nanosic_firmware_parse(image,bytes,&fw)==-EBADMSG);image[0x8000]^=1;
    assert(!nanosic_firmware_parse(image,bytes,&fw));
    u8 block[512];assert(nanosic_firmware_chunk(&fw,fw.size,block)==-EINVAL);
    assert(nanosic_firmware_chunk(&fw,49797,block)==175);
    struct i2c_adapter adapter={};struct i2c_client client={.adapter=&adapter,.addr=0x4c};
    struct uke_nanosic n={.client=&client};
    reset();assert(!uke_nano_upload(&n,&fw)&&start_commands==1&&code_bytes==49972&&writes==pace);
    unsigned all=transfers;
    for(unsigned i=0;i<all;i++) {
        reset();fail_at=i;assert(uke_nano_upload(&n,&fw)==-EREMOTEIO&&!start_commands&&writes==pace);
        reset();short_at=i;assert(uke_nano_upload(&n,&fw)==-EIO&&!start_commands&&writes==pace);
    }
    reset();corrupt_state=1;assert(uke_nano_upload(&n,&fw)==-EPROTO&&!start_commands&&!code_bytes);
    u8 cmd[66],value=50;assert(!nanosic_uke_command(0x4e,0x23,&value,1,cmd)&&cmd[9]==0x8d);
    assert(nanosic_uke_command(0x4e,0x23,&value,58,cmd)==-EINVAL);
    u8 frame[68]={0x57,0,0x39,5};assert(nanosic_uke_report(frame,68)==9);
    for(size_t len=0;len<68;len++)assert(nanosic_uke_report(frame,len)==-EMSGSIZE);
    frame[3]=0x19;assert(nanosic_uke_report(frame,68)==21);
    frame[23]=4;assert(nanosic_uke_report(frame,68)==-EBADMSG);frame[23]=1;
    frame[5]=1;put_unaligned_le16(3200,frame+7);assert(nanosic_uke_report(frame,68)==-EBADMSG);
    frame[3]=0x24;frame[5]=0x38;frame[6]=0x80;frame[8]=60;assert(nanosic_uke_report(frame,68)==-EBADMSG);
    for(unsigned i=0;i<20000;i++) {
        for(unsigned j=0;j<68;j++)frame[j]=rand();
        (void)nanosic_uke_report(frame,68);
    }
    free(image);
    puts("PASS: actual firmware/parser, every short/failed I2C transfer, no start after failure, Uke pacing and bounded input; COPR only");
    return 0;
}
C
"${CC:-cc}" -std=gnu11 -O1 -Wall -Wextra -Werror -Wno-sign-compare \
    -I"$work" -I"$owner/src/pogo" ${CFLAGS:-} "$work/check.c" -o "$work/check"
"$work/check"

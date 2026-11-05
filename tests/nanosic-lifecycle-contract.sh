#!/usr/bin/env bash
# Actual authentication/output callbacks at synthetic lifecycle boundaries.
set -Eeuo pipefail
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
typedef uint8_t u8;typedef uint32_t u32;
#define READ_ONCE(v) (v)
#define UKE_AUTH_TIMEOUT 5000
#define UKE_KEEPALIVE 12000
#define SW_DOCK 5
#define container_of(p,t,m) ((t *)((char *)(p)-offsetof(t,m)))
struct mutex {bool held;};
enum led_brightness { LED_OFF=0, LED_FULL=100 };
struct led_classdev {};
struct device { void *data; int kobj; };
struct device_attribute {};
struct i2c_client {struct device dev;};
struct uke_nanosic {
    struct i2c_client *client;struct mutex lock;
    bool attached,suspended,removing,caps,lid_closed,folded,input_allowed,auth_pending,token_delivered;
    u8 requested_backlight,auth_phase;bool requested_micmute;
    u32 auth_epoch;unsigned long auth_deadline;
    u8 uid[16],challenge[16],host_challenge[16];
    int keepalive_work,backlight_work;void *dock;
    struct led_classdev backlight,micmute;
};
static unsigned long jiffies=100;static void *system_wq;
static unsigned commands,releases,notifications;static int command_error;
static u8 last_opcode,last_value;
static void mutex_lock(struct mutex *m) {assert(!m->held);m->held=true;}
static void mutex_unlock(struct mutex *m) {assert(m->held);m->held=false;}
static bool time_after_eq(unsigned long a,unsigned long b) {return (long)(a-b)>=0;}
static void memzero_explicit(void *p,size_t n) {memset(p,0,n);}
static void *dev_get_drvdata(struct device *d) {return d->data;}
static int uke_nano_cmd(struct uke_nanosic *n,u8 route,u8 op,const u8 *data,size_t len) {
    assert(n->lock.held);if(n->removing)return -ENODEV;if(n->suspended)return -EHOSTDOWN;
    assert(route==0x4f&&len<=20&&data);commands++;last_opcode=op;return command_error;
}
static int uke_nano_control(struct uke_nanosic *n,u8 op,u8 value) {
    assert(n->lock.held);if(n->removing)return -ENODEV;if(n->suspended)return -EHOSTDOWN;
    commands++;last_opcode=op;last_value=value;return command_error;
}
static void uke_nano_release_inputs(struct uke_nanosic *n) {assert(n->lock.held);releases++;}
static void input_report_switch(void *d,int code,bool value) {(void)d;(void)value;assert(code==SW_DOCK);}
static void input_sync(void *d) {(void)d;}
static void get_random_bytes(void *p,size_t len) {memset(p,0x55,len);}
static void mod_delayed_work(void *w,int *d,unsigned long t) {(void)w;(void)d;assert(t==UKE_KEEPALIVE);}
static void cancel_delayed_work(int *w) {(void)w;}
static void schedule_work(int *w) {(void)w;}
static void sysfs_notify(void *k,void *p,const char *s) {(void)k;(void)p;assert(!strcmp(s,"auth_request"));notifications++;}
static int sysfs_emit(char *buf,const char *format,...) {(void)buf;(void)format;return 1;}
static int hex2bin(u8 *out,const char *in,size_t len) {
    for(size_t i=0;i<len;i++){unsigned v;if(sscanf(in+i*2,"%2x",&v)!=1)return -EINVAL;out[i]=v;}return 0;
}
C
for f in uke_nano_invalidate_auth uke_nano_restore uke_nano_vendor uke_nano_backlight \
    uke_nano_micmute auth_request_show auth_token_store; do
    awk -v f="$f" '$0 ~ "^static (void|int|ssize_t) " f "\\(" {p=1} p{print} p&&/^}/{exit}' \
        "$owner/src/pogo/hid-nanosic-uke.c" >> "$work/check.c"
done
cat >> "$work/check.c" <<'C'
int main(void) {
    struct uke_nanosic n={0};struct i2c_client client={.dev={.data=&n}};n.client=&client;
    u8 report[65]={0x24,0,0x38,0x80};char buf[256];
    mutex_lock(&n.lock);
    report[4]=0x32;uke_nano_vendor(&n,report,38);assert(!n.auth_pending&&!commands);
    report[4]=0xa2;report[9]=1;uke_nano_vendor(&n,report,12);assert(n.attached&&!n.input_allowed&&!n.token_delivered);
    report[4]=0x24;uke_nano_vendor(&n,report,12);assert(n.auth_phase==1&&!n.auth_pending&&last_opcode==0x31);
    report[4]=0x31;uke_nano_vendor(&n,report,24);assert(n.auth_phase==2&&last_opcode==0x32);
    report[4]=0x32;uke_nano_vendor(&n,report,38);assert(n.auth_pending&&n.auth_phase==3&&notifications==1);
    u32 epoch=n.auth_epoch;mutex_unlock(&n.lock);
    assert(auth_request_show(&client.dev,NULL,buf)==1);
    snprintf(buf,sizeof(buf),"%u 00000000000000000000000000000000\n",epoch-1);
    assert(auth_token_store(&client.dev,NULL,buf,strlen(buf))==-ESTALE&&n.auth_pending);
    jiffies=n.auth_deadline;
    snprintf(buf,sizeof(buf),"%u 00000000000000000000000000000000\n",epoch);
    assert(auth_token_store(&client.dev,NULL,buf,strlen(buf))==-ESTALE);
    assert(auth_request_show(&client.dev,NULL,buf)==-ENODATA);
    mutex_lock(&n.lock);uke_nano_invalidate_auth(&n);n.suspended=true;mutex_unlock(&n.lock);
    assert(!uke_nano_backlight(&n.backlight,50)&&n.requested_backlight==50);
    assert(!uke_nano_micmute(&n.micmute,LED_FULL)&&n.requested_micmute);
    assert(uke_nano_backlight(&n.backlight,101)==-EINVAL);
    mutex_lock(&n.lock);n.suspended=false;assert(!uke_nano_restore(&n)&&!n.input_allowed&&last_opcode==0x23&&last_value==0);
    report[4]=0x24;uke_nano_vendor(&n,report,12);report[4]=0x31;uke_nano_vendor(&n,report,24);
    report[4]=0x32;uke_nano_vendor(&n,report,38);epoch=n.auth_epoch;mutex_unlock(&n.lock);
    snprintf(buf,sizeof(buf),"%u 00112233445566778899aabbccddeeff\n",epoch);
    assert(auth_token_store(&client.dev,NULL,buf,strlen(buf))==(ssize_t)strlen(buf)&&!n.auth_pending&&n.token_delivered&&n.input_allowed&&last_value==50);
    assert(auth_token_store(&client.dev,NULL,buf,strlen(buf))==-ESTALE);
    mutex_lock(&n.lock);
    n.folded=true;unsigned prior=releases;assert(!uke_nano_restore(&n)&&!n.input_allowed&&releases==prior+1&&last_value==0);
    n.folded=false;n.lid_closed=true;assert(!uke_nano_restore(&n)&&!n.input_allowed);
    n.lid_closed=false;assert(!uke_nano_restore(&n)&&n.input_allowed&&last_value==50);
    n.suspended=true;uke_nano_invalidate_auth(&n);n.suspended=false;
    assert(n.token_delivered&&!uke_nano_restore(&n)&&n.input_allowed); // MCU power/session survived sleep.
    report[4]=0xa2;report[9]=0;uke_nano_vendor(&n,report,12);mutex_unlock(&n.lock);
    assert(!n.attached&&!n.input_allowed&&!n.auth_pending&&!n.token_delivered);
    n.removing=true;unsigned before=commands;
    assert(auth_token_store(&client.dev,NULL,buf,strlen(buf))==-ENODEV);
    assert(auth_request_show(&client.dev,NULL,buf)==-ENODEV);
    assert(uke_nano_backlight(&n.backlight,30)==-ENODEV&&commands==before);
    puts("PASS: actual auth phases/epochs/expiry, stale-token rejection, cached outputs, lid/fold and detach/remove boundaries; COPR only");
}
C
"${CC:-cc}" -std=gnu11 -O1 -Wall -Wextra -Werror -Wno-sign-compare -Wno-unused-parameter ${CFLAGS:-} \
    "$work/check.c" -o "$work/check"
"$work/check"

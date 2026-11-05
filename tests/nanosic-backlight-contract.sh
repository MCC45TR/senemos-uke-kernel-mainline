#!/usr/bin/env bash
# COPR only: execute the real LED callbacks and asynchronous plug lifecycle.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
cat > "$stage/check.c" <<'C'
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
typedef uint8_t u8;
#define WRITE_ONCE(v,x) ((v)=(x))
#define container_of(p,t,m) ((t *)((char *)(p)-offsetof(t,m)))
struct mutex {bool held;};
struct work_struct {int unused;};
enum led_brightness {LED_OFF=0,LED_FULL=100};
struct led_classdev {
 const char *name;unsigned max_brightness;enum led_brightness brightness;
 int (*brightness_set_blocking)(struct led_classdev *,enum led_brightness);
 enum led_brightness (*brightness_get)(struct led_classdev *);
};
struct device {int unused;};
struct i2c_client {struct device dev;};
struct uke_nanosic {
 struct i2c_client *client;struct mutex lock;struct work_struct backlight_work;
 struct led_classdev backlight;bool attached,removing,suspended,input_allowed,backlight_registered;
 u8 requested_backlight;
};
static unsigned registrations,unregistrations,commands;
static bool live,detach_on_register;
static int register_error,command_error;
static void mutex_lock(struct mutex *m) {assert(!m->held);m->held=true;}
static void mutex_unlock(struct mutex *m) {assert(m->held);m->held=false;}
static int uke_nano_control(struct uke_nanosic *n,u8 op,u8 value) {
 assert(n->lock.held&&n->attached&&!n->removing&&!n->suspended&&n->input_allowed);
 assert(op==0x23&&value<=100);commands++;return command_error;
}
static void dev_warn(struct device *d,const char *s,int error) {(void)d;(void)s;assert(error==register_error);}
static int led_classdev_register(struct device *d,struct led_classdev *led) {
 struct uke_nanosic *n=container_of(led,struct uke_nanosic,backlight);
 assert(d==&n->client->dev&&!n->lock.held&&!live);
 assert(!strcmp(led->name,"uke-pogo::kbd_backlight")&&led->max_brightness==100);
 registrations++;if(register_error)return register_error;live=true;
 assert(led->brightness_get(led)==n->requested_backlight);
 if(detach_on_register)n->attached=false;
 return 0;
}
static void led_classdev_unregister(struct led_classdev *led) {
 struct uke_nanosic *n=container_of(led,struct uke_nanosic,backlight);
 assert(!n->lock.held&&live);unregistrations++;live=false;
 assert(led->brightness_set_blocking(led,LED_OFF)==0);
}
C
for fn in uke_nano_backlight uke_nano_backlight_get uke_nano_backlight_work; do
 awk -v fn="$fn" '$0~"^static (int|enum led_brightness|void) "fn"\\(" {p=1} p{print} p&&/^}/{exit}' \
   "$owner/src/pogo/hid-nanosic-uke.c" >> "$stage/check.c"
done
cat >> "$stage/check.c" <<'C'
int main(void) {
 struct i2c_client client={0};struct uke_nanosic n={.client=&client,.requested_backlight=37};
 uke_nano_backlight_work(&n.backlight_work);assert(!live&&!registrations);
 n.attached=true;n.input_allowed=true;uke_nano_backlight_work(&n.backlight_work);
 assert(live&&n.backlight_registered&&registrations==1&&n.backlight.brightness==37);
 uke_nano_backlight_work(&n.backlight_work);assert(registrations==1);
 assert(!uke_nano_backlight(&n.backlight,65)&&n.requested_backlight==65&&commands==1);
 command_error=-EIO;assert(uke_nano_backlight(&n.backlight,80)==-EIO&&n.requested_backlight==65);command_error=0;
 unsigned sent=commands;n.suspended=true;assert(!uke_nano_backlight(&n.backlight,42)&&commands==sent);
 n.suspended=false;n.input_allowed=false;assert(!uke_nano_backlight(&n.backlight,43)&&commands==sent);
 assert(uke_nano_backlight(&n.backlight,101)==-EINVAL&&commands==sent);
 n.attached=false;assert(uke_nano_backlight(&n.backlight,50)==-ENODEV);
 uke_nano_backlight_work(&n.backlight_work);assert(!live&&!n.backlight_registered&&unregistrations==1&&n.requested_backlight==43);
 n.attached=true;uke_nano_backlight_work(&n.backlight_work);assert(live&&n.backlight.brightness==43&&registrations==2);
 n.removing=true;uke_nano_backlight_work(&n.backlight_work);assert(!live&&unregistrations==2&&n.requested_backlight==43);
 n.removing=false;n.attached=true;detach_on_register=true;
 uke_nano_backlight_work(&n.backlight_work);assert(!live&&!n.backlight_registered&&unregistrations==3);
 detach_on_register=false;n.attached=true;register_error=-ENOMEM;
 uke_nano_backlight_work(&n.backlight_work);assert(!live&&!n.backlight_registered);
 register_error=0;uke_nano_backlight_work(&n.backlight_work);assert(live&&n.backlight_registered);
 n.removing=true;uke_nano_backlight_work(&n.backlight_work);assert(!live);
 puts("PASS: actual conditional LED registration, detach/register race, reconnect preference, suspended cache, range and transport errors; synthetic only");
}
C
"${CC:-cc}" -std=gnu11 -O1 -g -Wall -Wextra -Werror ${CFLAGS:-} "$stage/check.c" -o "$stage/check"
"$stage/check"

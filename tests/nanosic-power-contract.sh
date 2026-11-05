#!/usr/bin/env bash
# COPR only: actual OEM-order power callbacks and partial-failure ownership.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
cat > "$stage/check.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <errno.h>
struct device {int unused;};struct i2c_client {struct device dev;};
struct regulator {int id;};struct gpio_desc {int id;};
struct uke_nanosic {struct i2c_client *client;struct {struct regulator *consumer;} supplies[2];bool vdd_on,dvdd_on;struct gpio_desc *wake,*reset;};
static int events[20],used,fail_enable=-1,fail_disable=-1;
static int regulator_enable(struct regulator *r) {events[used++]=10+r->id;return fail_enable==r->id?-EIO:0;}
static int regulator_disable(struct regulator *r) {events[used++]=20+r->id;return fail_disable==r->id?-EIO:0;}
static void gpiod_set_value_cansleep(struct gpio_desc *g,int v) {assert(v==(g->id==1));events[used++]=30+g->id;}
static void dev_warn(struct device *d,const char *s,int e) {(void)d;(void)s;assert(e==-EIO);}
C
for fn in uke_nano_power_off uke_nano_power_on; do
 awk -v fn="$fn" '$0~"^static (void|int) "fn"\\(" {p=1} p{print} p&&/^}/{exit}' \
  "$owner/src/pogo/hid-nanosic-uke.c" >> "$stage/check.c"
done
cat >> "$stage/check.c" <<'C'
int main(void) {
 struct i2c_client client={0};struct regulator vdd={0},dvdd={1};struct gpio_desc wake={0},reset={1};
 struct uke_nanosic n={.client=&client,.supplies={{&vdd},{&dvdd}},.wake=&wake,.reset=&reset};
 assert(!uke_nano_power_on(&n)&&n.vdd_on&&n.dvdd_on&&used==2&&events[0]==10&&events[1]==11);
 uke_nano_power_off(&n);assert(!n.vdd_on&&!n.dvdd_on&&events[4]==21&&events[5]==20);
 used=0;fail_enable=0;assert(uke_nano_power_on(&n)==-EIO&&!n.vdd_on&&!n.dvdd_on&&used==1);
 used=0;fail_enable=1;assert(uke_nano_power_on(&n)==-EIO&&n.vdd_on&&!n.dvdd_on);
 uke_nano_power_off(&n);assert(!n.vdd_on&&!n.dvdd_on&&events[4]==20);
 used=0;fail_enable=-1;assert(!uke_nano_power_on(&n));fail_disable=1;
 uke_nano_power_off(&n);assert(n.vdd_on&&n.dvdd_on&&used==5); // Keep first rail while second refuses stop.
 fail_disable=-1;uke_nano_power_off(&n);assert(!n.vdd_on&&!n.dvdd_on);
 puts("PASS: actual Uke3.3V-before1.8V ordering, reverse stop, partial enable unwind and refused-disable vote retention; synthetic only");
}
C
"${CC:-cc}" -std=gnu11 -O1 -g -Wall -Wextra -Werror ${CFLAGS:-} "$stage/check.c" -o "$stage/check"
"$stage/check"

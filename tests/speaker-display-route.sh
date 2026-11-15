#!/usr/bin/bash
# COPR-only actual transaction header; no ALSA, firmware or device access.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(realpath "${1:?Native source profile}")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/test.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include "uke-speaker-display.h"
struct fake { unsigned value[4], sets, reads, faults; int fail_set, fail_get; bool partial, rollback_fault; };
static int get(void *p, unsigned i, unsigned *turn) {
 struct fake *f=p; unsigned call=f->reads++;
 if ((int)call==f->fail_get) return -ENODEV;
 *turn=f->value[i]; return 0;
}
static int set(void *p, unsigned i, unsigned turn) {
 struct fake *f=p; unsigned call=f->sets++;
 if ((int)call==f->fail_set) { if(f->partial)f->value[i]=turn; return -EIO; }
 if(f->rollback_fault && (int)call>f->fail_set)return -ETIMEDOUT;
 f->value[i]=turn;return 1;
}
static void fault(void *p) { ((struct fake *)p)->faults++; }
static const struct uke_display_route_ops ops={get,set,fault};
static struct fake fresh(void) { return (struct fake){.fail_set=-1,.fail_get=-1}; }
int main(void) {
 unsigned cases=0;
 for(unsigned from=0;from<4;from++)for(unsigned to=0;to<4;to++) {
  struct fake f=fresh();for(unsigned i=0;i<4;i++)f.value[i]=from;
  assert(uke_display_route(&f,&ops,to)==(from!=to));
  for(unsigned i=0;i<4;i++)assert(f.value[i]==to);
  assert(!f.faults);cases++;
 }
 for(int fail=0;fail<4;fail++)for(unsigned partial=0;partial<2;partial++) {
  struct fake f=fresh();f.fail_set=fail;f.partial=partial;
  assert(uke_display_route(&f,&ops,3)==-EIO);
  for(unsigned i=0;i<4;i++)assert(f.value[i]==0);
  assert(!f.faults);cases++;
  f=fresh();f.fail_set=fail;f.partial=partial;f.rollback_fault=true;
  assert(uke_display_route(&f,&ops,3)==-EIO);assert(f.faults==1);cases++;
 }
 for(int fail=0;fail<8;fail++) {
  struct fake f=fresh();f.fail_get=fail;
  assert(uke_display_route(&f,&ops,2)==-ENODEV);
  for(unsigned i=0;i<4;i++)assert(f.value[i]==0);
  assert(!f.faults);if(fail<4)assert(!f.sets);cases++;
 }
 {struct fake f=fresh();assert(uke_display_route(&f,&ops,4)==-EINVAL);assert(!f.sets&&!f.reads);cases++;}
 {struct fake f=fresh();f.value[3]=4;assert(uke_display_route(&f,&ops,0)==-EPROTO);assert(!f.sets);cases++;}
 printf("Actual speaker display routing: %u cases passed; no physical channel acceptance.\n",cases);
}
C
for cc in gcc clang; do
 for sanitize in 0 1; do
  flags=()
  if [[ $sanitize == 1 ]]; then flags=(-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer);fi
  "$cc" -std=c11 -O2 -Wall -Wextra -Werror -UNDEBUG "${flags[@]}" -I"$owner/src/audio" "$work/test.c" -o "$work/test"
  "$work/test"
  printf 'Native speaker display routing passed:%s/sanitize%s.\n' "$cc" "$sanitize"
 done
done

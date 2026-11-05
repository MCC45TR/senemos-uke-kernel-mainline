#!/usr/bin/env bash
# COPR only: actual status callback, synthetic cache/guard; no sensor/unit data.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
source_file=${1:-$owner/src/audio/uke-fs19xx-runtime.c}
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
ulimit -c 0
cat > "$stage/check.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include "uke-fs19xx-protocol.h"
#include "uke-fs19xx-safety.h"
struct mutex { bool held; };
static void mutex_lock(struct mutex *p) { assert(!p->held); p->held=true; }
static void mutex_unlock(struct mutex *p) { assert(p->held); p->held=false; }
static struct mutex *take_lock(struct mutex *p) { mutex_lock(p); return p; }
static void drop_lock(struct mutex **p) { mutex_unlock(*p); }
#define guard(t) struct mutex *held_guard __attribute__((cleanup(drop_lock)))=take_lock
struct q6apm_fs19xx {
 struct mutex lock;
 struct uke_fs19xx_state data;
 void *owner;
 bool removing, admitted;
};
struct q6apm { struct q6apm_fs19xx *fs19xx; };
struct device { struct q6apm *data; };
struct snd_soc_component { struct device *dev; };
struct snd_kcontrol { struct snd_soc_component *component; };
struct snd_ctl_elem_value { union { struct { unsigned int item[1]; } enumerated; } value; };
static struct snd_soc_component *snd_kcontrol_chip(struct snd_kcontrol *p) { return p->component; }
static struct q6apm *dev_get_drvdata(struct device *p) { return p->data; }
static struct mutex fs19xx_guard_lock;
static struct uke_fs_guard fs19xx_guard;
static struct q6apm_fs19xx *expected_fs;
static unsigned int snapshots;
static void take_guard(struct mutex *p) { assert(expected_fs->lock.held); mutex_lock(p); snapshots++; }
#define spin_lock_irqsave(p,f) ((f)=0,take_guard(p))
#define spin_unlock_irqrestore(p,f) ((void)(f),mutex_unlock(p))
C
awk '/^static int fs19xx_state_get\(/ {emit=1} emit {print} emit && /^}/ {exit}' "$source_file" > "$stage/function.c"
grep -Fq 'static int fs19xx_state_get(' "$stage/function.c"
cat "$stage/function.c" >> "$stage/check.c"
cat >> "$stage/check.c" <<'C'
int main(void)
{
 struct q6apm_fs19xx fs={0}; struct q6apm apm={&fs};
 struct device dev={&apm}; struct snd_soc_component component={&dev};
 struct snd_kcontrol control={&component}; struct snd_ctl_elem_value value={0};
 expected_fs=&fs;
 /* Actual normal-close interleaving: quiesce returned, close has not released
  * the owner/cache yet. Neither this nor a cached status proves VI samples. */
 fs.admitted=true; fs.owner=&apm; fs.data.status=UKE_FS_RUNNING;
 fs19xx_guard.mode=0;
 assert(!fs19xx_state_get(&control,&value));
 if(value.value.enumerated.item[0]==UKE_FS_RUNNING)
  fputs("Status overstates RUNNING after the actual guard is closed\n",stderr);
 assert(value.value.enumerated.item[0]==UKE_FS_READY);
 unsigned cases=0;
 for(unsigned state=UKE_FS_EMPTY;state<=UKE_FS_FAULT;state++)
 for(unsigned mode=0;mode<=2;mode++)
 for(unsigned bits=0;bits<16;bits++) {
  bool faulted=bits&1, admitted=bits&2, owner=bits&4, removing=bits&8;
  fs.data.status=state; fs.admitted=admitted; fs.removing=removing; fs.owner=owner?&apm:NULL;
  fs19xx_guard=(struct uke_fs_guard){.generation=17,.mode=mode,.faulted=faulted};
  struct uke_fs_guard before_guard=fs19xx_guard;
  struct uke_fs19xx_state before_data=fs.data;
  unsigned expected=faulted?UKE_FS_FAULT:state;
  if(!faulted&&state==UKE_FS_RUNNING&&(!admitted||!owner||removing||mode!=2)) expected=UKE_FS_READY;
  unsigned before_snapshots=snapshots;
  assert(!fs19xx_state_get(&control,&value));
  assert(value.value.enumerated.item[0]==expected&&snapshots==before_snapshots+1);
  assert(!memcmp(&fs.data,&before_data,sizeof before_data));
  assert(fs19xx_guard.generation==before_guard.generation&&fs19xx_guard.mode==before_guard.mode&&fs19xx_guard.faulted==before_guard.faulted);
  assert(fs.owner==(owner?&apm:NULL)&&fs.admitted==admitted&&fs.removing==removing);
  assert(!fs.lock.held&&!fs19xx_guard_lock.held);
  cases++;
 }
 assert(cases==288);
 puts("Actual speaker state callback: close interleaving,288 guard/cache/admission/lifetime cases, fault precedence and read-only locked snapshot pass; no telemetry/hardware");
}
C
"${CC:-clang}" -std=gnu11 -Wall -Wextra -Werror -fsanitize=address,undefined \
 -fno-sanitize-recover=all -fno-omit-frame-pointer -I "$owner/src/audio" "$stage/check.c" -o "$stage/check"
"$stage/check"

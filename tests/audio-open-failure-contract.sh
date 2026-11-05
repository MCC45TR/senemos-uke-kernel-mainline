#!/usr/bin/env bash
# COPR only: run actual failed-OPEN and release bodies with synthetic state.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
profile=$kernel/native-profile
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
source_file=$kernel/sound/soc/qcom/qdsp6/q6apm.c
awk '/^static struct audioreach_graph \*q6apm_get_audioreach_graph\(/ {copy=1}
 copy {print;if($0=="}")exit}' "$source_file" > "$work/get.c"
grep -Fq 'q6apm_fs19xx_release(graph);' "$work/get.c"
! grep -Fq 'q6apm_fs19xx_shutdown(apm);' "$work/get.c"
awk '/^void q6apm_fs19xx_release\(/ {copy=1}
 copy {print;if($0=="}")exit}' "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c" > "$work/release.c"
awk '/^void q6apm_fs19xx_shutdown\(/ {copy=1}
 copy {print;if($0=="}")exit}' "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c" > "$work/shutdown.c"
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <limits.h>
#define GFP_KERNEL 0
#define ERR_PTR(e) ((void *)(intptr_t)(e))
#define IS_ERR(p) ((uintptr_t)(p)>=(uintptr_t)-4095)
#define PTR_ERR(p) ((intptr_t)(p))
#define ERR_CAST(p) ((void *)(p))
#define kzalloc_obj(v) calloc(1,sizeof(v))
#define kfree free
#define guard(t) int lock_guard __attribute__((unused)) = (int)(intptr_t)
#define dev_err(...) ((void)0)
enum { UKE_FS_READY=2,UKE_FS_PREPARED,UKE_FS_RUNNING,UKE_FS_FAULT };
struct audioreach_graph;
struct snapshot { int status; unsigned char calibration[96]; };
struct q6apm_fs19xx { bool admitted,removing; int lock; struct audioreach_graph *owner; struct snapshot data; };
struct idr { void *entry; unsigned id; };
struct q6apm { struct q6apm_fs19xx *fs19xx; struct idr graph_idr,graph_info_idr; int cmd_lock,lock,dev; };
struct audioreach_graph_info { int unused; };
struct kref { int count; };
struct audioreach_graph { struct q6apm *apm; struct audioreach_graph_info *info; unsigned id; void *graph; int state; struct kref refcount; };
static unsigned gates,sends,claims;
static int response=-EINVAL;
static void fs19xx_gate(int value) { assert(value==0);gates++; }
static void uke_fs19xx_erase(struct snapshot *data) { memset(data,0,sizeof(*data)); }
static void mutex_lock(int *lock) { assert(!*lock);*lock=1; }
static void mutex_unlock(int *lock) { assert(*lock);*lock=0; }
static void *idr_find(struct idr *idr,unsigned id) { return idr->entry && idr->id==id?idr->entry:NULL; }
static int idr_alloc(struct idr *idr,void *entry,unsigned begin,unsigned end,int flags) {
 (void)flags; assert(!idr->entry && end==begin+1);idr->entry=entry;idr->id=begin;return begin;
}
static void kref_init(struct kref *ref) { ref->count=1; }
static bool kref_get_unless_zero(struct kref *ref) { if(!ref->count)return false;ref->count++;return true; }
static int q6apm_fs19xx_claim(struct audioreach_graph *graph) {
 claims++;if(graph->id==40) { assert(!graph->apm->fs19xx->owner);graph->apm->fs19xx->owner=graph; }return 0;
}
static void *audioreach_alloc_graph_pkt(struct q6apm *apm,struct audioreach_graph_info *info) {
 (void)apm;(void)info;return malloc(1);
}
static int q6apm_send_cmd_sync(struct q6apm *apm,void *packet,int opcode) {
 (void)apm;(void)packet;(void)opcode;sends++;return response;
}
#include "release.c"
#include "shutdown.c"
#include "get.c"
static void trial(unsigned id,int error) {
 struct q6apm_fs19xx fs={.admitted=true,.data={.status=UKE_FS_READY}};
 struct audioreach_graph_info info={0};
 struct q6apm apm={.fs19xx=&fs,.graph_info_idr={.entry=&info,.id=id}};
 struct audioreach_graph unrelated={.id=40};
 memset(fs.data.calibration,0x5a,sizeof(fs.data.calibration));
 if(id!=40)fs.owner=&unrelated;
 const struct snapshot before=fs.data;response=error;gates=sends=claims=0;
 assert(PTR_ERR(q6apm_get_audioreach_graph(&apm,id))==error);
 struct audioreach_graph *quarantined=apm.graph_idr.entry;
 assert(quarantined && quarantined->state==error && !fs.removing && sends==1 && claims==1);
 if(id==40) {
  assert(!fs.owner && gates==1 && fs.data.status==UKE_FS_FAULT);
  for(unsigned i=0;i<sizeof(fs.data.calibration);i++)assert(!fs.data.calibration[i]);
 } else assert(fs.owner==&unrelated && !gates && !memcmp(&before,&fs.data,sizeof(before)));
 assert(PTR_ERR(q6apm_get_audioreach_graph(&apm,id))==error);
 assert(sends==1 && claims==1 && apm.graph_idr.entry==quarantined);
 free(quarantined->graph);free(quarantined);
}
int main(void) {
 for(unsigned id=0;id<=40;id++)for(unsigned e=0;e<3;e++)trial(id,e==0?-EINVAL:e==1?-ETIMEDOUT:-ENODEV);
 puts("Actual failed OPEN: unrelated speaker state retained; protected fault mutes/erases; all failed IDs stay quarantined.");
}
C
for compiler in gcc clang; do
 "$compiler" -std=gnu11 -O1 -g -Wall -Wextra -Werror -Wno-sign-compare \
  -fsanitize=address,undefined -fno-sanitize-recover=all -I"$work" "$work/check.c" -o "$work/$compiler"
 ASAN_OPTIONS=detect_leaks=1:halt_on_error=1 "$work/$compiler"
done
cp "$work/get.c" "$work/get.fixed"
sed 's/q6apm_fs19xx_release(graph);/q6apm_fs19xx_shutdown(apm);/g' "$work/get.fixed" > "$work/get.c"
gcc -std=gnu11 -O1 -g -Wall -Wextra -Werror -Wno-sign-compare -I"$work" "$work/check.c" -o "$work/before"
ulimit -c 0
set +e
"$work/before" > "$work/before.log" 2>&1
before=$?
set -e
[[ $before == 134 ]]
grep -Fq '!fs.removing' "$work/before.log"
printf 'Original provider-wide failed-OPEN cleanup fails the same unrelated-graph assertion134.\n'

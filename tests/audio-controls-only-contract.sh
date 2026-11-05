#!/usr/bin/env bash
# Actual admission/graph callbacks; fake allocation/state only, no device I/O.
set -Eeuo pipefail
export LC_ALL=C
ulimit -c 0
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
source_file=${1:-$owner/src/audio/uke-fs19xx-runtime.c}
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
cat > "$stage/check.c" <<'C'
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "uke-fs19xx-protocol.h"
#include "uke-fs19xx-safety.h"
typedef uint8_t u8; typedef uint32_t u32;
#define GFP_KERNEL 0
#define IS_ERR(p) ((intptr_t)(p)<0)
#define PTR_ERR(p) ((intptr_t)(p))
#define EXPORT_SYMBOL_GPL(x)
struct mutex { bool held; };
static unsigned locks,gates,sends;
static void mutex_init(struct mutex *m){m->held=false;}
static struct mutex *acquire_mutex(struct mutex *m){assert(!m->held);m->held=true;locks++;return m;}
static void cleanup_mutex(struct mutex **m){assert((*m)->held);(*m)->held=false;}
#define guard(t) struct mutex *guard_value __attribute__((cleanup(cleanup_mutex)))=acquire_mutex
struct crypto_shash { int unused; };
struct device { void *of_node; };
struct q6apm_fs19xx;
struct q6apm { struct device *dev; struct q6apm_fs19xx *fs19xx; };
struct audioreach_graph { struct q6apm *apm; unsigned id; int state; void *info; };
struct q6apm_graph { struct q6apm *apm; unsigned id; struct audioreach_graph *ar_graph; };
static bool uke,dt_admitted;
static bool __attribute__((unused)) of_machine_is_compatible(const char *s){assert(!strcmp(s,"xiaomi,uke"));return uke;}
static bool __attribute__((unused)) of_property_read_bool(void *p,const char *s){(void)p;assert(!strcmp(s,"xiaomi,fs19xx-protected"));return dt_admitted;}
static void *devm_kzalloc(struct device *d,size_t n,int f){(void)d;(void)f;return calloc(1,n);}
static struct crypto_shash hash;
static struct crypto_shash *crypto_alloc_shash(const char *n,int a,int b){assert(!strcmp(n,"sha256")&&!a&&!b);return &hash;}
static void fs19xx_free_hash(void *p){(void)p;}
static int devm_add_action_or_reset(struct device *d,void(*fn)(void*),void*p){(void)d;(void)fn;(void)p;return 0;}
static int fs19xx_gate(unsigned n){(void)n;gates++;return 0;}
static int fs19xx_send(void *ctx,u32 iid,u32 param,const u8 *data,size_t n){(void)ctx;(void)iid;(void)param;(void)data;(void)n;sends++;return 0;}
#define list_for_each_entry(pos,head,member) for((pos)=NULL;(pos)!=NULL;(pos)=NULL)
struct audioreach_sub_graph { unsigned direction; };
struct audioreach_container { unsigned capability_id,proc_domain,graph_pos; };
struct audioreach_module {
 unsigned module_id,instance_id,hw_interface_type,hw_interface_idx,slot_mask,nslots_per_frame,slot_width,sync_src,data_format,ctrl_data_out_enable,sync_mode,ctrl_invert_sync_pulse,ctrl_sync_data_delay,active_lane_mask,src_mod_inst_id,max_ip_port,max_op_port,num_connections;
 unsigned src_mod_op_port_id[1],dst_mod_inst_id[1],dst_mod_ip_port_id[1];
 struct { unsigned first_instance,second_instance,first_port,second_port,intent,heap; } ctrl_link;
};
#define MODULE_ID_TDM_SINK 1
#define MODULE_ID_TDM_SOURCE 2
#define MODULE_ID_MFC 3
C
awk '/^struct q6apm_fs19xx \{/ {emit=1} emit {print} emit && /^};/ {exit}' "$source_file" >> "$stage/check.c"
for function in q6apm_fs19xx_init q6apm_fs19xx_graph q6apm_fs19xx_claim q6apm_fs19xx_prepare q6apm_fs19xx_prepared q6apm_fs19xx_started q6apm_fs19xx_stopped q6apm_fs19xx_quiesce q6apm_fs19xx_release q6apm_fs19xx_shutdown; do
 awk -v name="$function" '$0 ~ "^(int|bool|void) "name"\\(" {emit=1} emit {print} emit && /^}/ {exit}' "$source_file" >> "$stage/check.c"
 grep -Fq "$function(" "$stage/check.c"
done
if [[ ${UKE_AUDIO_TEST_MUTANTS:-0} == 1 ]]; then
 for mutation in graph claim force foreign; do
  case "$mutation" in
   graph) sed 's/graph->apm->fs19xx->admitted \&\& //g' "$source_file" > "$stage/mutant.c";;
   claim) sed 's/!fs || !fs->admitted || graph->id != 40/!fs || graph->id != 40/g' "$source_file" > "$stage/mutant.c";;
   force) sed 's/fs->admitted = false;/fs->admitted = true;/' "$source_file" > "$stage/mutant.c";;
   foreign) sed 's/if (!of_machine_is_compatible("xiaomi,uke"))/if (false)/' "$source_file" > "$stage/mutant.c";;
  esac
  if UKE_AUDIO_TEST_MUTANTS=0 bash "$0" "$stage/mutant.c" > "$stage/mutant.log" 2>&1; then
   echo "Unsafe admission mutant passed: $mutation" >&2; exit 1
  fi
  grep -q 'Assertion.*failed' "$stage/mutant.log"
 done
 printf '%s\n' 'Four compiled admission/interception mutants rejected by actual callback assertions.'
fi
cat >> "$stage/check.c" <<'C'
int main(void){
 struct device dev={0};struct q6apm apm={.dev=&dev};
 uke=false;dt_admitted=true;assert(q6apm_fs19xx_init(&apm)==0&&!apm.fs19xx);
 uke=true;dt_admitted=false;assert(q6apm_fs19xx_init(&apm)==0&&apm.fs19xx&&!apm.fs19xx->admitted);
 struct q6apm_fs19xx *fs=apm.fs19xx;free(fs);apm.fs19xx=NULL;
 dt_admitted=true;assert(q6apm_fs19xx_init(&apm)==0&&apm.fs19xx);
 fs=apm.fs19xx;
#ifdef UKE_FS19XX_CONTROLS_ONLY
 assert(!fs->admitted); /* Even a stray DT flag cannot activate this build. */
#else
 assert(fs->admitted);
#endif
 struct audioreach_graph ar={.apm=&apm,.id=40,.state=0};
 struct q6apm_graph graph={.apm=&apm,.id=40,.ar_graph=&ar};
 fs->admitted=false; /* Poison cached state: inactive callbacks must stay inert. */
 fs->data.status=UKE_FS_RUNNING;fs->owner=&ar;
 unsigned before_locks=locks;
 for(unsigned id=0;id<64;id++){
  ar.id=id;graph.id=id;
  assert(!q6apm_fs19xx_graph(&graph));assert(!q6apm_fs19xx_claim(&ar));
  assert(!q6apm_fs19xx_prepare(&graph));assert(!q6apm_fs19xx_prepared(&graph));assert(!q6apm_fs19xx_started(&graph));
  q6apm_fs19xx_stopped(&graph,true);q6apm_fs19xx_quiesce(&ar);q6apm_fs19xx_release(&ar);
  assert(fs->data.status==UKE_FS_RUNNING&&fs->owner==&ar&&!gates&&!sends&&locks==before_locks);
 }
#ifndef UKE_FS19XX_CONTROLS_ONLY
 fs->admitted=true;ar.id=40;graph.id=40;fs->owner=NULL;fs->data.status=UKE_FS_EMPTY;
 assert(q6apm_fs19xx_graph(&graph));assert(q6apm_fs19xx_claim(&ar)==-ENODATA);
 assert(q6apm_fs19xx_prepared(&graph)==-ENODATA&&q6apm_fs19xx_started(&graph)==-ENODATA);
 fs->owner=&ar;fs->data.status=UKE_FS_PREPARED;assert(!q6apm_fs19xx_started(&graph)&&fs->data.status==UKE_FS_RUNNING);
#endif
 fs->data.re25[0]=23;q6apm_fs19xx_shutdown(&apm);assert(fs->removing&&!fs->data.re25[0]);free(fs);
 puts("Actual Uke controls-only callbacks: no legacy graph interception, DSP send or gate change; private cache erased on shutdown.");
}
C
for mode in controls active; do
 flags=();[[ $mode != controls ]] || flags+=(-DUKE_FS19XX_CONTROLS_ONLY)
 "${CC:-cc}" -std=gnu11 -Wall -Wextra -Werror -fsanitize=address,undefined -fno-sanitize-recover=all \
  -fno-omit-frame-pointer -I"$owner/src/audio" "${flags[@]}" "$stage/check.c" -o "$stage/check"
 "$stage/check"
done

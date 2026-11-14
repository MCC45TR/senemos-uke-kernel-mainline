/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual machine callbacks, with controlled ALSA/backend providers. */
#include <assert.h>
#include <errno.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define GFP_KERNEL 0
#define SECONDARY_TDM_RX_0 40
#define SNDRV_CTL_EVENT_MASK_VALUE 1
#define SNDRV_CTL_ELEM_TYPE_ENUMERATED 3
struct mutex { pthread_mutex_t value; };
static struct mutex *lock_mutex(struct mutex *m) { assert(!pthread_mutex_lock(&m->value));return m; }
static void unlock_mutex(struct mutex **m) { assert(!pthread_mutex_unlock(&(*m)->value)); }
#define guard(type) struct mutex *held __attribute__((cleanup(unlock_mutex))) = lock_mutex
struct snd_ctl_elem_value { union { struct { unsigned int item[4]; } enumerated; } value; };
struct snd_ctl_elem_info { unsigned int type,count; union { struct { unsigned int item,items; char name[16]; } enumerated; } value; };
struct snd_soc_card;
struct snd_kcontrol {
 int (*get)(struct snd_kcontrol *,struct snd_ctl_elem_value *);
 int (*put)(struct snd_kcontrol *,struct snd_ctl_elem_value *);
 int (*info)(struct snd_kcontrol *,struct snd_ctl_elem_info *);
 unsigned int id; struct snd_soc_card *card;
};
struct snd_kcontrol_new { const char *name; int (*get)(struct snd_kcontrol *,struct snd_ctl_elem_value *); int (*put)(struct snd_kcontrol *,struct snd_ctl_elem_value *); const void *enum_data; };
#define SOC_ENUM_SINGLE_EXT_DECL(name,strings) const void *name = (strings)
#define SOC_ENUM_EXT(n,e,g,p) {n,g,p,&e}
struct snd_soc_dai_ops { bool set_channel_map,get_channel_map; };
struct snd_soc_dai_driver { const struct snd_soc_dai_ops *ops; };
struct snd_soc_dai { unsigned int id; const struct snd_soc_dai_driver *driver; };
struct snd_soc_dai_link { bool no_pcm; };
struct snd_soc_pcm_runtime { struct snd_soc_dai *cpu; struct snd_soc_dai_link *dai_link; struct snd_soc_pcm_runtime *next; };
struct uke_speaker_data { struct mutex rotation_lock; struct snd_kcontrol *rotation_controls[4]; struct snd_soc_dai *rotation_dai; struct snd_soc_card *card; };
struct snd_soc_card { struct uke_speaker_data *data; struct snd_soc_pcm_runtime *rtd; void *snd_card; };
#define for_each_card_rtds(card,rtd) for((rtd)=(card)->rtd;(rtd);(rtd)=(rtd)->next)
static struct snd_soc_dai *snd_soc_rtd_to_cpu(struct snd_soc_pcm_runtime *rtd,int index) { assert(!index);return rtd->cpu; }
static void *snd_kcontrol_chip(struct snd_kcontrol *c) { return c->card; }
static struct uke_speaker_data *snd_soc_card_get_drvdata(struct snd_soc_card *c) { return c->data; }
static void *kzalloc(size_t n,int flags) { (void)flags;return calloc(1,n); }
static void kfree(void *p) { free(p); }
static unsigned int amp[4],turn,reads,sets,maps,faults,notifications,registered;
static int fail_read=-1,fail_set=-1,fail_map=-1;
static bool partial,fail_rollback;
static struct snd_kcontrol controls[4];
static int amp_get(struct snd_kcontrol *c,struct snd_ctl_elem_value *v) {
 unsigned int call=reads++;
 if((int)call==fail_read)return -ENODEV;
 v->value.enumerated.item[0]=amp[c->id];return 0;
}
static int amp_put(struct snd_kcontrol *c,struct snd_ctl_elem_value *v) {
 unsigned int call=sets++,value=v->value.enumerated.item[0];
 if((int)call==fail_set){if(partial)amp[c->id]=value;return -EIO;}
 if(fail_rollback && (int)call>fail_set)return -ETIMEDOUT;
 bool changed=amp[c->id]!=value;amp[c->id]=value;return changed;
}
static int amp_info(struct snd_kcontrol *c,struct snd_ctl_elem_info *v) {
 (void)c;v->type=SNDRV_CTL_ELEM_TYPE_ENUMERATED;v->count=1;v->value.enumerated.items=4;
 snprintf(v->value.enumerated.name,sizeof(v->value.enumerated.name),"%u",v->value.enumerated.item*90);return 0;
}
static struct snd_kcontrol *snd_soc_card_get_kcontrol(struct snd_soc_card *c,const char *name) {
 static const char * const p[]={"TopLeft","TopRight","BottomLeft","BottomRight"};(void)c;
 for(unsigned int i=0;i<4;i++)if(!strncmp(name,p[i],strlen(p[i])))return &controls[i];
 return NULL;
}
static void snd_ctl_notify(void *card,int event,unsigned int *id) { (void)card;(void)id;assert(event==1);notifications++; }
static int snd_soc_add_card_controls(struct snd_soc_card *c,const struct snd_kcontrol_new *n,unsigned int count) {
 (void)c;assert(count==1 && !strcmp(n->name,"Speaker Display Rotation") && n->get && n->put && n->enum_data);registered++;return 0;
}
#include "../src/audio/uke-speaker-quad.h"
static int snd_soc_dai_set_channel_map(struct snd_soc_dai *dai,unsigned int tx,const unsigned int *t,unsigned int rx,const unsigned int *r) {
 assert(dai->id==40 && !tx && !t);int target=uke_quad_turn(r,rx);assert(target>=0);
 unsigned int call=maps++;
 if((int)call==fail_map){if(partial)turn=target;return -EIO;}
 bool changed=turn!=(unsigned int)target;turn=target;return changed;
}
static int snd_soc_dai_get_channel_map(struct snd_soc_dai *dai,unsigned int *tx,unsigned int *t,unsigned int *rx,unsigned int *r) {
 (void)t;assert(dai->id==40);*tx=0;*rx=4;memcpy(r,uke_quad_sources[turn],sizeof(uke_quad_sources[0]));return 0;
}
static void q6apm_fs19xx_fault(void) { faults++; }
#include "../src/audio/uke-speaker-quad-control.h"

static void fresh(unsigned int angle,unsigned int codec) {
 for(unsigned int i=0;i<4;i++)amp[i]=codec;
 turn=angle;reads=sets=maps=faults=notifications=0;
 fail_read=fail_set=fail_map=-1;partial=fail_rollback=false;
}
int main(void) {
 const struct snd_soc_dai_ops ops={true,true};
 const struct snd_soc_dai_driver driver={&ops};
 struct snd_soc_dai dai={40,&driver};struct snd_soc_dai_link link={true};
 struct snd_soc_pcm_runtime rtd={&dai,&link,NULL};
 struct uke_speaker_data data={};struct snd_soc_card card={&data,&rtd,NULL};
 struct snd_kcontrol aggregate={.card=&card};struct snd_ctl_elem_value v={};unsigned int cases=0;
 assert(!pthread_mutex_init(&data.rotation_lock.value,NULL));
 for(unsigned int i=0;i<4;i++)controls[i]=(struct snd_kcontrol){amp_get,amp_put,amp_info,i,&card};
 assert(!uke_speaker_display_init(&card) && registered==1 && data.rotation_dai==&dai);cases++;
 for(unsigned int from=0;from<4;from++)for(unsigned int to=0;to<4;to++) {
  fresh(from,0);v.value.enumerated.item[0]=to;
  assert(uke_display_put(&aggregate,&v)==(from!=to));
  assert(turn==to && !faults && !sets);
  assert(!uke_display_get(&aggregate,&v) && v.value.enumerated.item[0]==to);cases++;
 }
 for(unsigned int codec=1;codec<4;codec++) {
  fresh(2,codec);assert(uke_display_get(&aggregate,&v)==-EUCLEAN);
  v.value.enumerated.item[0]=2;assert(uke_display_put(&aggregate,&v)==1);
  for(unsigned int i=0;i<4;i++)assert(!amp[i]);
  assert(notifications==4 && !faults);cases++;
 }
 for(int fail=0;fail<4;fail++)for(unsigned int mutate=0;mutate<2;mutate++) {
  fresh(0,2);fail_set=fail;partial=mutate;v.value.enumerated.item[0]=3;
  assert(uke_display_put(&aggregate,&v)==-EIO && !turn && !faults);
  for(unsigned int i=0;i<4;i++)assert(amp[i]==2);
  cases++;
  fresh(0,2);fail_set=fail;partial=mutate;fail_rollback=true;v.value.enumerated.item[0]=3;
  assert(uke_display_put(&aggregate,&v)==-EIO && faults==1);cases++;
 }
 for(int fail=0;fail<8;fail++) {
  fresh(0,2);fail_read=fail;v.value.enumerated.item[0]=3;
  assert(uke_display_put(&aggregate,&v)==-ENODEV && !turn && !faults);
  for(unsigned int i=0;i<4;i++)assert(amp[i]==2);
  if(fail<4)assert(!sets && !maps);
  cases++;
 }
 for(unsigned int mutate=0;mutate<2;mutate++) {
  fresh(0,0);fail_map=0;partial=mutate;v.value.enumerated.item[0]=2;
  assert(uke_display_put(&aggregate,&v)==-EIO && !turn && !faults);cases++;
 }
 fresh(0,0);v.value.enumerated.item[0]=4;assert(uke_display_put(&aggregate,&v)==-EINVAL && !maps && !sets);cases++;
 assert(!pthread_mutex_destroy(&data.rotation_lock.value));
 printf("Actual quad machine callbacks: %u discovery/mapping/legacy/readback/rollback cases passed; controlled ALSA only.\n",cases);
 return 0;
}

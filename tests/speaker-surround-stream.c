/* SPDX-License-Identifier: GPL-2.0-only */
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <sound/asound.h>
#define ARRAY_SIZE(a) (sizeof(a)/sizeof((a)[0]))
struct snd_pcm_hw_params {unsigned channels,rate;snd_pcm_format_t format;};
#define params_channels(p) ((p)->channels)
#define params_rate(p) ((p)->rate)
#define params_format(p) ((p)->format)
struct snd_soc_dai {unsigned id;};
struct snd_soc_dai_link {bool no_pcm,dynamic;unsigned num_cpus;};
struct snd_soc_pcm_runtime;
struct snd_soc_dpcm {struct snd_soc_pcm_runtime *fe;struct snd_soc_dpcm *next;};
struct snd_soc_dpcm_runtime {struct snd_pcm_hw_params hw_params;struct snd_soc_dpcm *first;};
struct snd_soc_pcm_runtime {struct snd_soc_dai_link *dai_link;struct snd_soc_dai cpu;struct snd_soc_dpcm_runtime dpcm[2];};
struct snd_pcm_runtime {unsigned unused;};
struct snd_pcm_substream {int stream;struct snd_soc_pcm_runtime *rtd;struct snd_pcm_runtime *runtime;};
struct snd_pcm {struct {struct snd_pcm_substream *substream;} streams[2];};
struct snd_pcm_chmap_elem {unsigned char channels,map[15];};
struct snd_pcm_hw_constraint_list {unsigned count;const unsigned *list;};
#define snd_soc_substream_to_rtd(s) ((s)->rtd)
#define snd_soc_rtd_to_cpu(r,n) ((void)(n),&(r)->cpu)
#define for_each_dpcm_fe(be,stream,p) for((p)=(be)->dpcm[stream].first;(p);(p)=(p)->next)
static bool board=true;
static unsigned constraint_calls,chmap_calls;
static int constraint_error,chmap_error;
static bool of_machine_is_compatible(const char *s) {(void)s;return board;}
static int snd_pcm_hw_constraint_list(struct snd_pcm_runtime *r,int cond,int param,const struct snd_pcm_hw_constraint_list *list) {
 assert(r&&!cond&&param==SNDRV_PCM_HW_PARAM_CHANNELS&&list->count==3);
 assert(list->list[0]==4&&list->list[1]==6&&list->list[2]==8);
 constraint_calls++;return constraint_error;
}
static int snd_pcm_add_chmap_ctls(struct snd_pcm *p,int stream,const struct snd_pcm_chmap_elem *maps,int max,unsigned long v,void *out) {
 assert(p&&stream==SNDRV_PCM_STREAM_PLAYBACK&&max==8&&!v&&!out);
 assert(maps[0].channels==4&&maps[1].channels==6&&maps[2].channels==8&&!maps[3].channels);
 chmap_calls++;return chmap_error;
}
#include "../src/audio/uke-speaker-surround-stream.h"
#include "../src/audio/uke-speaker-surround-fe.h"
#include "actual-alsa-standard-chmaps.inc"
int main(void) {
 struct snd_soc_dai_link belink={.no_pcm=true},felink={.dynamic=true,.num_cpus=1};
 struct snd_soc_pcm_runtime be={.dai_link=&belink},fe={.dai_link=&felink,.cpu={1}};
 struct snd_soc_pcm_runtime fe2=fe;
 struct snd_soc_dpcm link={.fe=&fe},link2={.fe=&fe2};be.dpcm[0].first=&link;
 struct snd_pcm_runtime runtime={};struct snd_pcm_substream sub={.rtd=&be,.runtime=&runtime};
 struct snd_pcm pcm={.streams={{&sub}}};unsigned cases=0;
 for(unsigned n=0;n<=10;n++) {
  fe.dpcm[0].hw_params=(struct snd_pcm_hw_params){n,48000,SNDRV_PCM_FORMAT_S16_LE};
  assert(uke_surround_stream_channels(&sub)==(uke_surround_channels_valid(n)?(int)n:-EINVAL));cases++;
 }
 fe.dpcm[0].hw_params=(struct snd_pcm_hw_params){6,48000,SNDRV_PCM_FORMAT_S16_LE};
 fe2.dpcm[0].hw_params=fe.dpcm[0].hw_params;link.next=&link2;
 assert(uke_surround_stream_channels(&sub)==6);cases++;
 fe2.dpcm[0].hw_params.channels=8;assert(uke_surround_stream_channels(&sub)==-EBUSY);cases++;
 link.next=NULL;
 fe.dpcm[0].hw_params.rate=44100;assert(uke_surround_stream_channels(&sub)==-EINVAL);cases++;
 fe.dpcm[0].hw_params.rate=48000;fe.dpcm[0].hw_params.format=SNDRV_PCM_FORMAT_FLOAT_LE;
 assert(uke_surround_stream_channels(&sub)==-EINVAL);cases++;
 const snd_pcm_format_t formats[]={SNDRV_PCM_FORMAT_S16_LE,SNDRV_PCM_FORMAT_S24_LE,SNDRV_PCM_FORMAT_S32_LE};
 for(unsigned i=0;i<ARRAY_SIZE(formats);i++)for(unsigned n=4;n<=8;n+=2) {
  fe.dpcm[0].hw_params.channels=n;fe.dpcm[0].hw_params.format=formats[i];
  assert(uke_surround_stream_channels(&sub)==(int)n);cases++;
 }
 fe.dpcm[0].hw_params.format=SNDRV_PCM_FORMAT_S16_LE;
 fe.cpu.id=0;assert(uke_surround_stream_channels(&sub)==-EINVAL);cases++;
 fe.cpu.id=1;felink.num_cpus=2;assert(uke_surround_stream_channels(&sub)==-EINVAL);cases++;
 felink.num_cpus=1;felink.dynamic=false;assert(uke_surround_stream_channels(&sub)==-EINVAL);cases++;
 felink.dynamic=true;link.fe=NULL;assert(uke_surround_stream_channels(&sub)==-EINVAL);cases++;
 link.fe=&fe;be.dpcm[0].first=NULL;assert(uke_surround_stream_channels(&sub)==-ENOLINK);cases++;
 be.dpcm[0].first=&link;belink.no_pcm=false;assert(uke_surround_stream_channels(&sub)==-EINVAL);cases++;
 belink.no_pcm=true;sub.stream=SNDRV_PCM_STREAM_CAPTURE;assert(uke_surround_stream_channels(&sub)==-EINVAL);cases++;
 sub.stream=0;assert(uke_surround_stream_channels(NULL)==-EINVAL);cases++;
 for(unsigned i=0;i<3;i++) {
  const struct snd_pcm_chmap_elem *map=snd_pcm_std_chmaps;
  while(map->channels&&map->channels!=uke_surround_fe_maps[i].channels)map++;
  assert(map->channels&&!memcmp(map->map,uke_surround_fe_maps[i].map,sizeof(map->map)));cases++;
 }
 assert(!uke_surround_fe_open(&sub,1)&&constraint_calls==1);cases++;
 constraint_error=-ENOMEM;assert(uke_surround_fe_open(&sub,1)==-ENOMEM);constraint_error=0;cases++;
 assert(!uke_surround_fe_chmap(&pcm,1)&&chmap_calls==1);cases++;
 chmap_error=-EIO;assert(uke_surround_fe_chmap(&pcm,1)==-EIO);chmap_error=0;cases++;
 unsigned old=constraint_calls,prior=chmap_calls;board=false;
 assert(!uke_surround_fe_open(&sub,1)&&!uke_surround_fe_chmap(&pcm,1));board=true;cases++;
 assert(!uke_surround_fe_open(&sub,0)&&!uke_surround_fe_chmap(&pcm,0));cases++;
 sub.stream=SNDRV_PCM_STREAM_CAPTURE;assert(!uke_surround_fe_open(&sub,1));sub.stream=0;cases++;
 pcm.streams[0].substream=NULL;assert(!uke_surround_fe_chmap(&pcm,1));cases++;
 assert(constraint_calls==old&&chmap_calls==prior);
 printf("Actual surround FE/stream callbacks: %u constraint/map/ownership/format/error cases passed; controlled ASoC only.\n",cases);
}

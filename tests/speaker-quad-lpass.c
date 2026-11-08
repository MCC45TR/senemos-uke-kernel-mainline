/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual LPASS adapter with controlled graph, ALSA and DSP providers. */
#include <assert.h>
#include <errno.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
typedef uint8_t u8;
#define SECONDARY_TDM_RX_0 40
#define SNDRV_PCM_STREAM_PLAYBACK 0
#define MODULE_ID_MFC 0x07001015
#define PCM_CHANNEL_FL 1
#define PCM_CHANNEL_FR 2
#define PCM_CHANNEL_LS 5
#define PCM_CHANNEL_RS 6
struct mutex { pthread_mutex_t value; };
static struct mutex *lock_mutex(struct mutex *m) { assert(!pthread_mutex_lock(&m->value));return m; }
static void unlock_mutex(struct mutex **m) { assert(!pthread_mutex_unlock(&(*m)->value)); }
#define guard(type) struct mutex *held __attribute__((cleanup(unlock_mutex))) = lock_mutex
struct chain { void *first; };
#define list_for_each_entry(pos, head, member) for((pos)=(head)->first;(pos);(pos)=(pos)->next)
struct audioreach_module { unsigned int module_id,instance_id;struct audioreach_module *next; };
struct audioreach_container { struct chain modules_list;struct audioreach_container *next; };
struct audioreach_sub_graph { struct chain container_list;struct audioreach_sub_graph *next; };
struct audioreach_graph_info { struct chain sg_list; };
struct q6apm_graph { unsigned int id;bool admitted;struct audioreach_graph_info *info; };
struct audioreach_module_config { unsigned int num_channels,sample_rate,bit_width;int direction;u8 channel_map[32]; };
struct q6apm_lpass_dai_data {
	struct mutex uke_quad_lock;
	unsigned int uke_quad_turn;
	struct q6apm_graph *graph[128];
	struct audioreach_module_config module_config[128];
};
struct snd_soc_dai { int id;void *dev; };
struct snd_pcm_substream { int unused; };
struct snd_pcm_hw_params { int unused; };
static bool board=true;
static unsigned int sends,faults,fail_send,fail_restore,prepares,starts,closes,triggers,hw_params;
static u8 last_map[32];
static struct q6apm_graph *available_graph;
static pthread_mutex_t rendezvous=PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t progress=PTHREAD_COND_INITIALIZER;
static bool block_send,send_entered,close_requested,release_send;
static void *dev_get_drvdata(void *dev) { return dev; }
static bool of_machine_is_compatible(const char *id) { (void)id;return board; }
static bool q6apm_fs19xx_graph(struct q6apm_graph *g) { return g->admitted && g->id==40; }
static void q6apm_fs19xx_fault(void) { faults++; }
static void require_locked(struct snd_soc_dai *dai) {
	if(board && dai->id==40) {
		struct q6apm_lpass_dai_data *d=dev_get_drvdata(dai->dev);
		assert(pthread_mutex_trylock(&d->uke_quad_lock.value)==EBUSY);
	}
}
#define UKE_SPEAKER_QUAD_TRANSPORT_H
static int audioreach_uke_quad_matrix(struct q6apm_graph *graph,
		const struct audioreach_module *module,const unsigned int *map) {
	const u8 ids[]={1,2,5,6};
	assert(graph==available_graph && module->module_id==MODULE_ID_MFC && module->instance_id==0x442e);
	assert(!pthread_mutex_lock(&rendezvous));
	if(block_send) {
		send_entered=true;assert(!pthread_cond_broadcast(&progress));
		while(!release_send)assert(!pthread_cond_wait(&progress,&rendezvous));
	}
	assert(!pthread_mutex_unlock(&rendezvous));
	for(unsigned int i=0;i<4;i++)last_map[i]=ids[map[i]];
	sends++;
	return sends==fail_send || sends==fail_restore ? -EIO:0;
}
static int q6apm_lpass_dai_prepare(struct snd_pcm_substream *s,struct snd_soc_dai *dai) {
	(void)s;require_locked(dai);prepares++;return 0;
}
static int q6apm_lpass_dai_startup(struct snd_pcm_substream *s,struct snd_soc_dai *dai) {
	(void)s;require_locked(dai);starts++;
	((struct q6apm_lpass_dai_data *)dai->dev)->graph[dai->id]=available_graph;return 0;
}
static void q6i2s_lpass_dai_shutdown(struct snd_pcm_substream *s,struct snd_soc_dai *dai) {
	(void)s;require_locked(dai);closes++;
	((struct q6apm_lpass_dai_data *)dai->dev)->graph[dai->id]=NULL;
}
static int q6dma_hw_params(struct snd_pcm_substream *s,struct snd_pcm_hw_params *p,struct snd_soc_dai *dai) {
	(void)s;(void)p;require_locked(dai);hw_params++;return 0;
}
static int q6apm_lpass_dai_trigger(struct snd_pcm_substream *s,int cmd,struct snd_soc_dai *dai) {
	(void)s;(void)cmd;require_locked(dai);triggers++;return 0;
}
#include "../src/audio/uke-speaker-quad-lpass.h"

static void *live_route(void *p) {
	struct snd_soc_dai *dai=p;
	assert(uke_quad_set_map(dai,0,NULL,4,uke_quad_sources[1])==1);
	return NULL;
}
static void *parallel_close(void *p) {
	assert(!pthread_mutex_lock(&rendezvous));close_requested=true;
	assert(!pthread_cond_broadcast(&progress));assert(!pthread_mutex_unlock(&rendezvous));
	uke_quad_shutdown(NULL,p);return NULL;
}

int main(void) {
	struct audioreach_module module={.module_id=MODULE_ID_MFC,.instance_id=0x442e};
	struct audioreach_container container={.modules_list={&module}};
	struct audioreach_sub_graph sg={.container_list={&container}};
	struct audioreach_graph_info info={.sg_list={&sg}};
	struct q6apm_graph graph={.id=40,.admitted=true,.info=&info};
	struct q6apm_lpass_dai_data data={};
	struct snd_soc_dai dai={.id=40,.dev=&data};
	const u8 ids[4]={1,2,5,6};
	unsigned int tx=9,rx=0,map[4],cases=0;
	assert(!pthread_mutex_init(&data.uke_quad_lock.value,NULL));
	data.module_config[40]=(struct audioreach_module_config){4,48000,16,0,{1,2,5,6}};
	const struct audioreach_module_config canonical=data.module_config[40];
	available_graph=&graph;
	for(unsigned int turn=0;turn<4;turn++) {
		unsigned int before=sends;
		assert(uke_quad_set_map(&dai,0,NULL,4,uke_quad_sources[turn])>=0 && sends==before);
		assert(!uke_quad_startup(NULL,&dai) && !uke_quad_hw_params(NULL,NULL,&dai));
		assert(!uke_quad_prepare(NULL,&dai) && !uke_quad_trigger(NULL,1,&dai));
		assert(!uke_quad_get_map(&dai,&tx,NULL,&rx,map) && tx==0 && rx==4);
		assert(uke_quad_turn(map,rx)==(int)turn);
		if(turn)for(unsigned int i=0;i<4;i++)assert(last_map[i]==ids[uke_quad_sources[turn][i]]);
		else assert(sends==before); /* Exact original prepare: no extra DSP command. */
		assert(!memcmp(&canonical,&data.module_config[40],sizeof(canonical)));
		uke_quad_shutdown(NULL,&dai);assert(!data.graph[40]);cases++;
	}
	assert(prepares==4 && starts==4 && hw_params==4 && triggers==4 && closes==4);
	assert(!uke_quad_startup(NULL,&dai));
	for(unsigned int from=0;from<4;from++)for(unsigned int to=0;to<4;to++) {
		assert(uke_quad_set_map(&dai,0,NULL,4,uke_quad_sources[from])>=0);
		assert(uke_quad_set_map(&dai,0,NULL,4,uke_quad_sources[to])>=0);
		assert(data.uke_quad_turn==to);
		for(unsigned int i=0;i<4;i++)assert(last_map[i]==ids[uke_quad_sources[to][i]]);
		cases++;
	}
	assert(uke_quad_set_map(&dai,0,NULL,4,uke_quad_sources[0])>=0);
	fail_send=sends+1;assert(uke_quad_set_map(&dai,0,NULL,4,uke_quad_sources[1])==-EIO);
	assert(!data.uke_quad_turn && !faults && !memcmp(last_map,ids,4));cases++;
	fail_send=sends+1;fail_restore=sends+2;
	assert(uke_quad_set_map(&dai,0,NULL,4,uke_quad_sources[2])==-EIO && faults==1);cases++;
	fail_send=fail_restore=0;
	module.instance_id=0x4040;
	assert(uke_quad_set_map(&dai,0,NULL,4,uke_quad_sources[1])==-EINVAL);cases++;
	module.instance_id=0x442e;
	const unsigned int invalid[4]={0,0,2,3};
	assert(uke_quad_set_map(&dai,0,NULL,4,invalid)==-EINVAL);
	assert(uke_quad_set_map(&dai,1,invalid,4,uke_quad_sources[0])==-EINVAL);
	board=false;assert(uke_quad_set_map(&dai,0,NULL,4,uke_quad_sources[0])==-EINVAL);board=true;cases++;
	uke_quad_shutdown(NULL,&dai);
	/* Stop is requested while the actual live callback is inside a DSP send.
	 * Its graph remains owned until that command finishes; no timer/poll loop. */
	assert(!uke_quad_startup(NULL,&dai));
	assert(uke_quad_set_map(&dai,0,NULL,4,uke_quad_sources[0])>=0);
	unsigned int before_close=closes,before_send=sends;
	pthread_t router,closer;block_send=true;
	assert(!pthread_create(&router,NULL,live_route,&dai));
	assert(!pthread_mutex_lock(&rendezvous));
	while(!send_entered)assert(!pthread_cond_wait(&progress,&rendezvous));
	assert(!pthread_create(&closer,NULL,parallel_close,&dai));
	while(!close_requested)assert(!pthread_cond_wait(&progress,&rendezvous));
	assert(pthread_mutex_trylock(&data.uke_quad_lock.value)==EBUSY);
	assert(closes==before_close && data.graph[40]==available_graph);
	release_send=true;assert(!pthread_cond_broadcast(&progress));
	assert(!pthread_mutex_unlock(&rendezvous));
	assert(!pthread_join(router,NULL) && !pthread_join(closer,NULL));
	assert(closes==before_close+1 && !data.graph[40] && sends==before_send+1);
	assert(uke_quad_set_map(&dai,0,NULL,4,uke_quad_sources[2])==1 && sends==before_send+1);
	block_send=false;assert(!uke_quad_startup(NULL,&dai));
	assert(!uke_quad_prepare(NULL,&dai));
	for(unsigned int i=0;i<4;i++)assert(last_map[i]==ids[uke_quad_sources[2][i]]);
	uke_quad_shutdown(NULL,&dai);cases++;
	assert(!pthread_mutex_destroy(&data.uke_quad_lock.value));
	printf("Actual quad LPASS adapter: %u lifecycle/mapping/rollback/provider scenarios passed; controlled firmware only.\n",cases);
	return 0;
}

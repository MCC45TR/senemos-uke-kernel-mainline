// SPDX-License-Identifier: GPL-2.0-only
// Actual extracted encoders; independent AudioReach field/length expectations.
#include <assert.h>
#include <stdbool.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
typedef uint8_t u8; typedef uint16_t u16; typedef uint32_t u32;
#define __packed __attribute__((packed))
#define ALIGN(x,a) (((x)+(a)-1)&~((a)-1))
#define struct_size(p,m,n) (sizeof(*(p))+sizeof((p)->m[0])*(n))
#define __free(f) __attribute__((cleanup(f##_cleanup)))
#define IS_ERR(p) ((uintptr_t)(p)>=(uintptr_t)-4095)
#define PTR_ERR(p) ((long)(p))
#define dev_err(...) ((void)0)
#define SND_AUDIOCODEC_PCM 1
#define APM_CMD_SET_CFG 0x01001006
#define GPR_HDR_SIZE 24
#define APM_CMD_HDR_SIZE 16
#define APM_MODULE_PARAM_DATA_SIZE 16
struct gpr_pkt { unsigned char header[40]; };
struct apm_module_param_data { uint32_t module_instance_id,param_id,param_size,error_code; } __packed;
struct q6apm; struct port { int id; };
struct q6apm_graph { struct q6apm *apm; struct port *port; void *dev; };
struct audioreach_module { uint32_t instance_id,interleave_type; };
#include "pcm-types.inc"
struct audioreach_module_config { uint32_t sample_rate,fmt; uint16_t bit_width,bits_per_sample,num_channels; uint8_t channel_map[AR_PCM_MAX_NUM_CHANNEL]; };
static unsigned char sent[512]; static size_t sent_size;
static unsigned sends,allocations,frees; static int status,fail_alloc;
static void kfree_cleanup(void *p) { void *v=*(void **)p; if (!IS_ERR(v)&&v) {frees++;free(v);} }
static void *audioreach_alloc_cmd_pkt(int size,uint32_t op,uint32_t token,int port,int iid) {
 (void)op;(void)token;(void)port;(void)iid;
 if(fail_alloc)return (void *)(uintptr_t)-ENOMEM;
 sent_size=40+size;allocations++;return calloc(1,sent_size);
}
static void *audioreach_alloc_apm_cmd_pkt(int size,uint32_t op,uint32_t token) {return audioreach_alloc_cmd_pkt(size,op,token,0,0);}
static int q6apm_send_cmd_sync(struct q6apm *a,struct gpr_pkt *p,uint32_t r) {
 (void)a;(void)r;assert(sent_size<=sizeof sent);memcpy(sent,p,sent_size);sends++;return status;
}
static int audioreach_graph_send_cmd_sync(struct q6apm_graph *g,struct gpr_pkt *p,uint32_t r) {return q6apm_send_cmd_sync(g->apm,p,r);}
static int audioreach_set_compr_media_format(struct media_format *h,void *p,const struct audioreach_module_config *c) {(void)h;(void)p;(void)c;return -EOPNOTSUPP;}
#include "pcm-encoders.inc"
static uint16_t half(size_t n) {uint16_t v;memcpy(&v,sent+n,2);return v;}
static uint32_t word(size_t n) {uint32_t v;memcpy(&v,sent+n,4);return v;}
static void check_packet(unsigned ch,unsigned depth,unsigned storage,const unsigned char *map,bool shmem) {
 const size_t total=40+16+ALIGN(12+16+ch,8);
 assert(sent_size==total && allocations==frees);
 assert(word(40)==0x6100 && word(44)==(shmem?0x0800100c:0x08001008));
 assert(word(48)==total-40-16 && word(52)==0);
 assert(word(56)==1 && word(60)==0x09001000);
 // The logical media length excludes TLV and all alignment bytes.
 assert(word(64)==16+ch && 68+word(64)<=sent_size);
 if(shmem) {
  assert(word(68)==48000 && half(72)==depth && half(74)==1 && half(76)==storage);
  assert(half(78)==depth-1 && half(80)==1 && half(82)==ch);
 } else {
  assert(half(68)==depth && half(70)==1 && half(72)==storage);
  assert(half(74)==depth-1 && half(76)==1 && half(78)==1 && half(80)==0 && half(82)==ch);
 }
 assert(memcmp(sent+84,map,ch)==0);
 for(size_t n=84+ch;n<sent_size;n++)assert(sent[n]==0);
}
static void refused(struct q6apm_graph *g,struct audioreach_module *m,struct audioreach_module_config *c,int error,bool before_alloc) {
 unsigned a=allocations,s=sends;
 assert(audioreach_pcm_set_media_format(g,m,c)==error);
 assert(audioreach_shmem_set_media_format(g,m,c)==error);
 assert(sends==s && allocations==frees);
 if(before_alloc)assert(allocations==a);
}
int main(void) {
 struct port port={1};struct q6apm_graph graph={.port=&port};
 struct audioreach_module module={.instance_id=0x6100,.interleave_type=1};
 struct audioreach_module_config cfg={.sample_rate=48000,.fmt=1};
 const unsigned depths[]={16,24,24,32}, storage[]={16,24,32,32};
 const unsigned char ordered[]={1,2,8,9,3,6,4,5};
 unsigned cases=0;
 for(unsigned ch=1;ch<=8;ch++) {
  cfg.num_channels=ch;memset(cfg.channel_map,0,sizeof cfg.channel_map);memcpy(cfg.channel_map,ordered,ch);
  for(unsigned f=0;f<4;f++) {
   cfg.bit_width=depths[f];cfg.bits_per_sample=storage[f];
   assert(audioreach_pcm_set_media_format(&graph,&module,&cfg)==0);
   check_packet(ch,depths[f],storage[f],ordered,false);
   assert(audioreach_shmem_set_media_format(&graph,&module,&cfg)==0);
   check_packet(ch,depths[f],storage[f],ordered,true);cases++;
  }
  // Every advertised channel must have a nonzero map entry.
  cfg.channel_map[ch-1]=0;refused(&graph,&module,&cfg,-EINVAL,true);cases++;
 }
 const unsigned layouts[]={1,2,4,6,8};
 const unsigned char maps[5][8]={{3},{1,2},{1,2,4,5},{1,2,4,5,3,6},{1,2,8,9,3,6,4,5}};
 for(unsigned n=0;n<5;n++) {
  cfg.num_channels=layouts[n];memset(cfg.channel_map,0,sizeof cfg.channel_map);
  audioreach_set_default_channel_mapping(cfg.channel_map,cfg.num_channels);
  assert(memcmp(cfg.channel_map,maps[n],8)==0);
  assert(audioreach_pcm_set_media_format(&graph,&module,&cfg)==0);
  check_packet(layouts[n],32,32,maps[n],false);
  assert(audioreach_shmem_set_media_format(&graph,&module,&cfg)==0);
  check_packet(layouts[n],32,32,maps[n],true);cases++;
 }
 // Preserve sparse physical-to-logical mapping, including the last input slot.
 cfg.num_channels=2;memset(cfg.channel_map,0,sizeof cfg.channel_map);cfg.channel_map[0]=1;cfg.channel_map[7]=2;
 assert(audioreach_pcm_set_media_format(&graph,&module,&cfg)==0);check_packet(2,32,32,maps[1],false);
 assert(audioreach_shmem_set_media_format(&graph,&module,&cfg)==0);check_packet(2,32,32,maps[1],true);cases++;
 const unsigned counts[]={0,9,65535};
 for(unsigned n=0;n<3;n++){cfg.num_channels=counts[n];refused(&graph,&module,&cfg,-EINVAL,true);cases++;}
 cfg.num_channels=4;memcpy(cfg.channel_map,ordered,8);
 const unsigned invalid[][2]={{16,32},{24,16},{32,24},{8,8},{0,0},{24,64}};
 for(unsigned n=0;n<6;n++){cfg.bit_width=invalid[n][0];cfg.bits_per_sample=invalid[n][1];refused(&graph,&module,&cfg,-EINVAL,true);cases++;}
 cfg.bit_width=24;cfg.bits_per_sample=0;assert(audioreach_pcm_word_size(&cfg)==24);cases++;
 cfg.bits_per_sample=32;fail_alloc=1;refused(&graph,&module,&cfg,-ENOMEM,true);fail_alloc=0;cases++;
 status=-EIO;unsigned s=sends;
 assert(audioreach_pcm_set_media_format(&graph,&module,&cfg)==-EIO);
 assert(audioreach_shmem_set_media_format(&graph,&module,&cfg)==-EIO && sends==s+2 && allocations==frees);status=0;cases++;
 // Compressed validation/dispatch is unchanged, including unknown channel count.
 cfg.fmt=99;cfg.num_channels=0;s=sends;
 assert(audioreach_shmem_set_media_format(&graph,&module,&cfg)==-EOPNOTSUPP && sends==s && allocations==frees);
 cfg.num_channels=5;assert(audioreach_shmem_set_media_format(&graph,&module,&cfg)==-EINVAL && sends==s && allocations==frees);cases++;
 printf("Actual PCM encoder wire cases:%u;1..8/sparse/default maps/S16-S24-S32/bounds/length/padding/errors/compressed preserved.\n",cases);
}

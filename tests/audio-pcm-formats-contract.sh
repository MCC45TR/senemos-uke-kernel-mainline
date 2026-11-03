#!/usr/bin/env bash
# COPR only: exercise actual PCM encoders against independent wire expectations.
set -Eeuo pipefail
q6=${1:?Prepared source}/sound/soc/qcom/qdsp6
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
extract() { awk -v start="$2" '$0 ~ start {emit=1} emit {print} emit && /^}/ {exit}' "$1"; }
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
typedef uint16_t u16; typedef uint32_t u32;
#define __packed __attribute__((packed))
#define ALIGN(x,a) (((x)+(a)-1)&~((a)-1))
#define struct_size(p,m,n) (sizeof(*(p))+sizeof((p)->m[0])*(n))
#define __free(f) __attribute__((cleanup(f##_cleanup)))
#define IS_ERR(p) ((uintptr_t)(p)>=(uintptr_t)-4095)
#define PTR_ERR(p) ((long)(p))
static void kfree_cleanup(void *p) { void *v=*(void **)p; if (!IS_ERR(v)) free(v); }
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
struct audioreach_module_config { uint32_t sample_rate,fmt; uint16_t bit_width,bits_per_sample,num_channels; uint8_t channel_map[8]; };
static unsigned char sent[512]; static size_t sent_size; static unsigned sends; static int status,fail_alloc;
static void *audioreach_alloc_cmd_pkt(int size,uint32_t op,uint32_t token,int port,int iid) {
 (void)op;(void)token;(void)port;(void)iid; sent_size=40+size;
 return fail_alloc ? (void *)(uintptr_t)-ENOMEM : calloc(1,sent_size);
}
static void *audioreach_alloc_apm_cmd_pkt(int size,uint32_t op,uint32_t token) { return audioreach_alloc_cmd_pkt(size,op,token,0,0); }
static int q6apm_send_cmd_sync(struct q6apm *a,struct gpr_pkt *p,uint32_t r) { (void)a;(void)r; assert(sent_size<=sizeof sent);memcpy(sent,p,sent_size);sends++;return status; }
static int audioreach_graph_send_cmd_sync(struct q6apm_graph *g,struct gpr_pkt *p,uint32_t r) {return q6apm_send_cmd_sync(g->apm,p,r);}
C
for name in param_id_pcm_output_format_cfg payload_pcm_output_format_cfg media_format payload_media_fmt_pcm; do
 extract "$q6/audioreach.h" "^struct $name [{]" >> "$work/check.c"
done
rg '^#define (DATA_FORMAT_FIXED_POINT|PCM_LSB_ALIGNED|PCM_LITTLE_ENDIAN|MEDIA_FMT_ID_PCM|PARAM_ID_PCM_OUTPUT_FORMAT_CFG|PARAM_ID_MEDIA_FORMAT|AR_PCM_MAX_NUM_CHANNEL)\b' "$q6/audioreach.h" >> "$work/check.c"
for name in apm_pcm_module_media_fmt_cmd apm_sh_module_media_fmt_cmd; do
 extract "$q6/audioreach.c" "^struct $name [{]" >> "$work/check.c"
done
sed -n '/^#define APM_SHMEM_FMT_CFG_PSIZE/,/^struct apm_i2s_module_intf_cfg/p' "$q6/audioreach.c" | sed '$d' >> "$work/check.c"
cat >> "$work/check.c" <<'C'
static int audioreach_set_compr_media_format(struct media_format *h,void *p,const struct audioreach_module_config *c) {(void)h;(void)p;(void)c;return -EINVAL;}
C
for name in audioreach_pcm_word_size audioreach_pcm_set_media_format audioreach_shmem_set_media_format; do
 extract "$q6/audioreach.c" "^static int $name\\(" >> "$work/check.c"
done
cat >> "$work/check.c" <<'C'
static uint16_t half(size_t n) { uint16_t v;memcpy(&v,sent+n,2);return v; }
static uint32_t word(size_t n) { uint32_t v;memcpy(&v,sent+n,4);return v; }
int main(void) {
 struct port port={1};struct q6apm_graph graph={.port=&port};
 struct audioreach_module module={.instance_id=0x6100,.interleave_type=1};
 struct audioreach_module_config cfg={.sample_rate=48000,.fmt=1,.num_channels=4,.channel_map={1,2,3,4}};
 const unsigned depths[]={16,24,32}, storage[]={16,32,32};
 for(unsigned f=0;f<3;f++) {
  cfg.bit_width=depths[f];cfg.bits_per_sample=storage[f];
  assert(audioreach_pcm_set_media_format(&graph,&module,&cfg)==0);
  assert(word(40)==0x6100 && word(44)==0x08001008);
  assert(word(56)==1 && word(60)==0x09001000 && word(64)==20);
  assert(half(68)==depths[f] && half(70)==1 && half(72)==storage[f]);
  assert(half(74)==depths[f]-1 && half(76)==1 && half(78)==1 && half(80)==0 && half(82)==4);
  assert(memcmp(sent+84,"\1\2\3\4",4)==0);
  assert(audioreach_shmem_set_media_format(&graph,&module,&cfg)==0);
  assert(word(44)==0x0800100c && word(56)==1 && word(60)==0x09001000);
  assert(word(68)==48000 && half(72)==depths[f] && half(74)==1 && half(76)==storage[f]);
  assert(half(78)==depths[f]-1 && half(80)==1 && half(82)==4 && memcmp(sent+84,"\1\2\3\4",4)==0);
 }
 cfg.bit_width=24;cfg.bits_per_sample=0;assert(audioreach_pcm_word_size(&cfg)==24); // existing packed callers
 const unsigned invalid[][2]={{16,32},{24,16},{32,24},{8,8},{0,0},{24,64}};
 for(unsigned f=0;f<sizeof invalid/sizeof *invalid;f++) {
  cfg.bit_width=invalid[f][0];cfg.bits_per_sample=invalid[f][1];sends=0;
  assert(audioreach_pcm_set_media_format(&graph,&module,&cfg)==-EINVAL);
  assert(audioreach_shmem_set_media_format(&graph,&module,&cfg)==-EINVAL && sends==0);
 }
 cfg.bit_width=24;cfg.bits_per_sample=32;fail_alloc=1;sends=0;
 assert(audioreach_pcm_set_media_format(&graph,&module,&cfg)==-ENOMEM);
 assert(audioreach_shmem_set_media_format(&graph,&module,&cfg)==-ENOMEM && sends==0);
 fail_alloc=0;status=-EIO;
 assert(audioreach_pcm_set_media_format(&graph,&module,&cfg)==-EIO);
 assert(audioreach_shmem_set_media_format(&graph,&module,&cfg)==-EIO);
 puts("Actual PCM media encoders: S16/Q15, unpacked S24/Q23, S32/Q31 and rejection fixtures passed");
}
C
${CC:-clang} -O1 -g -Wall -Wextra -Werror -fsanitize=undefined -fno-sanitize-recover=all "$work/check.c" -o "$work/check"
"$work/check"

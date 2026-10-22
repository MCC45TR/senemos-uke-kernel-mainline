#!/usr/bin/env bash
# Exercise actual physical-mask, packed-map and reconfiguration code; no DSP access.
set -euo pipefail
kernel=${1:?Pass prepared kernel tree}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
audio=$kernel/sound/soc/qcom/qdsp6/audioreach.c
part() {
    awk -v name="$1" -v first="$2" -v last="$3" '
      $0 ~ "^static int " name "\\(" {in_fn=1}
      in_fn && $0 ~ first {emit=1; next}
      emit && $0 ~ last {done=1; exit}
      emit {print}
      END {if (!done) exit 1}
    ' "$audio" >> "$work/check.c"
}
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <limits.h>
typedef uint8_t u8;
#define U8_MAX UINT8_MAX
#define AR_PCM_MAX_NUM_CHANNEL 8
#define BIT(n) (1u << (n))
#define EXPORT_SYMBOL_GPL(x)
#define dev_err(...) ((void)0)
struct audioreach_module_config { unsigned num_channels; u8 channel_map[8]; };
static unsigned actual_mask(const struct audioreach_module_config *cfg) {
 struct { struct {unsigned active_channels_mask;} cfg; } v={0}, *intf_cfg=&v;
 int i __attribute__((unused));
C
part audioreach_codec_dma_set_media_format 'intf_cfg->cfg.intf_index =' 'p [+]= ic_sz'
cat >> "$work/check.c" <<'C'
 return v.cfg.active_channels_mask;
}
static void actual_mfc(const struct audioreach_module_config *cfg, u8 *out) {
 struct {u8 *channel_mapping;} v={out}, *media_format=&v;
 unsigned num_channels __attribute__((unused))=cfg->num_channels;
 int i, j __attribute__((unused));
C
part audioreach_mfc_set_media_format 'media_format->num_channels =' 'return q6apm_send_cmd_sync'
cat >> "$work/check.c" <<'C'
}
static void actual_pcm(const struct audioreach_module_config *mcfg, u8 *out) {
 struct {u8 *channel_mapping;} v={out}, *media_cfg=&v;
 int i __attribute__((unused)), j __attribute__((unused));
C
part audioreach_pcm_set_media_format 'media_cfg->bits_per_sample =' 'return q6apm_send_cmd_sync'
cat >> "$work/check.c" <<'C'
}
static void actual_shmem(const struct audioreach_module_config *mcfg, u8 *out) {
 struct {unsigned num_channels; u8 *channel_mapping;} v={mcfg->num_channels,out}, *cfg=&v;
 int i __attribute__((unused)), j __attribute__((unused));
C
part audioreach_shmem_set_media_format 'cfg->num_channels = mcfg->num_channels' '} else [{]'
cat >> "$work/check.c" <<'C'
}
static void actual_vi(const struct audioreach_module_config *mcfg, u8 *out) {
 struct {struct {u8 *channel_mapping;} cfg;} v={{out}}, *cm_cfg=&v;
 unsigned num_channels=mcfg->num_channels;
 int i, j __attribute__((unused));
C
part audioreach_speaker_protection_vi 'cm_cfg->cfg.num_channels =' 'p [+]= cm_sz'
{
cat <<'C'
}
C
awk '/^#define PCM_CHANNEL_(FL|FR|LS|RS)[[:space:]]/ {print}' \
    "$kernel/sound/soc/qcom/qdsp6/q6dsp-common.h"
awk '/^void audioreach_set_default_channel_mapping\(/ {emit=1} emit {print}
    emit && /^}/ {emit=0}' "$audio"
cat <<'C'
#include <dt-bindings/sound/qcom,q6dsp-lpass-ports.h>
struct q6apm_lpass_dai_data {struct audioreach_module_config module_config[512];};
struct snd_soc_dai {void *dev; unsigned id;};
static void *dev_get_drvdata(void *dev) {return dev;}
C
awk '/^#define APM_PORT_MAX_AUDIO_CHAN_CNT[[:space:]]/ {print}' \
    "$kernel/sound/soc/qcom/qdsp6/q6apm.h"
awk '/^static int q6dma_set_channel_map\(/ {emit=1} emit {print}
    emit && /^}/ {emit=0}' "$kernel/sound/soc/qcom/qdsp6/q6apm-lpass-dais.c"
cat <<'C'
int main(void) {
 unsigned cases=0;
 for (unsigned mask=1;mask<256;mask++) {
  struct audioreach_module_config cfg={0};
  for(unsigned i=0;i<8;i++) if(mask&BIT(i)) cfg.channel_map[i]=++cfg.num_channels;
  if(cfg.num_channels>4)continue;
  assert(actual_mask(&cfg)==mask);
  void (*pack[])(const struct audioreach_module_config *,u8 *)={actual_mfc,actual_pcm,actual_shmem};
  for(unsigned f=0;f<3;f++) {
   u8 out[8];memset(out,0xa5,sizeof(out));pack[f](&cfg,out);
   for(unsigned i=0;i<cfg.num_channels;i++)assert(out[i]==i+1);
   assert(out[cfg.num_channels]==0xa5);
  }
  u8 vi[16];memset(vi,0xa5,sizeof(vi));actual_vi(&cfg,vi);
  for(unsigned i=0;i<2*cfg.num_channels;i++)assert(vi[i]==i+1);
  assert(vi[2*cfg.num_channels]==0xa5);cases++;
 }
 struct q6apm_lpass_dai_data data={0};
 unsigned maps[8]={0,1,2,3,4,0,0,0};
 const unsigned ids[]={TX_CODEC_DMA_TX_4,RX_CODEC_DMA_RX_0};
 for(unsigned d=0;d<2;d++) {
  struct snd_soc_dai dai={&data,ids[d]};
  struct audioreach_module_config *cfg=&data.module_config[dai.id];
  cfg->num_channels=4;
  assert(q6dma_set_channel_map(&dai,8,maps,8,maps)==0);
  assert(actual_mask(cfg)==30);
  assert(q6dma_set_channel_map(&dai,1,maps+1,1,maps+1)==0);
  assert(actual_mask(cfg)==1);
  struct audioreach_module_config before=*cfg;
  unsigned bad[]={1,256};
  assert(q6dma_set_channel_map(&dai,2,bad,2,bad)==-EINVAL);
  assert(memcmp(cfg,&before,sizeof(before))==0);
  assert(q6dma_set_channel_map(&dai,9,maps,9,maps)==-EINVAL);
  assert(q6dma_set_channel_map(&dai,1,NULL,1,NULL)==-EINVAL);
  assert(memcmp(cfg,&before,sizeof(before))==0);
  assert(q6dma_set_channel_map(&dai,0,maps,0,maps)==0 && actual_mask(cfg)==0);
  memset(cfg->channel_map,0xa5,sizeof(cfg->channel_map));
  audioreach_set_default_channel_mapping(cfg->channel_map,4);assert(actual_mask(cfg)==15);
  audioreach_set_default_channel_mapping(cfg->channel_map,2);assert(actual_mask(cfg)==3);
  audioreach_set_default_channel_mapping(cfg->channel_map,1);assert(actual_mask(cfg)==1);
 }
 printf("Actual channel-map code: %u sparse masks, four packed consumers, TX/RX replacement and refusals passed; host only.\n",cases);
}
C
} >> "$work/check.c"
${CC:-cc} -std=gnu11 -Wall -Wextra -Werror -Wno-sign-compare \
    -fsanitize=address,undefined -fno-omit-frame-pointer -idirafter "$kernel/include" \
    "$work/check.c" -o "$work/check"
"$work/check"

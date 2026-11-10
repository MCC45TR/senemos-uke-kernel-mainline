/* SPDX-License-Identifier: GPL-2.0-only OR MIT */
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "uke-ssc-heading.h"
#include "actual-iio-types.h"
#define BIT(n) (1UL<<(n))
#define GFP_KERNEL 0
#define IIO_CHAN_INFO_RAW 0
#define IIO_CHAN_INFO_SCALE 1
#define IIO_VAL_INT 1
#define IIO_VAL_INT_PLUS_MICRO 2
#define IIO_CPU 0
#define INDIO_DIRECT_MODE 1
#define SSC_TIMEOUT 100
#define SSC_STREAM_DIRECT 1U
#define SSC_STREAM_BUFFER 2U
#define SSC_STREAM_DUAL 4U
#define SSC_STREAM_HEADING_DIRECT 8U
#define SSC_STREAM_HEADING_BUFFER 16U
struct device {int unused;};
struct iio_dev;
struct iio_chan_spec {
 enum iio_chan_type type;int modified,scan_index;enum iio_modifier channel2;
 unsigned long info_mask_separate;
 struct {char sign;int realbits,storagebits,endianness;} scan_type;
};
#define IIO_CHAN_SOFT_TIMESTAMP(n) ((struct iio_chan_spec){.type=IIO_TIMESTAMP,.scan_index=(n)})
struct iio_info {int (*read_raw)(struct iio_dev *,const struct iio_chan_spec *,int *,int *,long);};
struct iio_buffer_setup_ops {int (*postenable)(struct iio_dev *);int (*predisable)(struct iio_dev *);};
struct iio_dev {void *priv;const char *name;const struct iio_info *info;int modes;struct iio_chan_spec *channels;int num_channels;const unsigned long *available_scan_masks;};
struct ssc_controller {struct device *dev;bool current;int control,state;};
struct ssc_description {const char *datatype;};
struct ssc_sensor {
 struct ssc_controller *controller;const struct ssc_description *description;
 struct iio_dev *heading_iio;struct iio_chan_spec heading_channel[2];
 bool heading_registered,heading_buffered,buffer_fault,ready,need_stop,stream_active;
 unsigned int stream_users;int error,sample_done;u64 ticks,sample_sequence;s64 sample[6];
};
static unsigned int starts,stops,pushes,claims,releases,waits;
static int start_error,stop_error,buffer_error;
static bool claim_ok=true,wait_ok=true,disconnect_on_stop,poison_on_stop,allocation_fail;
static unsigned char emitted[16];
static struct iio_dev allocated;
static struct ssc_sensor *private_sensor,*reading;
static bool ssc_current(struct ssc_controller *c){return c->current;}
static void mutex_lock(int *p){assert(!*p);*p=1;}
static void mutex_unlock(int *p){assert(*p);*p=0;}
#define spin_lock_irqsave(p,f) do{f=0;assert(!*(p));*(p)=1;}while(0)
#define spin_unlock_irqrestore(p,f) do{assert((f)==0&&*(p));*(p)=0;}while(0)
#define lockdep_assert_held(p) assert(*(p)==1)
static int ssc_start(struct ssc_sensor *s){assert(s->controller->control&&!s->controller->state);starts++;if(!start_error)s->stream_active=true;return start_error;}
static int ssc_stop(struct ssc_sensor *s){assert(s->controller->control&&!s->controller->state&&!s->stream_users);stops++;s->stream_active=false;if(disconnect_on_stop)s->controller->current=false;if(poison_on_stop)memset(s->sample,0,sizeof(s->sample));return stop_error;}
#include "actual-heading-streams.inc"
static bool iio_device_claim_direct(struct iio_dev *i){assert(i);claims++;return claim_ok;}
static void iio_device_release_direct(struct iio_dev *i){assert(i);releases++;}
static void *iio_priv(const struct iio_dev *i){return i->priv;}
static unsigned int wait_for_completion_timeout(int *completion,unsigned int timeout){assert(completion==&reading->sample_done&&timeout==SSC_TIMEOUT&&reading->controller->control&&!reading->controller->state);waits++;if(wait_ok){reading->ticks=50;reading->sample[3]=1000000;}return wait_ok;}
static s64 iio_get_time_ns(struct iio_dev *i){assert(i);return 987654321;}
static int iio_push_to_buffers_with_ts(struct iio_dev *i,void *scan,size_t size,s64 timestamp){assert(i&&size==16);memcpy((char *)scan+8,&timestamp,8);memcpy(emitted,scan,16);pushes++;return 0;}
static struct iio_dev *devm_iio_device_alloc(struct device *d,size_t bytes){assert(d&&bytes==sizeof(private_sensor));if(allocation_fail)return NULL;allocated=(struct iio_dev){.priv=&private_sensor};return &allocated;}
static int devm_iio_kfifo_buffer_setup(struct device *d,struct iio_dev *i,const struct iio_buffer_setup_ops *ops){assert(d&&i&&ops->postenable&&ops->predisable);return buffer_error;}
#include "uke-ssc-heading-input.h"
static void reset(struct ssc_sensor *s){starts=stops=pushes=claims=releases=waits=0;start_error=stop_error=buffer_error=0;claim_ok=wait_ok=true;disconnect_on_stop=poison_on_stop=allocation_fail=false;s->controller->current=true;s->controller->control=s->controller->state=0;s->ready=true;s->need_stop=s->buffer_fault=s->heading_buffered=s->stream_active=false;s->heading_registered=true;s->ticks=123;s->sample_sequence=5;s->stream_users=0;s->error=0;memset(s->sample,0,sizeof(s->sample));s->sample[3]=1000000;reading=s;memset(emitted,0xcc,sizeof(emitted));}
int main(void){
 struct device dev={0};struct ssc_controller c={.dev=&dev};const struct ssc_description desc[]={ {"rotv"},{"game_rv"},{"geomag_rv"},{"mag"}};struct ssc_sensor s={.controller=&c,.description=&desc[0]};private_sensor=&s;reset(&s);unsigned int checks=0;
 for(unsigned int n=1;n<4;n++){s.description=&desc[n];s.heading_iio=NULL;assert(ssc_heading_allocate(&c,&s)==0&&!s.heading_iio);checks++;}s.description=&desc[0];
 allocation_fail=true;assert(ssc_heading_allocate(&c,&s)==-ENOMEM);allocation_fail=false;assert(ssc_heading_allocate(&c,&s)==0);assert(s.heading_iio->num_channels==2&&s.heading_channel[0].type==IIO_ROT&&s.heading_channel[0].channel2==IIO_MOD_NORTH_MAGN_TILT_COMP&&s.heading_channel[0].scan_type.storagebits==32&&s.heading_channel[0].scan_type.realbits==32&&s.heading_channel[0].scan_index==0&&s.heading_channel[1].type==IIO_TIMESTAMP&&s.heading_channel[1].scan_index==1&&s.heading_iio->available_scan_masks[0]==1&&s.heading_iio->info->read_raw==ssc_heading_read_raw);checks+=2;
 for(unsigned int raw=0;raw<8;raw++){
  reset(&s);s.stream_users=raw;s.stream_active=raw!=0;int value=123,scale=456;poison_on_stop=true;
  assert(ssc_heading_read_raw(s.heading_iio,s.heading_channel,&value,&scale,IIO_CHAN_INFO_RAW)==IIO_VAL_INT&&value==0&&scale==456&&s.stream_users==raw&&starts==(raw?0U:1U)&&stops==(raw?0U:1U)&&claims==1&&releases==1&&!waits&&!c.control&&!c.state);checks++;
 }
 for(unsigned int fault=0;fault<9;fault++){
  reset(&s);int value=123,scale=456,wanted;switch(fault){case 0:claim_ok=false;wanted=-EBUSY;break;case 1:start_error=-EIO;wanted=-EIO;break;case 2:s.ticks=0;wait_ok=false;wanted=-ETIMEDOUT;break;case 3:s.error=-EREMOTEIO;wanted=-EREMOTEIO;break;case 4:stop_error=-EPIPE;wanted=-EPIPE;break;case 5:disconnect_on_stop=true;wanted=-ENOTCONN;break;case 6:s.sample[3]=0;wanted=-ERANGE;break;case 7:s.sample[0]=s.sample[3]=707107;wanted=-ENODATA;break;default:s.ready=false;wanted=-ENODEV;}
  assert(ssc_heading_read_raw(s.heading_iio,s.heading_channel,&value,&scale,IIO_CHAN_INFO_RAW)==wanted&&value==123&&scale==456&&!c.control&&!c.state&&!s.stream_users);checks++;
 }
 reset(&s);s.ticks=0;int value=123,scale=456;assert(ssc_heading_read_raw(s.heading_iio,s.heading_channel,&value,&scale,IIO_CHAN_INFO_RAW)==IIO_VAL_INT&&value==0&&waits==1);checks++;
 reset(&s);assert(ssc_heading_read_raw(s.heading_iio,s.heading_channel,&value,&scale,IIO_CHAN_INFO_SCALE)==IIO_VAL_INT_PLUS_MICRO&&!value&&scale==1&&!claims&&!starts);assert(ssc_heading_read_raw(s.heading_iio,s.heading_channel,&value,&scale,999)==-EINVAL);checks+=2;
 for(unsigned int raw=0;raw<8;raw++){
  reset(&s);s.stream_users=raw;s.stream_active=raw!=0;assert(ssc_heading_buffer_enable(s.heading_iio)==0&&s.heading_buffered&&s.stream_users==(raw|SSC_STREAM_HEADING_BUFFER)&&starts==(raw?0U:1U)&&pushes==1);s32 heading;memcpy(&heading,emitted,4);assert(!heading&&!memcmp(emitted+4,"\0\0\0\0",4));s64 timestamp;memcpy(&timestamp,emitted+8,8);assert(timestamp==987654321);assert(ssc_heading_buffer_enable(s.heading_iio)==-EBUSY);assert(ssc_heading_buffer_disable(s.heading_iio)==0&&!s.heading_buffered&&s.stream_users==raw&&stops==(raw?0U:1U));checks++;
 }
 reset(&s);start_error=-EIO;assert(ssc_heading_buffer_enable(s.heading_iio)==-EIO&&!s.heading_buffered&&!s.stream_users&&!pushes);checks++;
 for(unsigned int fault=0;fault<8;fault++){
  reset(&s);s.heading_buffered=s.stream_active=true;switch(fault){case 0:s.heading_registered=false;break;case 1:s.buffer_fault=true;break;case 2:c.current=false;break;case 3:s.ready=false;break;case 4:s.error=-EPIPE;break;case 5:s.ticks=0;break;case 6:s.sample[3]=0;break;default:s.sample[0]=s.sample[3]=707107;}
  ssc_heading_feed_locked(&s);assert(!pushes);checks++;
 }
 reset(&s);s.buffer_fault=true;s.stream_users=31;assert(ssc_stream_wanted(&s)==(SSC_STREAM_DIRECT|SSC_STREAM_DUAL|SSC_STREAM_HEADING_DIRECT));assert(!ssc_stream_user_valid(0)&&!ssc_stream_user_valid(3)&&!ssc_stream_user_valid(32));checks+=2;
 printf("Actual heading lifecycle: %u allocation/raw/scan/shared-owner/fault/stop/restart-boundary cases passed; no physical acceptance.\n",checks);
 return 0;
}

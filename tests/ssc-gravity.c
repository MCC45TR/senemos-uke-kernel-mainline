// SPDX-License-Identifier: GPL-2.0-only
// Exercise extracted production callbacks against independent public wire values.
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include "uke-ssc-protocol.h"
#include "actual-iio-types.h"
#define ARRAY_SIZE(a) (sizeof(a)/sizeof((a)[0]))
#define GFP_KERNEL 0
#define BIT(n) (1UL<<(n))
#define IIO_CHAN_INFO_RAW 0
#define IIO_CHAN_INFO_SCALE 1
#define IIO_CPU 0
#define INDIO_DIRECT_MODE 1
#define IIO_VAL_INT 1
#define IIO_VAL_INT_PLUS_MICRO 2
#include "actual-gravity-descriptions.inc"
struct device { int unused; };
struct iio_chan_spec_ext_info { int unused; };
struct iio_chan_spec {
 enum iio_chan_type type; unsigned int address; int scan_index;
 unsigned long info_mask_separate,info_mask_shared_by_type;
 struct { char sign; int realbits,storagebits,endianness; } scan_type;
 int modified; enum iio_modifier channel2; const char *extend_name;
 const struct iio_chan_spec_ext_info *ext_info;
};
#define IIO_CHAN_SOFT_TIMESTAMP(n) ((struct iio_chan_spec){.type=IIO_TIMESTAMP,.scan_index=(n)})
struct iio_mount_matrix { const char *rotation[9]; };
struct ssc_sensor;
struct iio_dev {
 void *priv; const char *name; const void *info; int modes;
 struct iio_chan_spec *channels; unsigned int num_channels;
 const unsigned long *available_scan_masks;
 size_t scan_bytes,timestamp_offset; bool timestamp;
};
struct completion { unsigned int done; };
struct ssc_controller { struct device *dev; bool current; struct ssc_sensor *sensor;struct {bool direct,buffered,reset_pending,buffer_fault;} dual; };
struct ssc_sensor {
 struct ssc_controller *controller; const struct ssc_description *description;
 struct iio_dev *iio; struct iio_chan_spec channel[SSC_SAMPLE_MAX+1];
 struct uke_ssc_attributes attributes; struct iio_mount_matrix mount_matrix;
 bool has_mount_matrix,ready,stream_active,buffered,registered;
 s64 sample[SSC_SAMPLE_MAX]; u64 ticks,sample_sequence; int error;
 struct completion sample_done;
};
static const int ssc_iio_info,ssc_buffer_ops;
static const struct iio_chan_spec_ext_info ssc_mount_matrix_info[]={{0}};
static const unsigned long ssc_xyz_masks[]={7,0},ssc_scalar_masks[]={1,0},ssc_gravity_masks[]={63,0};
static struct iio_dev allocated;static struct ssc_sensor *private_sensor;
static bool allocation_fails;static int buffer_error;
static unsigned char emitted[64];static size_t emitted_size;
static unsigned pushes,dual_feeds,proximity_feeds;
static void *iio_priv(const struct iio_dev *iio){return iio->priv;}
static struct iio_dev *devm_iio_device_alloc(struct device *d,size_t size){assert(d&&size==sizeof(private_sensor));if(allocation_fails)return NULL;allocated=(struct iio_dev){.priv=&private_sensor};return &allocated;}
static int devm_iio_kfifo_buffer_setup(struct device *d,struct iio_dev *i,const void *ops){assert(d&&i==&allocated&&ops==&ssc_buffer_ops);return buffer_error;}
static bool ssc_current(struct ssc_controller *c){return c->current;}
static void ssc_schedule_locked(struct ssc_controller *c){(void)c;assert(false);}
static void complete(struct completion *c){c->done++;}
static void ssc_dual_feed_locked(struct ssc_sensor *s){(void)s;dual_feeds++;}
static void ssc_proximity_feed_locked(struct ssc_sensor *s){(void)s;proximity_feeds++;}
static s64 iio_get_time_ns(struct iio_dev *i){(void)i;return 987654321;}
static int iio_push_to_buffers_with_ts(struct iio_dev *i,void *p,size_t bytes,s64 t){
 assert(bytes>=i->scan_bytes && i->scan_bytes<=sizeof emitted);
 if(i->timestamp)memcpy((char *)p+i->timestamp_offset,&t,sizeof t);
 memcpy(emitted,p,i->scan_bytes);emitted_size=i->scan_bytes;pushes++;return 0;
}
#include "actual-gravity-callbacks.inc"
static struct uke_ssc_event event(unsigned count,unsigned status,int corrupt,unsigned char *wire){
 // Packed standard event: floats followed by sample-status field2.
 wire[0]=0x0a;wire[1]=count*4;
 const uint32_t values[]={0x3f800000,0xc0000000,0x3f000000,0xbf000000,0x40000000,0x00000000,0x40400000};
 for(unsigned i=0;i<count;i++){uint32_t bits=(int)i==corrupt?0x7fc00000:values[i];memcpy(wire+2+4*i,&bits,4);}
 wire[2+4*count]=0x10;wire[3+4*count]=status;
 return (struct uke_ssc_event){.message=1025,.ticks=123,.payload={wire,4+4*count}};
}
int main(void){
 struct device dev={0};struct ssc_controller c={.dev=&dev,.current=true};
 const struct ssc_description *d=&ssc_descriptions[8];
 assert(!strcmp(d->datatype,"gravity")&&!strcmp(d->api,"sns_gravity.proto")&&d->kind==SSC_GRAVITY&&d->channel==IIO_GRAVITY&&d->dimensions==6&&d->multiplier==1000000);
 struct ssc_sensor s={.controller=&c,.description=d,.ready=true,.stream_active=true,.buffered=true,.registered=true};
 struct ssc_sensor others[9]={};c.sensor=others;
 unsigned checks=0;unsigned char wire[64];s64 out[8];
 for(unsigned count=1;count<=7;count++)for(unsigned status=0;status<=3;status++){
  for(unsigned i=0;i<8;i++)out[i]=123456;
  struct uke_ssc_event e=event(count,status,-1,wire);int ret=ssc_sample_values(&s,&e,out);
  assert(ret==(count!=6?-EBADMSG:status?0:-EAGAIN));
  if(!ret){const s64 wanted[]={1000000,-2000000,500000,-500000,2000000,0};assert(!memcmp(out,wanted,sizeof wanted));}
  assert(out[6]==123456&&out[7]==123456);checks++;
 }
 for(unsigned n=0;n<6;n++){struct uke_ssc_event e=event(6,3,n,wire);assert(ssc_sample_values(&s,&e,out)==-EBADMSG);checks++;}
 struct uke_ssc_event e=event(6,3,-1,wire);e.message=769;assert(ssc_sample_values(&s,&e,out)==-ENOMSG);checks++;
 for(unsigned sensor=0;sensor<9;sensor++)for(unsigned physical=0;physical<2;physical++){
  struct uke_ssc_attributes a={.available=true,.physical=physical,.rate_count=1,.rate={0x41200000}};
  strcpy(a.name,"synthetic-firmware");assert(ssc_attributes_usable(&ssc_descriptions[sensor],&a)==(physical||sensor==8));checks++;
 }
 for(unsigned fault=0;fault<4;fault++){
  struct uke_ssc_attributes a={.available=fault!=0,.physical=false,.hlos_incompatible=fault==1,.stream_type=fault==2?1:0,.rate_count=fault==3?0:1,.rate={0x41200000}};
  assert(!ssc_attributes_usable(d,&a));checks++;
 }
 int val=55,val2=66;assert(ssc_read_scale(d,&val,&val2)==IIO_VAL_INT_PLUS_MICRO&&val==0&&val2==1);checks++;
 assert(ssc_allocate_iio(&c,&s)==0&&s.iio==&allocated&&private_sensor==&s&&s.iio->num_channels==7);
 for(unsigned i=0;i<6;i++){
  const struct iio_chan_spec *ch=&s.channel[i];assert(ch->type==(i<3?IIO_GRAVITY:IIO_ACCEL)&&ch->modified&&ch->channel2==(i%3==0?IIO_MOD_X:i%3==1?IIO_MOD_Y:IIO_MOD_Z));
  assert(ch->address==i&&ch->scan_index==(int)i&&ch->scan_type.realbits==64&&ch->scan_type.storagebits==64&&ch->scan_type.sign=='s');
  assert((i<3&&!ch->extend_name)||(i>=3&&ch->extend_name&&!strcmp(ch->extend_name,"linear")));assert(!ch->ext_info);checks++;
 }
 assert(s.channel[6].type==IIO_TIMESTAMP&&s.channel[6].scan_index==6&&s.iio->available_scan_masks[0]==63&&s.iio->available_scan_masks[1]==0);checks++;
 allocation_fails=true;assert(ssc_allocate_iio(&c,&s)==-ENOMEM);allocation_fails=false;buffer_error=-EIO;assert(ssc_allocate_iio(&c,&s)==-EIO);buffer_error=0;checks+=2;
 // Every existing scalar/XYZ scan keeps its field count and timestamp offset.
 for(unsigned n=0;n<9;n++){
  s.description=&ssc_descriptions[n];assert(!ssc_allocate_iio(&c,&s));unsigned count=ssc_sample_channels(s.description);
  assert(count==(n==8?6:n<3?3:1));allocated.scan_bytes=(count+1)*8;allocated.timestamp_offset=count*8;allocated.timestamp=true;
  s.ticks=0;s.sample_sequence=0;s.sample_done.done=0;s.error=-EIO;
  struct { s64 data[6];s64 canary; } sample={{11,22,33,44,55,66},777};
  ssc_publish_locked(&s,sample.data,100);
  assert(sample.canary==777&&emitted_size==(count+1)*8&&!memcmp(emitted,sample.data,count*8));s64 stamp;memcpy(&stamp,emitted+count*8,8);assert(stamp==987654321&&s.ticks==100&&s.sample_sequence==1&&s.sample_done.done==1&&!s.error);
  for(unsigned i=count;i<6;i++)assert(!s.sample[i]);
  unsigned previous=pushes;ssc_publish_locked(&s,sample.data,100);assert(pushes==previous);s.ready=false;ssc_publish_locked(&s,sample.data,101);assert(pushes==previous);s.ready=true;c.current=false;ssc_publish_locked(&s,sample.data,102);assert(pushes==previous);c.current=true;checks++;
 }
 assert(pushes==9&&dual_feeds==9&&proximity_feeds==9);
 printf("Actual SSC gravity/linear callbacks:%u cases;6-value units/schema/metadata/IIO layout/scalar-XYZ timestamps/order and faults pass; no physical acceptance.\n",checks);
}

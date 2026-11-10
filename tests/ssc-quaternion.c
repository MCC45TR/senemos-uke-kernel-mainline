// SPDX-License-Identifier: GPL-2.0-only
// Actual callbacks, independent wire vectors and observable demand ownership.
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
#define IIO_VAL_INT_64 3
#define IIO_VAL_INT_MULTIPLE 4
#define SSC_STREAM_DIRECT 1
#define SSC_TIMEOUT 100
#include "actual-quaternion-descriptions.inc"
struct device { int unused; };
struct iio_chan_spec_ext_info { int unused; };
struct iio_chan_spec {
 enum iio_chan_type type; unsigned int address; int scan_index;
 unsigned long info_mask_separate,info_mask_shared_by_type;
 struct { char sign; int realbits,storagebits,endianness,repeat; } scan_type;
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
struct ssc_controller {
 struct device *dev; bool current; int control,state; struct ssc_sensor *sensor;
 struct {bool direct,buffered,reset_pending,buffer_fault;} dual;
};
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
static struct iio_dev allocated;static struct ssc_sensor *private_sensor,*reading;
static bool allocation_fails,claim_ok=true,wait_ok=true,disconnect_on_put,poison_on_put;
static int buffer_error,get_error,put_error;
static unsigned char emitted[64];static size_t emitted_size;
static unsigned pushes,claims,releases,gets,puts,waits;
static const s64 expected_q[]={500000,-500000,500000,-500000};
static void *iio_priv(const struct iio_dev *iio){return iio->priv;}
static struct iio_dev *devm_iio_device_alloc(struct device *d,size_t size){assert(d&&size==sizeof(private_sensor));if(allocation_fails)return NULL;allocated=(struct iio_dev){.priv=&private_sensor};return &allocated;}
static int devm_iio_kfifo_buffer_setup(struct device *d,struct iio_dev *i,const void *ops){assert(d&&i==&allocated&&ops==&ssc_buffer_ops);return buffer_error;}
static bool ssc_current(struct ssc_controller *c){return c->current;}
static void ssc_schedule_locked(struct ssc_controller *c){(void)c;assert(false);}
static void complete(struct completion *c){c->done++;}
static void ssc_dual_feed_locked(struct ssc_sensor *s){(void)s;}
static void ssc_proximity_feed_locked(struct ssc_sensor *s){(void)s;}
static s64 iio_get_time_ns(struct iio_dev *i){(void)i;return 987654321;}
static int iio_push_to_buffers_with_ts(struct iio_dev *i,void *p,size_t bytes,s64 t){assert(bytes>=i->scan_bytes&&i->scan_bytes<=sizeof emitted);if(i->timestamp)memcpy((char *)p+i->timestamp_offset,&t,sizeof t);memcpy(emitted,p,i->scan_bytes);emitted_size=i->scan_bytes;pushes++;return 0;}
static void mutex_lock(int *lock){assert(!*lock);*lock=1;}
static void mutex_unlock(int *lock){assert(*lock==1);*lock=0;}
#define spin_lock_irqsave(lock,flags) do{(flags)=0;assert(!*(lock));*(lock)=1;}while(0)
#define spin_unlock_irqrestore(lock,flags) do{assert((flags)==0&&*(lock)==1);*(lock)=0;}while(0)
static bool iio_device_claim_direct(struct iio_dev *i){(void)i;claims++;return claim_ok;}
static void iio_device_release_direct(struct iio_dev *i){(void)i;releases++;}
static int ssc_stream_get(struct ssc_sensor *s,unsigned owner){assert(s->controller->control==1&&!s->controller->state&&owner==SSC_STREAM_DIRECT);gets++;return get_error;}
static int ssc_stream_put(struct ssc_sensor *s,unsigned owner){assert(s->controller->control==1&&!s->controller->state&&owner==SSC_STREAM_DIRECT);puts++;if(poison_on_put)for(unsigned i=0;i<SSC_SAMPLE_MAX;i++)s->sample[i]=999999;if(disconnect_on_put)s->controller->current=false;return put_error;}
static unsigned wait_for_completion_timeout(struct completion *done,unsigned timeout){assert(done==&reading->sample_done&&timeout==SSC_TIMEOUT&&reading->controller->control==1);waits++;if(wait_ok){memcpy(reading->sample,expected_q,sizeof expected_q);reading->ticks=99;}return wait_ok?1:0;}
static void iio_val_s64_decompose(s64 value,int *low,int *high){*low=(uint32_t)value;*high=(uint64_t)value>>32;}
#include "actual-quaternion-callbacks.inc"
static struct uke_ssc_event event(unsigned count,unsigned status,int corrupt,unsigned char *wire){
 wire[0]=0x0a;wire[1]=count*4;
 const uint32_t values[]={0x3f000000,0xbf000000,0x3f000000,0xbf000000,0,0,0};
 for(unsigned i=0;i<count;i++){uint32_t bits=(int)i==corrupt?0x7fc00000:values[i];memcpy(wire+2+4*i,&bits,4);}
 wire[2+4*count]=0x10;wire[3+4*count]=status;
 return (struct uke_ssc_event){.message=1025,.ticks=123,.payload={wire,4+4*count}};
}
static void reset_read(struct ssc_sensor *s){
 claims=releases=gets=puts=waits=0;claim_ok=wait_ok=true;get_error=put_error=0;poison_on_put=disconnect_on_put=false;
 s->controller->current=true;s->controller->control=s->controller->state=0;s->ready=s->stream_active=true;s->error=0;s->ticks=123;
 memcpy(s->sample,expected_q,sizeof expected_q);reading=s;
}
int main(void){
 struct device dev={0};struct ssc_controller c={.dev=&dev,.current=true};struct ssc_sensor sensors[12]={};c.sensor=sensors;
 struct ssc_sensor s={.controller=&c,.ready=true,.stream_active=true,.buffered=true,.registered=true};
 unsigned checks=0;unsigned char wire[64];s64 values[8];
 assert(SSC_SENSOR_COUNT==12&&SSC_SAMPLE_MAX==6);
 const char *types[]={"rotv","game_rv","geomag_rv"},*apis[]={"sns_rotv.proto","sns_game_rv.proto","sns_geomag_rv.proto"};
 for(unsigned n=9;n<12;n++){
  s.description=&ssc_descriptions[n];assert(!strcmp(s.description->datatype,types[n-9])&&!strcmp(s.description->api,apis[n-9])&&s.description->kind==SSC_QUATERNION&&s.description->channel==IIO_ROT&&ssc_sample_channels(s.description)==4);checks++;
  for(unsigned count=1;count<=7;count++)for(unsigned status=0;status<=3;status++){
   for(unsigned i=0;i<8;i++){values[i]=7777777;}struct uke_ssc_event e=event(count,status,-1,wire);int ret=ssc_sample_values(&s,&e,values);
   assert(ret==(count!=4?-EBADMSG:status?0:-EAGAIN));if(!ret)assert(!memcmp(values,expected_q,sizeof expected_q));assert(values[4]==7777777&&values[7]==7777777);checks++;
  }
  for(unsigned i=0;i<4;i++){struct uke_ssc_event e=event(4,3,i,wire);assert(ssc_sample_values(&s,&e,values)==-EBADMSG);checks++;}
  struct uke_ssc_event e=event(4,3,-1,wire);uint32_t two=0x40000000;memcpy(wire+2,&two,4);assert(ssc_sample_values(&s,&e,values)==-ERANGE);e.message=769;assert(ssc_sample_values(&s,&e,values)==-ENOMSG);checks+=2;
  assert(!ssc_allocate_iio(&c,&s)&&s.iio->num_channels==2);const struct iio_chan_spec *ch=&s.channel[0];assert(ch->type==IIO_ROT&&ch->modified&&ch->channel2==IIO_MOD_QUATERNION&&ch->scan_type.repeat==4&&ch->scan_type.realbits==64&&ch->scan_type.storagebits==64&&!ch->ext_info&&!ch->extend_name&&ch->scan_index==0&&ch->address==0);assert(s.channel[1].type==IIO_TIMESTAMP&&s.channel[1].scan_index==1&&s.iio->available_scan_masks[0]==1&&!s.iio->available_scan_masks[1]);checks++;
  int out[6]={11,22,33,44,55,66},length=99;reset_read(&s);poison_on_put=true;assert(ssc_read_raw_multi(s.iio,ch,6,out,&length,IIO_CHAN_INFO_RAW)==IIO_VAL_INT_MULTIPLE&&length==4);for(unsigned i=0;i<4;i++)assert(out[i]==expected_q[i]);assert(out[4]==55&&out[5]==66&&gets==1&&puts==1&&claims==1&&releases==1&&!waits&&!c.control&&!c.state);checks++;
  reset_read(&s);s.ticks=0;assert(ssc_read_raw_multi(s.iio,ch,4,out,&length,IIO_CHAN_INFO_RAW)==IIO_VAL_INT_MULTIPLE&&waits==1&&gets==1&&puts==1);checks++;
  for(unsigned fault=0;fault<7;fault++){
   reset_read(&s);for(unsigned i=0;i<6;i++)out[i]=1234567;length=99;int wanted;
   switch(fault){case 0:claim_ok=false;wanted=-EBUSY;break;case 1:get_error=-ENODEV;wanted=-ENODEV;break;case 2:s.ticks=0;wait_ok=false;wanted=-ETIMEDOUT;break;case 3:s.error=-EIO;wanted=-EIO;break;case 4:put_error=-EREMOTEIO;wanted=-EREMOTEIO;break;case 5:disconnect_on_put=true;wanted=-ENOTCONN;break;default:s.sample[3]=1000001;wanted=-ERANGE;}
   assert(ssc_read_raw_multi(s.iio,ch,4,out,&length,IIO_CHAN_INFO_RAW)==wanted&&length==99);for(unsigned i=0;i<6;i++)assert(out[i]==1234567);assert(!c.control&&!c.state);assert(releases==(fault==0?0:1)&&puts==(fault<2?0:1));checks++;
  }
  reset_read(&s);assert(ssc_read_raw_multi(s.iio,ch,3,out,&length,IIO_CHAN_INFO_RAW)==-EINVAL&&!gets&&!claims);assert(ssc_read_raw_multi(s.iio,ch,1,out,&length,IIO_CHAN_INFO_SCALE)==-EINVAL);assert(ssc_read_raw_multi(s.iio,ch,2,out,&length,IIO_CHAN_INFO_SCALE)==IIO_VAL_INT_PLUS_MICRO&&length==2&&!out[0]&&out[1]==1&&!gets);checks++;
 }
 // Legacy read formats, all scan widths and timestamp offsets remain intact.
 for(unsigned n=0;n<12;n++){
  reset_read(&s);s.description=&ssc_descriptions[n];assert(!ssc_allocate_iio(&c,&s));unsigned count=ssc_sample_channels(s.description);bool q=n>=9;assert(s.iio->num_channels==(q?2:count+1));allocated.scan_bytes=(count+1)*8;allocated.timestamp_offset=count*8;allocated.timestamp=true;s.ticks=0;s.sample_sequence=0;
  const s64 input[]={11,22,33,44,55,66};ssc_publish_locked(&s,input,100);assert(emitted_size==(count+1)*8&&!memcmp(emitted,input,count*8));s64 stamp;memcpy(&stamp,emitted+count*8,8);assert(stamp==987654321);for(unsigned i=count;i<6;i++)assert(!s.sample[i]);checks++;
  if(q)continue;
  for(unsigned axis=0;axis<count;axis++){
   int out[4]={7,8,9,10},length=99;reset_read(&s);s.sample[axis]=-5000000001LL;struct iio_chan_spec *ch=&s.channel[axis];assert(ssc_read_raw_multi(s.iio,ch,4,out,&length,IIO_CHAN_INFO_RAW)==IIO_VAL_INT_64&&length==2);assert((uint32_t)out[0]==(uint32_t)-5000000001LL&&out[1]==-2&&out[2]==9&&out[3]==10&&gets==1&&puts==1);checks++;
  }
  struct uke_ssc_attributes a={.available=true,.physical=true,.rate_count=1,.rate={0x41200000}};assert(ssc_attributes_usable(s.description,&a));checks++;
 }
 for(unsigned n=0;n<12;n++){
  struct uke_ssc_attributes a={.available=true,.physical=false,.rate_count=1,.rate={0x41200000}};assert(ssc_attributes_usable(&ssc_descriptions[n],&a)==(n>=8));checks++;
  for(unsigned fault=0;fault<4&&n>=9;fault++){struct uke_ssc_attributes bad=a;if(fault==0)bad.available=false;if(fault==1)bad.hlos_incompatible=true;if(fault==2)bad.stream_type=1;if(fault==3)bad.rate_count=0;assert(!ssc_attributes_usable(&ssc_descriptions[n],&bad));checks++;}
 }
 assert(pushes==12);printf("Actual SSC quaternion callbacks:%u cases;XYZW repeat4,one-snapshot reads,legacy64/scalar-XYZ-gravity scans,metadata and faults pass; no physical acceptance.\n",checks);
}

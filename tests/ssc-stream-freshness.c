/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual production bodies; stream ACK and Linux IIO boundaries are controlled. */
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include "actual-iio-types.h"
typedef int64_t s64;
typedef uint64_t u64;
typedef uint32_t u32;
#include "descriptions.inc"
#define SSC_STREAM_BUFFER 2U
struct ssc_sensor;
struct iio_dev { struct ssc_sensor *sensor; unsigned int channels, scan_bytes; };
struct completion { unsigned int done; };
struct ssc_controller {
	int control, state;
	bool current;
	struct ssc_sensor *sensor;
	struct { bool direct, buffered, reset_pending, buffer_fault; } dual;
};
struct ssc_sensor {
	struct ssc_controller *controller;
	const struct ssc_description *description;
	struct iio_dev *iio;
	struct { unsigned int stream_type; } attributes;
	u64 ticks, sample_sequence;
	s64 sample[SSC_SAMPLE_MAX];
	int error;
	bool ready, stream_active, registered, buffered, buffer_fault;
	struct completion sample_done;
};
static struct ssc_sensor sensors[SSC_SENSOR_COUNT];
static struct ssc_controller controller;
static struct iio_dev iio;
static unsigned int stream_gets, stream_puts, pushes, time_reads;
static int get_error;
static bool early_report;
static s64 now, emitted_time, emitted[SSC_SAMPLE_MAX];
static unsigned char padding[64];
static const s64 values[SSC_SAMPLE_MAX] = {11,22,33,44,55,66};
static bool ssc_current(struct ssc_controller *c) { return c->current; }
static void *iio_priv(struct iio_dev *dev) { return &dev->sensor; }
static void mutex_lock(int *lock) { assert(!*lock); *lock=1; }
static void mutex_unlock(int *lock) { assert(*lock==1); *lock=0; }
#define spin_lock_irqsave(lock,flags) do {assert(!*(lock));*(lock)=1;(flags)=0;}while(0)
#define spin_unlock_irqrestore(lock,flags) do {assert(*(lock)==1);*(lock)=0;(void)(flags);}while(0)
static void complete(struct completion *c) { c->done++; }
static void ssc_dual_feed_locked(struct ssc_sensor *s) { assert(s->controller->state); }
static void ssc_proximity_feed_locked(struct ssc_sensor *s) { assert(s->controller->state); }
static void ssc_heading_feed_locked(struct ssc_sensor *s) { assert(s->controller->state); }
static void ssc_schedule_locked(struct ssc_controller *c) { (void)c; assert(false); }
static s64 iio_get_time_ns(struct iio_dev *dev) { assert(dev==&iio); time_reads++; return now; }
static int iio_push_to_buffers_with_ts(struct iio_dev *dev, void *scan, size_t bytes, s64 stamp)
{
	assert(dev==&iio && controller.state && bytes==64 && bytes>=dev->scan_bytes);
	memcpy(emitted,scan,dev->channels*sizeof(s64));
	memcpy((char *)scan+dev->channels*sizeof(s64),&stamp,sizeof(stamp));
	memcpy(padding,scan,dev->scan_bytes); emitted_time=stamp; pushes++;
	return 0;
}
static int ssc_stream_get(struct ssc_sensor *s, unsigned int user);
static int ssc_stream_put(struct ssc_sensor *s, unsigned int user);
#include "callbacks.inc"
static void report(struct ssc_sensor *s, u64 ticks)
{
	unsigned long flags;
	spin_lock_irqsave(&controller.state,flags);
	ssc_publish_locked(s,values,ticks);
	spin_unlock_irqrestore(&controller.state,flags);
}
static int ssc_stream_get(struct ssc_sensor *s, unsigned int user)
{
	assert(user==SSC_STREAM_BUFFER && controller.control && !controller.state);
	stream_gets++;
	if (get_error) return get_error;
	s->stream_active=true;
	if (early_report) report(s,s->ticks+1);
	return 0;
}
static int ssc_stream_put(struct ssc_sensor *s, unsigned int user)
{ (void)s; assert(user==SSC_STREAM_BUFFER && controller.control && !controller.state); stream_puts++; return 0; }
static struct ssc_sensor *reset(unsigned int index, unsigned int stream_type)
{
	memset(sensors,0,sizeof(sensors)); memset(&controller,0,sizeof(controller));
	controller.current=true; controller.sensor=sensors;
	struct ssc_sensor *s=&sensors[index];
	s->controller=&controller; s->description=&ssc_descriptions[index]; s->iio=&iio;
	s->ready=s->stream_active=s->registered=true; s->ticks=100; s->sample_sequence=4;
	s->attributes.stream_type=stream_type; memcpy(s->sample,values,sizeof(values));
	iio.sensor=s; iio.channels=ssc_sample_channels(s->description);
	iio.scan_bytes=s->description->kind==SSC_QUATERNION?64:(iio.channels+1)*8;
	stream_gets=stream_puts=pushes=time_reads=0; early_report=false; get_error=0; now=1000000000;
	return s;
}
int main(void)
{
	for(unsigned int index=0;index<SSC_SENSOR_COUNT;index++) {
		struct ssc_sensor *s=reset(index,0);
		assert(!ssc_buffer_enable(&iio));
		assert(stream_gets==1 && !pushes && !time_reads && s->buffered);
		assert(ssc_buffer_enable(&iio)==-EBUSY && stream_gets==1);
		now+=2000000000; report(s,101);
		assert(pushes==1 && time_reads==1 && emitted_time==now);
		assert(!memcmp(emitted,values,iio.channels*sizeof(s64)));
		s64 stamp;memcpy(&stamp,padding+iio.channels*8,8);assert(stamp==now);
		for(unsigned int i=(iio.channels+1)*8;i<iio.scan_bytes;i++)assert(!padding[i]);
		now++; report(s,101); assert(pushes==1 && time_reads==1);
		assert(!ssc_buffer_disable(&iio) && stream_puts==1 && !s->buffered);
		report(s,102); assert(pushes==1);
		s=reset(index,1); assert(!ssc_buffer_enable(&iio));
		assert(pushes==1 && time_reads==1 && emitted_time==now);
		assert(!ssc_buffer_disable(&iio) && stream_puts==1);
		for(unsigned int type=0;type<=1;type++) {
			s=reset(index,type);early_report=true;
			assert(!ssc_buffer_enable(&iio) && pushes==1 && s->sample_sequence==5);
			assert(!ssc_buffer_disable(&iio) && stream_puts==1);
		}
		s=reset(index,0);get_error=-ETIMEDOUT;
		assert(ssc_buffer_enable(&iio)==-ETIMEDOUT && !s->buffered && !pushes && !time_reads);
	}
	puts("Actual SSC buffer callbacks: all12 datatypes wait for a fresh streaming report, retain on-change replay/early-ACK deduplication, values/layout, duplicate/error/release gates; no device result");
	return 0;
}

/* SPDX-License-Identifier: GPL-2.0-only OR MIT */
/* Included after shared SSC stream ownership. No independent request worker. */
static void ssc_heading_feed_locked(struct ssc_sensor *s)
{
 struct {
  s32 heading;
  s32 padding;
  s64 timestamp;
 } scan = {};

 if (!s->heading_registered || !s->heading_buffered || s->buffer_fault ||
     !ssc_current(s->controller) || !s->ready || !s->stream_active ||
     s->error || !s->ticks ||
     uke_ssc_heading_microdegrees(s->sample, &scan.heading))
  return;
 iio_push_to_buffers_with_ts(s->heading_iio, &scan, sizeof(scan),
       iio_get_time_ns(s->heading_iio));
}

static int ssc_heading_read_raw(struct iio_dev *iio,
         const struct iio_chan_spec *channel,
         int *val, int *val2, long mask)
{
 struct ssc_sensor *s = *(struct ssc_sensor **)iio_priv(iio);
 struct ssc_controller *c = s->controller;
 unsigned long flags;
 s64 q[4];
 s32 heading = 0;
 bool cached;
 int ret, stop_ret;

 if (mask == IIO_CHAN_INFO_SCALE) {
  *val = 0;
  *val2 = 1;
  return IIO_VAL_INT_PLUS_MICRO;
 }
 if (mask != IIO_CHAN_INFO_RAW)
  return -EINVAL;
 if (!iio_device_claim_direct(iio))
  return -EBUSY;
 mutex_lock(&c->control);
 ret = ssc_stream_get(s, SSC_STREAM_HEADING_DIRECT);
 if (!ret) {
  spin_lock_irqsave(&c->state, flags);
  cached = ssc_current(c) && s->ready && s->stream_active &&
     !s->error && s->ticks;
  spin_unlock_irqrestore(&c->state, flags);
  if (!cached && !wait_for_completion_timeout(&s->sample_done, SSC_TIMEOUT))
   ret = -ETIMEDOUT;
  spin_lock_irqsave(&c->state, flags);
  if (!ret) {
   if (!ssc_current(c) || !s->ready || !s->stream_active || s->error || !s->ticks)
    ret = s->error ? s->error : -ENODATA;
   else
    memcpy(q, s->sample, sizeof(q));
  }
  spin_unlock_irqrestore(&c->state, flags);
  if (!ret)
   ret = uke_ssc_heading_microdegrees(q, &heading);
  stop_ret = ssc_stream_put(s, SSC_STREAM_HEADING_DIRECT);
  if (!ret)
   ret = stop_ret;
 }
 spin_lock_irqsave(&c->state, flags);
 if (!ret && (!ssc_current(c) || !s->ready))
  ret = -ENOTCONN;
 spin_unlock_irqrestore(&c->state, flags);
 mutex_unlock(&c->control);
 iio_device_release_direct(iio);
 if (ret)
  return ret;
 *val = heading;
 return IIO_VAL_INT;
}

static int ssc_heading_buffer_enable(struct iio_dev *iio)
{
 struct ssc_sensor *s = *(struct ssc_sensor **)iio_priv(iio);
 struct ssc_controller *c = s->controller;
 unsigned long flags;
 u64 sequence;
 int ret;

 mutex_lock(&c->control);
 spin_lock_irqsave(&c->state, flags);
 if (s->heading_buffered) {
  spin_unlock_irqrestore(&c->state, flags);
  mutex_unlock(&c->control);
  return -EBUSY;
 }
 sequence = s->sample_sequence;
 s->heading_buffered = true;
 s->buffer_fault = false;
 spin_unlock_irqrestore(&c->state, flags);
 ret = ssc_stream_get(s, SSC_STREAM_HEADING_BUFFER);
 spin_lock_irqsave(&c->state, flags);
 if (ret)
  s->heading_buffered = false;
 else if (s->sample_sequence == sequence)
  ssc_heading_feed_locked(s);
 spin_unlock_irqrestore(&c->state, flags);
 mutex_unlock(&c->control);
 return ret;
}

static int ssc_heading_buffer_disable(struct iio_dev *iio)
{
 struct ssc_sensor *s = *(struct ssc_sensor **)iio_priv(iio);
 struct ssc_controller *c = s->controller;
 unsigned long flags;

 mutex_lock(&c->control);
 spin_lock_irqsave(&c->state, flags);
 s->heading_buffered = false;
 spin_unlock_irqrestore(&c->state, flags);
 ssc_stream_put(s, SSC_STREAM_HEADING_BUFFER);
 mutex_unlock(&c->control);
 return 0;
}

static const struct iio_info ssc_heading_info = {
 .read_raw = ssc_heading_read_raw,
};
static const struct iio_buffer_setup_ops ssc_heading_buffer_ops = {
 .postenable = ssc_heading_buffer_enable,
 .predisable = ssc_heading_buffer_disable,
};
static const unsigned long ssc_heading_masks[] = { 1, 0 };

static int ssc_heading_allocate(struct ssc_controller *c, struct ssc_sensor *s)
{
 struct iio_dev *iio;

 /* Only the declared, magnetically referenced ROTV firmware contract.
  * GameRV never supplies north; no silent switch of coordinate/provider.
  */
 if (strcmp(s->description->datatype, "rotv"))
  return 0;
 iio = devm_iio_device_alloc(c->dev, sizeof(struct ssc_sensor *));
 if (!iio)
  return -ENOMEM;
 *(struct ssc_sensor **)iio_priv(iio) = s;
 s->heading_iio = iio;
 s->heading_channel[0] = (struct iio_chan_spec){
  .type = IIO_ROT, .modified = 1,
  .channel2 = IIO_MOD_NORTH_MAGN_TILT_COMP,
  .scan_index = 0,
  .info_mask_separate = BIT(IIO_CHAN_INFO_RAW) | BIT(IIO_CHAN_INFO_SCALE),
  .scan_type = { .sign = 's', .realbits = 32, .storagebits = 32,
    .endianness = IIO_CPU },
 };
 s->heading_channel[1] = IIO_CHAN_SOFT_TIMESTAMP(1);
 iio->name = "uke-ssc-magnetic-heading";
 iio->info = &ssc_heading_info;
 iio->modes = INDIO_DIRECT_MODE;
 iio->channels = s->heading_channel;
 iio->num_channels = 2;
 iio->available_scan_masks = ssc_heading_masks;
 return devm_iio_kfifo_buffer_setup(c->dev, iio, &ssc_heading_buffer_ops);
}

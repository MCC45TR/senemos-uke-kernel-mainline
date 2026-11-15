// SPDX-License-Identifier: GPL-2.0-only
/* Included after actual production structures and owner/direct/buffer callbacks.
 * SSC start/stop and IIO providers are controlled boundaries, not hardware tests.
 */
static struct {
	struct ssc_controller c;
	struct iio_dev iio;
	struct ssc_sensor *sensor;
	unsigned int starts, stops, waits, pushes;
	int start_error, stop_error;
	bool early_sample, wait_sample, wait_reset;
	s64 pushed, value;
} f;

static void sample(struct ssc_sensor *s)
{
	s->ticks = 900;
	s->sample[0] = f.value;
	s->sample_sequence++;
	s->error = 0;
	if (s->buffered && s->registered) {
		s64 scan[4] = {};

		memcpy(scan, s->sample, sizeof(s->sample));
		iio_push_to_buffers_with_ts(s->iio, scan, sizeof(scan), iio_get_time_ns(s->iio));
	}
	complete(&s->sample_done);
}

/* These providers preserve the already qualified low-level callback contract:
 * start invalidates its old sample; a failed command invalidates the namespace;
 * successful stop clears activity/ticks. Wire/ACK tests remain independent.
 */
static int ssc_start(struct ssc_sensor *s)
{
	assert(s->controller->control.locked && !s->controller->state);
	f.starts++;
	s->ticks = 0;
	s->stream_active = false;
	s->error = 0;
	reinit_completion(&s->sample_done);
	if (f.start_error) {
		ssc_invalidate_locked(s->controller);
		return f.start_error;
	}
	s->stream_active = true;
	if (f.early_sample)
		sample(s);
	return 0;
}

static int ssc_stop(struct ssc_sensor *s)
{
	assert(s->controller->control.locked && !s->controller->state);
	f.stops++;
	s->stream_active = false;
	s->need_stop = false;
	s->ticks = 0;
	if (f.stop_error)
		ssc_invalidate_locked(s->controller);
	return f.stop_error;
}

static unsigned long wait_for_completion_timeout(struct completion *done, unsigned long timeout)
{
	assert(f.c.control.locked && !f.c.state && done == &f.sensor->sample_done && timeout == SSC_TIMEOUT);
	f.waits++;
	if (f.wait_reset)
		ssc_invalidate_locked(&f.c);
	else if (f.wait_sample)
		sample(f.sensor);
	return done->done != 0;
}

static int iio_push_to_buffers_with_ts(struct iio_dev *iio, void *data, size_t size, s64 timestamp)
{
	assert(iio == &f.iio && size == 4 * sizeof(s64) && timestamp == 1000000);
	f.pushed = *(s64 *)data;
	f.pushes++;
	return 0;
}

static s64 iio_get_time_ns(struct iio_dev *iio)
{
	assert(iio == &f.iio);
	return 1000000;
}

static struct ssc_sensor *setup(void)
{
	memset(&f, 0, sizeof(f));
	f.sensor = &f.c.sensor[3];
	f.sensor->controller = &f.c;
	f.sensor->description = &ssc_descriptions[3];
	f.sensor->iio = &f.iio;
	f.sensor->ready = f.sensor->registered = true;
	f.c.client_open = true;
	f.c.endpoint_count = 1;
	f.c.generation = f.c.client_generation = 10;
	f.iio.private = &f.sensor;
	f.value = 123456789;
	return f.sensor;
}

static void permutations(void)
{
	const unsigned int order[6][3] = {
		{1,2,4}, {1,4,2}, {2,1,4}, {2,4,1}, {4,1,2}, {4,2,1}
	};
	for (unsigned int a = 0; a < 6; a++) {
		for (unsigned int b = 0; b < 6; b++) {
			struct ssc_sensor *s = setup();
			unsigned int mask = 0;

			mutex_lock(&f.c.control);
			for (unsigned int i = 0; i < 3; i++) {
				CHECK(ssc_stream_get(s, order[a][i]) == 0);
				mask |= order[a][i];
				CHECK(s->stream_users == mask && s->stream_active);
				CHECK(f.starts == 1 && f.stops == 0);
				CHECK(ssc_stream_get(s, order[a][i]) == -EBUSY);
				CHECK(s->stream_users == mask && f.starts == 1);
			}
			for (unsigned int i = 0; i < 3; i++) {
				CHECK(ssc_stream_put(s, order[b][i]) == 0);
				mask &= ~order[b][i];
				CHECK(s->stream_users == mask);
				CHECK(s->stream_active == (mask != 0));
				CHECK(f.stops == (mask == 0));
				CHECK(ssc_stream_put(s, order[b][i]) == -EINVAL);
			}
			mutex_unlock(&f.c.control);
		}
	}
}

static void invalid_and_restart(void)
{
	const unsigned int bad[] = { 0,3,5,6,7,8,UINT32_MAX };
	for (unsigned int i = 0; i < sizeof(bad)/sizeof(bad[0]); i++) {
		struct ssc_sensor *s = setup();

		mutex_lock(&f.c.control);
		CHECK(ssc_stream_get(s, bad[i]) == -EINVAL);
		CHECK(ssc_stream_put(s, bad[i]) == -EINVAL);
		CHECK(!s->stream_users && !f.starts && !f.stops);
		mutex_unlock(&f.c.control);
	}
	for (unsigned int mask = 0; mask < 8; mask++) {
		struct ssc_sensor *s = setup();

		s->stream_users = mask;
		CHECK(ssc_stream_wanted(s) == mask);
		s->buffer_fault = true;
		CHECK(ssc_stream_wanted(s) == (mask & ~SSC_STREAM_BUFFER));
		ssc_invalidate_locked(&f.c);
		CHECK(s->stream_users == mask && !s->stream_active && !s->ticks);
		CHECK(ssc_stream_wanted(s) == (mask & ~SSC_STREAM_BUFFER));
	}
	for (unsigned int fault = 0; fault < 8; fault++) {
		struct ssc_sensor *s = setup();

		s->stream_users = SSC_STREAM_DUAL;
		switch (fault) {
		case 0: f.c.removed = true; break;
		case 1: f.c.paused = true; break;
		case 2: f.c.lookup_fault = true; break;
		case 3: f.c.client_open = false; break;
		case 4: f.c.endpoint_count = 2; break;
		case 5: f.c.generation++; break;
		case 6: s->ready = false; break;
		case 7: s->need_stop = true; break;
		}
		mutex_lock(&f.c.control);
		CHECK(ssc_stream_get(s, SSC_STREAM_DIRECT) == -ENODEV);
		CHECK(s->stream_users == SSC_STREAM_DUAL && !f.starts);
		mutex_unlock(&f.c.control);
	}
	for (unsigned int user = 1; user <= 4; user <<= 1) {
		for (unsigned int n = 0; n < 3; n++) {
			const int error[] = { -EIO, -ETIMEDOUT, -ENODEV };
			struct ssc_sensor *s = setup();

			s->stream_users = 7U & ~user;
			f.start_error = error[n];
			mutex_lock(&f.c.control);
			CHECK(ssc_stream_get(s, user) == error[n]);
			CHECK(s->stream_users == (7U & ~user) && f.starts == 1);
			CHECK(!s->ready && !s->stream_active && !s->ticks);
			mutex_unlock(&f.c.control);
		}
	}
}

static int read_value(s64 expected)
{
	const struct iio_chan_spec channel = { .address = 0 };
	int low = 17, high = 42;
	int ret = ssc_read_raw(&f.iio, &channel, &low, &high, IIO_CHAN_INFO_RAW);

	CHECK(!f.c.control.locked && !f.iio.direct && !f.c.state);
	if (ret == IIO_VAL_INT_64)
		CHECK(((u64)(u32)high << 32 | (u32)low) == (u64)expected);
	else
		CHECK(low == 17 && high == 42);
	return ret;
}

static void selectors_and_result_values(void)
{
	const struct iio_chan_spec channel = { .address = 0 };
	const long invalid[] = { 1, -1, 99 };
	struct ssc_sensor *s = setup();
	int low = 17, high = 42;

	CHECK(IIO_CHAN_INFO_RAW == 0 && IIO_CHAN_INFO_SCALE == 2);
	CHECK(IIO_VAL_INT_64 == 6);
	f.iio.busy = true;
	for (unsigned int i = 0; i < sizeof(invalid)/sizeof(invalid[0]); i++) {
		CHECK(ssc_read_raw(&f.iio, &channel, &low, &high, invalid[i]) == -EINVAL);
		CHECK(low == 17 && high == 42);
	}
	CHECK(ssc_read_raw(&f.iio, &channel, &low, &high, IIO_CHAN_INFO_SCALE) == IIO_VAL_INT_PLUS_MICRO);
	CHECK(low == 0 && high == 1);
	CHECK(!s->stream_users && !f.starts && !f.stops && !f.waits && !f.iio.direct && !f.c.control.locked);
}

static void direct_and_buffer(void)
{
	struct ssc_sensor *s = setup();
	f.early_sample = true;
	CHECK(read_value(f.value) == IIO_VAL_INT_64);
	CHECK(f.starts == 1 && f.stops == 1 && !f.waits && !s->stream_users);

	s = setup(); f.wait_sample = true;
	CHECK(read_value(f.value) == IIO_VAL_INT_64);
	CHECK(f.starts == 1 && f.stops == 1 && f.waits == 1 && !s->stream_users);

	s = setup(); s->stream_active = true; s->ticks = 123;
	s->stream_users = SSC_STREAM_DUAL; s->sample[0] = f.value;
	CHECK(read_value(f.value) == IIO_VAL_INT_64);
	CHECK(!f.starts && !f.stops && !f.waits && s->stream_active && s->stream_users == SSC_STREAM_DUAL);

	s = setup(); s->stream_active = true; s->stream_users = SSC_STREAM_DUAL;
	CHECK(read_value(0) == -ETIMEDOUT);
	CHECK(!f.starts && !f.stops && f.waits == 1 && s->stream_users == SSC_STREAM_DUAL);

	s = setup(); s->stream_active = true; s->ticks = 123;
	s->stream_users = SSC_STREAM_DUAL; s->sample[0] = -8589934593LL;
	CHECK(read_value(s->sample[0]) == IIO_VAL_INT_64);
	CHECK(s->stream_active && s->stream_users == SSC_STREAM_DUAL);

	s = setup(); f.wait_reset = true; s->stream_users = SSC_STREAM_DUAL;
	CHECK(read_value(0) == -ENOTCONN);
	CHECK(!f.stops && s->stream_users == SSC_STREAM_DUAL && !s->stream_active);

	s = setup(); f.iio.busy = true;
	CHECK(read_value(0) == -EBUSY);
	CHECK(!s->stream_users && !f.starts && !f.stops);

	s = setup(); f.early_sample = true; f.stop_error = -EIO;
	CHECK(read_value(0) == -EIO);
	CHECK(!s->stream_users && f.stops == 1);

	s = setup(); f.start_error = -EIO;
	CHECK(read_value(0) == -EIO);
	CHECK(!s->stream_users && f.starts == 1 && !f.stops);

	/* Joining a live stream supplies one admitted current value, without
	 * another command, and detaching the buffer retains the dual owner.
	 */
	s = setup(); s->stream_active = true; s->ticks = 123;
	s->stream_users = SSC_STREAM_DUAL; s->sample[0] = f.value;
	CHECK(ssc_buffer_enable(&f.iio) == 0);
	CHECK(s->buffered && s->stream_users == (SSC_STREAM_DUAL | SSC_STREAM_BUFFER));
	CHECK(!f.starts && f.pushes == 1 && f.pushed == f.value);
	CHECK(ssc_buffer_enable(&f.iio) == -EBUSY && s->buffered);
	CHECK(ssc_buffer_disable(&f.iio) == 0);
	CHECK(!s->buffered && !f.stops && s->stream_active && s->stream_users == SSC_STREAM_DUAL);

	/* A first-sample-before-ACK publication already reached this new buffer. */
	s = setup(); f.early_sample = true;
	CHECK(ssc_buffer_enable(&f.iio) == 0);
	CHECK(f.starts == 1 && f.pushes == 1 && s->stream_users == SSC_STREAM_BUFFER);
	CHECK(ssc_buffer_disable(&f.iio) == 0);
	CHECK(!s->buffered && !s->stream_users && !s->stream_active && f.stops == 1);

	s = setup(); f.start_error = -ETIMEDOUT;
	s->stream_users = SSC_STREAM_DUAL;
	CHECK(ssc_buffer_enable(&f.iio) == -ETIMEDOUT);
	CHECK(!s->buffered && s->stream_users == SSC_STREAM_DUAL && !f.stops);
}

int main(void)
{
	permutations();
	invalid_and_restart();
	selectors_and_result_values();
	direct_and_buffer();
	printf("Actual shared SSC stream callbacks: %u assertions passed; controlled providers only.\n", assertions);
	return 0;
}

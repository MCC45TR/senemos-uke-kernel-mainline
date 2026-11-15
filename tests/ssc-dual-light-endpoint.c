// SPDX-License-Identifier: GPL-2.0-only
/* Controlled boundaries around actual endpoint, owner, publish and lid callbacks. */
static struct {
	struct ssc_controller c;
	struct iio_dev io[3];
	struct ssc_sensor *raw[2];
	struct ssc_controller *owner;
	struct workqueue_struct queue;
	unsigned int starts[2], stops[2], pushes[3], waits, registrations;
	unsigned int input_registered, input_unregistered, input_opened, input_closed;
	unsigned int cancelled, released, lookup_released, handlers_removed, iio_removed, queues_destroyed;
	unsigned int expected_iio_removed, expected_client_release;
	struct input_handle *handle;
	int input_register_error, input_open_error;
	bool linked, opened;
	s64 values[2], last[3];
	u64 tick;
	int start_error, stop_error, register_error;
	bool sample_on_start, sample_on_wait, reset_on_wait, lid_on_start;
} f;

static int input_register_handle(struct input_handle *handle)
{
	assert(!f.linked && !f.opened);
	f.input_registered++;
	if (f.input_register_error)
		return f.input_register_error;
	f.handle = handle;
	f.linked = true;
	return 0;
}

static void input_unregister_handle(struct input_handle *handle)
{
	assert(f.linked && !f.opened && f.handle == handle);
	f.input_unregistered++;
	f.linked = false;
	f.handle = NULL;
}

static int input_open_device(struct input_handle *handle)
{
	assert(f.linked && !f.opened && f.handle == handle && handle->handler->passive_observer);
	f.input_opened++;
	if (f.input_open_error)
		return f.input_open_error;
	f.opened = true;
	ssc_dual_lid_start(handle);
	return 0;
}

static void input_close_device(struct input_handle *handle)
{
	assert(f.linked && f.opened && f.handle == handle);
	f.input_closed++;
	f.opened = false;
}

static void cancel_work_sync(struct work_struct *work)
{
	assert(work == &f.c.reconcile && (f.c.paused || f.c.removed) && !f.c.control.locked && !f.c.state);
	f.cancelled++;
	f.queue.queued = 0;
}

static void qmi_handle_release(struct qmi_handle *qmi)
{
	if (qmi == &f.c.lookup) {
		assert(f.c.removed && !f.c.control.locked && !f.c.state && !f.linked);
		f.lookup_released++;
		qmi->live = false;
		return;
	}
	assert(qmi == &f.c.client && f.c.control.locked && !f.c.state && !f.c.client_open);
	qmi->live = false;
	f.released++;
}

static void input_unregister_handler(struct input_handler *handler)
{
	assert(handler == &f.c.dual.lid_handler && f.c.removed && !f.c.control.locked);
	f.handlers_removed++;
	if (f.handle)
		ssc_dual_lid_disconnect(f.handle);
}

static void iio_device_unregister(struct iio_dev *iio)
{
	assert(f.c.removed && !f.c.control.locked && !f.c.state && !f.c.client_open && !f.c.lookup.live);
	assert(f.cancelled == 1 && f.released == f.expected_client_release && !f.queues_destroyed);
	f.iio_removed++;
	if (iio->index == 2 && f.c.dual.buffered)
		CHECK(ssc_dual_buffer_disable(iio) == 0);
	else if (iio->index < 2 && f.raw[iio->index]->buffered)
		CHECK(ssc_buffer_disable(iio) == 0);
}

static void destroy_workqueue(struct workqueue_struct *queue)
{
	assert(queue == &f.queue && f.c.removed && !f.c.control.locked && !f.c.state);
	assert(f.iio_removed == f.expected_iio_removed && !f.linked && !f.c.lookup.live && !f.c.client.live);
	f.queues_destroyed++;
}

static void publish(unsigned int side, s64 value)
{
	s64 values[3] = { value, 0, 0 };
	unsigned long flags;

	spin_lock_irqsave(&f.c.state, flags);
	ssc_publish_locked(f.raw[side], values, ++f.tick);
	spin_unlock_irqrestore(&f.c.state, flags);
}

static unsigned int side_of(struct ssc_sensor *s)
{
	assert(s == f.raw[0] || s == f.raw[1]);
	return s == f.raw[1];
}

static int ssc_start(struct ssc_sensor *s)
{
	unsigned int side = side_of(s);
	assert(f.c.control.locked && !f.c.state);
	f.starts[side]++;
	s->ticks = 0;
	s->stream_active = false;
	s->error = 0;
	reinit_completion(&s->sample_done);
	ssc_dual_reset_locked(&f.c, -EAGAIN);
	if (f.start_error) {
		ssc_invalidate_locked(&f.c);
		return f.start_error;
	}
	s->stream_active = true;
	if (f.sample_on_start)
		publish(side, f.values[side]);
	if (f.lid_on_start) {
		f.lid_on_start = false;
		ssc_dual_lid_locked(&f.c, true, true);
	}
	return 0;
}

static int ssc_stop(struct ssc_sensor *s)
{
	unsigned int side = side_of(s);
	assert(f.c.control.locked && !f.c.state);
	f.stops[side]++;
	s->ticks = 0;
	s->stream_active = false;
	s->need_stop = false;
	ssc_dual_reset_locked(&f.c, -EAGAIN);
	if (f.stop_error)
		ssc_invalidate_locked(&f.c);
	return f.stop_error;
}

static unsigned long wait_for_completion_timeout(struct completion *done, unsigned long timeout)
{
	assert(f.c.control.locked && !f.c.state && timeout == SSC_TIMEOUT);
	assert(done == &f.c.dual.sample_done);
	f.waits++;
	if (f.reset_on_wait)
		ssc_invalidate_locked(&f.c);
	else if (f.sample_on_wait) {
		publish(0, f.values[0]);
		publish(1, f.values[1]);
	}
	return done->done != 0;
}

static int iio_push_to_buffers_with_ts(struct iio_dev *iio, void *data, size_t size, s64 timestamp)
{
	assert(iio >= &f.io[0] && iio <= &f.io[2]);
	assert(size == (iio->index == 2 ? 16 : 32) && timestamp == 1000000);
	f.pushes[iio->index]++;
	f.last[iio->index] = *(s64 *)data;
	return 0;
}

static s64 iio_get_time_ns(struct iio_dev *iio)
{ (void)iio; return 1000000; }

static int iio_device_register(struct iio_dev *iio)
{
	assert(f.c.control.locked && !f.c.state && iio == &f.io[2]);
	f.registrations++;
	return f.register_error;
}

static void setup(bool known, bool closed)
{
	memset(&f, 0, sizeof(f));
	f.owner = &f.c;
	f.c.client_open = true;
	f.c.client.live = true;
	f.c.lookup.live = true;
	f.c.endpoint_count = 1;
	f.c.generation = f.c.client_generation = 10;
	f.c.workqueue = &f.queue;
	f.tick = 100;
	f.expected_iio_removed = 3;
	f.expected_client_release = 1;
	f.values[0] = 5000000;
	f.values[1] = 2000000;
	for (unsigned int i = 0; i < SSC_SENSOR_COUNT; i++) {
		f.c.sensor[i].controller = &f.c;
		f.c.sensor[i].description = &ssc_descriptions[i];
	}
	for (unsigned int side = 0; side < 2; side++) {
		f.raw[side] = &f.c.sensor[SSC_FRONT_LIGHT + side];
		f.raw[side]->ready = f.raw[side]->registered = true;
		f.raw[side]->iio = &f.io[side];
		f.io[side].index = side;
		f.io[side].private = &f.raw[side];
	}
	f.io[2].index = 2;
	f.io[2].private = &f.owner;
	f.c.dual.iio = &f.io[2];
	f.c.dual.registered = true;
	f.c.dual.lid_known = known;
	f.c.dual.lid_closed = closed;
	f.c.dual.lid_handler.private = &f.c;
	f.c.dual.lid_handler.passive_observer = true;
}

static int read_value(s64 expected)
{
	const struct iio_chan_spec channel = { .address = 0 };
	int low = 17, high = 42;
	int ret = ssc_dual_read_raw(&f.io[2], &channel, &low, &high, IIO_CHAN_INFO_RAW);

	CHECK(!f.c.control.locked && !f.io[2].direct && !f.c.state && !f.c.dual.direct);
	if (ret == IIO_VAL_INT_64)
		CHECK(((u64)(u32)high << 32 | (u32)low) == (u64)expected);
	else
		CHECK(low == 17 && high == 42);
	return ret;
}

static void demands(void)
{
	for (unsigned int cover = 0; cover < 3; cover++) {
		for (unsigned int mask = 0; mask < 4; mask++) {
			setup(cover != 0, cover == 2);
			for (unsigned int side = 0; side < 2; side++) {
				if (!(mask & (1U << side)))
					continue;
				f.raw[side]->stream_active = true;
				f.raw[side]->stream_users = SSC_STREAM_BUFFER;
				f.raw[side]->buffered = true;
				publish(side, f.values[side]);
			}
			f.sample_on_start = true;
			CHECK(ssc_dual_buffer_enable(&f.io[2]) == 0);
			CHECK(f.c.dual.pair.active && f.c.dual.result_valid);
			CHECK(f.last[2] == (cover == 2 ? f.values[1] : f.values[0]));
			CHECK(f.starts[0] == (cover == 2 || (mask & 1) ? 0 : 1));
			CHECK(f.starts[1] == (mask & 2 ? 0 : 1));
			CHECK(ssc_dual_buffer_disable(&f.io[2]) == 0);
			CHECK(!f.c.dual.pair.active && !f.c.dual.result_valid);
			for (unsigned int side = 0; side < 2; side++) {
				CHECK(f.raw[side]->stream_users == (mask & (1U << side) ? SSC_STREAM_BUFFER : 0));
				CHECK(f.raw[side]->stream_active == !!(mask & (1U << side)));
			}
		}
	}
}

static void lid_and_samples(void)
{
	setup(true, false);
	f.sample_on_start = true;
	CHECK(ssc_dual_buffer_enable(&f.io[2]) == 0);
	CHECK(f.pushes[2] == 1 && f.last[2] == f.values[0]);
	publish(1, 3000000);
	CHECK(f.pushes[2] == 1);
	publish(1, 8000000);
	CHECK(f.pushes[2] == 2 && f.last[2] == 8000000);
	struct input_dev input = {};
	struct input_handle handle = { .dev = &input, .handler = &f.c.dual.lid_handler };
	ssc_dual_lid_event(&handle, EV_SW, SW_LID, 1);
	CHECK(f.c.dual.lid_known && f.c.dual.lid_closed && !f.c.dual.result_valid);
	mutex_lock(&f.c.control);
	CHECK(ssc_dual_reconcile(&f.c) == 0);
	mutex_unlock(&f.c.control);
	CHECK(f.starts[1] == 1 && f.stops[0] == 1 && f.stops[1] == 0);
	CHECK(f.c.dual.result_valid && f.last[2] == 8000000);
	unsigned int count = f.pushes[2];
	publish(0, 90000000);
	CHECK(f.pushes[2] == count && f.last[2] == 8000000);
	ssc_dual_lid_event(&handle, EV_SW, SW_LID, 0);
	CHECK(f.c.dual.front_needs_fresh && !f.c.dual.result_valid);
	f.sample_on_start = false;
	mutex_lock(&f.c.control);
	CHECK(ssc_dual_reconcile(&f.c) == 0);
	mutex_unlock(&f.c.control);
	CHECK(!f.c.dual.result_valid && f.pushes[2] == count);
	publish(1, 7000000);
	CHECK(!f.c.dual.result_valid);
	publish(0, 4000000);
	CHECK(f.c.dual.result_valid && f.last[2] == 7000000 && !f.c.dual.front_needs_fresh);
	count = f.pushes[2];
	u64 epoch = f.c.dual.epoch;
	ssc_dual_lid_event(&handle, EV_SW, SW_LID, 2);
	ssc_dual_lid_event(&handle, EV_SW + 1, SW_LID, 1);
	ssc_dual_lid_event(&handle, EV_SW, SW_LID + 1, 1);
	CHECK(f.c.dual.epoch == epoch && f.pushes[2] == count && !f.c.dual.lid_closed);
	CHECK(ssc_dual_buffer_disable(&f.io[2]) == 0);
}

static void direct_and_failure(void)
{
	for (unsigned int i = 0; i < 3; i++) {
		const s64 values[] = { 0, 1, 1099511627783LL };
		setup(false, false);
		f.values[0] = f.values[1] = values[i];
		f.sample_on_start = true;
		CHECK(read_value(values[i]) == IIO_VAL_INT_64);
		CHECK(!f.raw[0]->stream_users && !f.raw[1]->stream_users);
	}
	{
		const struct iio_chan_spec channel = { .address = 0 };
		int low = 17, high = 42;
		setup(false, false);
		CHECK(ssc_dual_read_raw(&f.io[2], &channel, &low, &high, IIO_CHAN_INFO_SCALE) == IIO_VAL_INT_PLUS_MICRO);
		CHECK(low == 0 && high == 1 && !f.starts[0] && !f.starts[1] && !f.io[2].direct);
		CHECK(ssc_dual_read_raw(&f.io[2], &channel, &low, &high, 1) == -EINVAL);
		CHECK(!f.c.dual.direct && !f.starts[0] && !f.starts[1]);
	}
	setup(false, false);
	f.sample_on_start = true;
	CHECK(read_value(f.values[0]) == IIO_VAL_INT_64);
	CHECK(f.starts[0] == 1 && f.starts[1] == 1 && f.stops[0] == 1 && f.stops[1] == 1 && !f.waits);
	setup(true, true);
	f.sample_on_wait = true;
	CHECK(read_value(f.values[1]) == IIO_VAL_INT_64);
	CHECK(f.starts[0] == 0 && f.starts[1] == 1 && f.stops[1] == 1 && f.waits == 1);
	setup(true, false);
	CHECK(read_value(0) == -ETIMEDOUT);
	CHECK(!f.raw[0]->stream_users && !f.raw[1]->stream_users);
	setup(true, false);
	f.reset_on_wait = true;
	CHECK(read_value(0) == -ENOTCONN);
	CHECK(!f.raw[0]->stream_users && !f.raw[1]->stream_users);
	for (unsigned int side = 0; side < 2; side++) {
		setup(true, true);
		f.raw[side]->ready = false;
		f.sample_on_start = true;
		CHECK(read_value(f.values[1]) == (side ? -ENOTCONN : IIO_VAL_INT_64));
		CHECK(!f.raw[0]->stream_users && !f.raw[1]->stream_users);
	}
	setup(true, false);
	f.start_error = -EIO;
	CHECK(ssc_dual_buffer_enable(&f.io[2]) == -EIO);
	CHECK(!f.c.dual.buffered && !f.c.dual.pair.active && !f.raw[0]->stream_users && !f.raw[1]->stream_users);
	setup(true, false);
	f.sample_on_start = true;
	f.lid_on_start = true;
	CHECK(ssc_dual_buffer_enable(&f.io[2]) == -EAGAIN);
	CHECK(!f.c.dual.buffered && !f.c.dual.result_valid);
}

static void snapshots_and_recovery(void)
{
	setup(false, false);
	struct input_dev input = {};
	struct input_handle handle = { .dev = &input, .handler = &f.c.dual.lid_handler };
	ssc_dual_lid_start(&handle);
	CHECK(!f.c.dual.lid_known && !f.c.dual.lid_closed);
	input.sw[0] = 1;
	ssc_dual_lid_start(&handle);
	CHECK(f.c.dual.lid_known && f.c.dual.lid_closed);
	input.sw[0] = 0;
	ssc_dual_lid_start(&handle);
	CHECK(f.c.dual.lid_known && !f.c.dual.lid_closed && f.c.dual.front_needs_fresh);
	CHECK(!f.c.state && !input.event_lock);
	f.c.removed = true;
	input.sw[0] = 1;
	ssc_dual_lid_start(&handle);
	CHECK(!f.c.dual.lid_closed);

	setup(true, false);
	f.sample_on_start = true;
	CHECK(ssc_dual_buffer_enable(&f.io[2]) == 0);
	CHECK(ssc_dual_buffer_enable(&f.io[2]) == -EBUSY && f.c.dual.buffered);
	u64 epoch = f.c.dual.epoch;
	unsigned int count = f.pushes[2];
	ssc_invalidate_locked(&f.c);
	CHECK(!f.c.dual.pair.active && !f.c.dual.result_valid && f.c.dual.buffered);
	CHECK(f.raw[0]->stream_users == SSC_STREAM_DUAL && f.raw[1]->stream_users == SSC_STREAM_DUAL);
	f.c.client_generation = f.c.generation;
	for (unsigned int i = 0; i < 2; i++) {
		f.raw[i]->ready = true;
		f.raw[i]->error = 0;
	}
	mutex_lock(&f.c.control);
	CHECK(ssc_dual_reconcile(&f.c) == 0);
	mutex_unlock(&f.c.control);
	CHECK(f.c.dual.epoch > epoch && f.c.dual.result_valid && f.pushes[2] == count + 1);
	CHECK(f.starts[0] == 2 && f.starts[1] == 2);
	CHECK(ssc_dual_buffer_disable(&f.io[2]) == 0);
	CHECK(!f.raw[0]->stream_users && !f.raw[1]->stream_users);

	setup(true, false);
	f.c.dual.epoch = UINT64_MAX;
	f.sample_on_start = true;
	CHECK(ssc_dual_buffer_enable(&f.io[2]) == -EOVERFLOW);
	CHECK(!f.c.dual.buffered && !f.c.dual.pair.active && !f.c.dual.result_valid);
	CHECK(!f.raw[0]->stream_users && !f.raw[1]->stream_users);

	setup(true, false);
	f.c.dual.registered = false;
	f.register_error = -ENOMEM;
	f.sample_on_start = true;
	CHECK(ssc_dual_buffer_enable(&f.io[2]) == -ENOMEM);
	CHECK(!f.c.dual.buffered && !f.c.dual.registered && !f.starts[0] && !f.starts[1]);
}

static void shared_front_freshness(void)
{
	setup(true, false);
	f.raw[0]->stream_active = true;
	f.raw[0]->buffered = true;
	f.raw[0]->stream_users = SSC_STREAM_BUFFER;
	publish(0, 9000000);
	f.sample_on_start = true;
	CHECK(ssc_dual_buffer_enable(&f.io[2]) == 0 && f.last[2] == 9000000);
	ssc_dual_lid_locked(&f.c, true, true);
	mutex_lock(&f.c.control);
	CHECK(ssc_dual_reconcile(&f.c) == 0);
	mutex_unlock(&f.c.control);
	CHECK(!f.starts[0] && !f.stops[0] && f.last[2] == f.values[1]);
	publish(0, 10000000);
	unsigned int count = f.pushes[2];
	ssc_dual_lid_locked(&f.c, true, false);
	mutex_lock(&f.c.control);
	CHECK(ssc_dual_reconcile(&f.c) == 0);
	mutex_unlock(&f.c.control);
	CHECK(!f.c.dual.result_valid && f.pushes[2] == count);
	CHECK(!f.starts[0] && !f.stops[0]);
	/* Waiting for an actual indication is deliberate: do not restart another
	 * consumer or pretend the covered sample was acquired after reopening.
	 */
	publish(0, 3000000);
	CHECK(f.c.dual.result_valid && f.last[2] == 3000000 && f.pushes[2] == count + 1);
	CHECK(ssc_dual_buffer_disable(&f.io[2]) == 0);
	CHECK(f.raw[0]->stream_users == SSC_STREAM_BUFFER && f.raw[0]->stream_active);
}

static void input_lifetime(void)
{
	const struct input_device_id id = {};
	struct input_dev input = {};
	struct device parent = {};
	struct device_node *lid = (struct device_node *)(uintptr_t)7;

	for (unsigned int fail = 0; fail < 3; fail++) {
		setup(false, false);
		input.sw[0] = 1;
		if (fail == 1)
			f.input_register_error = -ENOMEM;
		if (fail == 2)
			f.input_open_error = -EIO;
		int ret = ssc_dual_lid_connect(&f.c.dual.lid_handler, &input, &id);
		CHECK(ret == (fail == 1 ? -ENOMEM : fail == 2 ? -EIO : 0));
		CHECK(f.c.dual.connected == (fail == 0));
		CHECK(f.input_registered == 1 && f.input_opened == (fail != 1));
		if (!fail) {
			CHECK(f.linked && f.opened && f.c.dual.lid_known && f.c.dual.lid_closed);
			CHECK(ssc_dual_lid_connect(&f.c.dual.lid_handler, &input, &id) == -EBUSY);
			ssc_dual_lid_disconnect(f.handle);
			CHECK(f.input_closed == 1 && f.input_unregistered == 1 && !f.c.dual.connected);
			CHECK(!f.c.dual.lid_known && !f.c.dual.lid_closed);
		} else {
			CHECK(!f.input_closed && f.input_unregistered == (fail == 2));
		}
		CHECK(!f.linked && !f.opened && !f.handle);
	}
	setup(false, false);
	f.c.dual.lid_node = lid;
	CHECK(!ssc_dual_lid_match(&f.c.dual.lid_handler, &input));
	input.dev.parent = &parent;
	CHECK(!ssc_dual_lid_match(&f.c.dual.lid_handler, &input));
	parent.of_node = lid;
	CHECK(ssc_dual_lid_match(&f.c.dual.lid_handler, &input));
	parent.of_node = (struct device_node *)(uintptr_t)8;
	CHECK(!ssc_dual_lid_match(&f.c.dual.lid_handler, &input));
}

static void sleep_lifetime(void)
{
	setup(true, false);
	struct device dev = { .driver_data = &f.c };
	f.sample_on_start = true;
	CHECK(ssc_dual_buffer_enable(&f.io[2]) == 0);
	u64 epoch = f.c.dual.epoch;
	unsigned int count = f.pushes[2];
	CHECK(ssc_suspend(&dev) == 0);
	CHECK(f.c.paused && !f.c.client_open && f.cancelled == 1 && f.released == 1);
	CHECK(!f.c.dual.result_valid && !f.c.dual.pair.active && f.c.dual.buffered);
	CHECK(!f.raw[0]->stream_active && !f.raw[1]->stream_active);
	CHECK(f.raw[0]->stream_users == SSC_STREAM_DUAL && f.raw[1]->stream_users == SSC_STREAM_DUAL);
	ssc_dual_lid_locked(&f.c, true, true);
	CHECK(f.c.dual.lid_closed && !f.queue.queued);
	publish(0, 90000000);
	publish(1, 90000000);
	CHECK(f.pushes[2] == count && !f.c.dual.result_valid);
	CHECK(ssc_resume(&dev) == 0);
	CHECK(!f.c.paused && f.queue.queued == 1 && !f.c.dual.result_valid);
	/* The real worker rediscovers metadata before applying outstanding demand. */
	f.c.client_open = f.c.client.live = true;
	f.c.client_generation = f.c.generation;
	for (unsigned int i = 0; i < 2; i++) {
		f.raw[i]->ready = true;
		f.raw[i]->error = 0;
	}
	mutex_lock(&f.c.control);
	CHECK(ssc_dual_reconcile(&f.c) == 0);
	mutex_unlock(&f.c.control);
	CHECK(f.c.dual.epoch > epoch && f.c.dual.result_valid && f.last[2] == f.values[1]);
	CHECK(!f.raw[0]->stream_users && !f.raw[0]->stream_active);
	CHECK(ssc_dual_buffer_disable(&f.io[2]) == 0);
	CHECK(!f.raw[1]->stream_users && !f.raw[1]->stream_active);
}

static void remove_lifetime(void)
{
	for (unsigned int raw = 0; raw < 4; raw++) {
		setup(false, false);
		struct input_dev input = {};
		const struct input_device_id id = {};
		CHECK(ssc_dual_lid_connect(&f.c.dual.lid_handler, &input, &id) == 0);
		f.c.dual.handler_registered = true;
		for (unsigned int side = 0; side < 2; side++)
			if (raw & (1U << side)) {
				f.raw[side]->stream_active = true;
				f.raw[side]->buffered = true;
				f.raw[side]->stream_users = SSC_STREAM_BUFFER;
				publish(side, f.values[side]);
			}
		f.sample_on_start = true;
		CHECK(ssc_dual_buffer_enable(&f.io[2]) == 0);
		ssc_shutdown(&f.c);
		CHECK(f.c.removed && !f.c.dual.handler_registered && !f.c.dual.connected);
		CHECK(f.handlers_removed == 1 && f.lookup_released == 1 && f.cancelled == 1 && f.released == 1);
		CHECK(f.iio_removed == 3 && f.queues_destroyed == 1 && !f.linked && !f.opened && !f.handle);
		CHECK(!f.raw[0]->stream_users && !f.raw[1]->stream_users && !f.c.dual.buffered);
		CHECK(!f.c.dual.result_valid && !f.c.dual.pair.active);
	}
	/* Probe unwind, partial registration and removal after lost client. */
	for (unsigned int client = 0; client < 2; client++)
		for (unsigned int registered = 0; registered < 8; registered++)
			for (unsigned int handler = 0; handler < 2; handler++) {
				setup(false, false);
				f.c.client_open = f.c.client.live = client;
				f.expected_client_release = client;
				f.c.dual.handler_registered = handler;
				f.c.dual.registered = !!(registered & 4);
				f.raw[0]->registered = !!(registered & 1);
				f.raw[1]->registered = !!(registered & 2);
				f.expected_iio_removed = f.c.dual.registered +
					f.raw[0]->registered + f.raw[1]->registered;
				ssc_shutdown(&f.c);
				CHECK(f.c.removed && !f.c.dual.handler_registered);
				CHECK(f.lookup_released == 1 && f.cancelled == 1 && f.released == client);
				CHECK(f.handlers_removed == handler && f.iio_removed == f.expected_iio_removed);
				CHECK(f.queues_destroyed == 1 && !f.c.client_open && !f.c.lookup.live);
			}
}

int main(void)
{
	demands();
	lid_and_samples();
	direct_and_failure();
	snapshots_and_recovery();
	shared_front_freshness();
	input_lifetime();
	sleep_lifetime();
	remove_lifetime();
	printf("Actual combined-light callbacks: %u assertions passed; controlled SSC/input/IIO providers only.\n", assertions);
	return 0;
}

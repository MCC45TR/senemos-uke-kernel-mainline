// SPDX-License-Identifier: GPL-2.0-only
/* Actual driver callbacks; input core and SSC transport are controlled boundaries. */
static struct {
	struct ssc_controller c;
	struct workqueue_struct queue;
	struct iio_dev iio;
	struct ssc_sensor *s;
	unsigned int allocs, frees, registrations, unregistrations;
	unsigned int starts, stops, reports, syncs, waits, pushes;
	int start_error, stop_error, register_error;
	bool allocation_error, open_on_register, sample_on_start, sample_on_wait, reset_on_wait;
	s64 value;
	u64 tick;
} f;

static void publish(s64 value)
{
	s64 sample[3] = { value, 0, 0 };
	unsigned long flags;
	spin_lock_irqsave(&f.c.state, flags);
	ssc_publish_locked(f.s, sample, ++f.tick);
	spin_unlock_irqrestore(&f.c.state, flags);
}

static int ssc_start(struct ssc_sensor *s)
{
	assert(s == f.s && f.c.control.locked && !f.c.state);
	f.starts++;
	s->ticks = 0;
	s->stream_active = false;
	s->error = 0;
	reinit_completion(&s->sample_done);
	if (f.start_error) {
		ssc_invalidate_locked(&f.c);
		return f.start_error;
	}
	s->stream_active = true;
	if (f.sample_on_start)
		publish(f.value);
	return 0;
}

static int ssc_stop(struct ssc_sensor *s)
{
	assert(s == f.s && f.c.control.locked && !f.c.state);
	f.stops++;
	s->stream_active = false;
	s->ticks = 0;
	if (f.stop_error)
		ssc_invalidate_locked(&f.c);
	return f.stop_error;
}

static unsigned long wait_for_completion_timeout(struct completion *done, unsigned long timeout)
{
	assert(done == &f.s->sample_done && timeout == SSC_TIMEOUT && f.c.control.locked && !f.c.state);
	f.waits++;
	if (f.reset_on_wait)
		ssc_invalidate_locked(&f.c);
	else if (f.sample_on_wait)
		publish(f.value);
	return done->done != 0;
}

static struct input_dev *input_allocate_device(void)
{
	assert(f.c.control.locked && !f.c.state);
	if (f.allocation_error)
		return NULL;
	f.allocs++;
	return calloc(1, sizeof(struct input_dev));
}

static void input_free_device(struct input_dev *input)
{
	assert(input && !input->registered && !f.c.control.locked && !f.c.state);
	f.frees++;
	free(input);
}

static int input_register_device(struct input_dev *input)
{
	assert(!f.c.control.locked && !f.c.state && f.s->input == input);
	assert(input->dev.parent == &f.iio.dev && input->id.bustype == BUS_HOST);
	f.registrations++;
	if (f.register_error)
		return f.register_error;
	input->registered = true;
	/* A synchronous handler open must not deadlock on controller->control. */
	if (f.open_on_register)
		input->opened = input->open(input) == 0;
	return 0;
}

static void input_unregister_device(struct input_dev *input)
{
	assert(input->registered && !f.c.control.locked && !f.c.state);
	assert(!f.s->input && !f.s->input_open);
	f.unregistrations++;
	if (input->opened)
		input->close(input);
	input->registered = false;
	input_free_device(input);
}

static void input_report_switch(struct input_dev *input, unsigned int code, int value)
{
	assert(f.c.state && input == f.s->input && code == SW_FRONT_PROXIMITY);
	assert(value == 0 || value == 1);
	f.reports++;
	input->near = value;
}
static void input_sync(struct input_dev *input)
{ assert(input == f.s->input && f.c.state); f.syncs++; }
static void ssc_dual_feed_locked(struct ssc_sensor *s) { (void)s; }
static int iio_push_to_buffers_with_ts(struct iio_dev *iio, void *data, size_t bytes, s64 time)
{
	assert(iio == &f.iio && *(s64 *)data == f.s->sample[0] && bytes == 32 && time == 1000);
	f.pushes++;
	return 0;
}
static s64 iio_get_time_ns(struct iio_dev *iio) { assert(iio == &f.iio); return 1000; }

static void setup(void)
{
	memset(&f, 0, sizeof(f));
	f.c.workqueue = &f.queue;
	f.c.client_open = true;
	f.c.endpoint_count = 1;
	f.c.generation = f.c.client_generation = 10;
	f.s = &f.c.sensor[5];
	f.s->controller = &f.c;
	f.s->description = &ssc_descriptions[5];
	f.s->iio = &f.iio;
	f.s->declared = f.s->ready = f.s->registered = true;
	f.sample_on_start = true;
	f.value = 1;
}
static void finish(void)
{
	ssc_proximity_unregister(&f.c);
	CHECK(!f.s->input && !f.s->input_registered && !f.s->input_open);
	CHECK(f.allocs == f.frees);
}
static int open_input(void)
{
	int ret = f.s->input->open(f.s->input);
	f.s->input->opened = ret == 0;
	return ret;
}
static void close_input(void)
{
	f.s->input->close(f.s->input);
	f.s->input->opened = false;
}

int main(void)
{
	setup();
	CHECK(ssc_proximity_register(&f.c) == 0);
	CHECK(f.s->input_registered && !f.starts && !f.s->stream_users);
	CHECK(ssc_proximity_register(&f.c) == 0 && f.allocs == 1);
	CHECK(open_input() == 0 && f.s->input->near && f.starts == 1 && !f.waits);
	CHECK(f.s->stream_users == SSC_STREAM_INPUT && f.reports == 1);
	publish(0);
	CHECK(!f.s->input->near && f.reports == 2 && f.syncs == 2);
	close_input();
	CHECK(f.stops == 1 && !f.s->stream_users && !f.s->input_open);
	publish(1);
	CHECK(f.reports == 2);
	finish();

	setup(); f.open_on_register = true;
	CHECK(ssc_proximity_register(&f.c) == 0 && f.s->input_open);
	finish(); CHECK(f.stops == 1 && f.unregistrations == 1);

	setup(); f.allocation_error = true;
	CHECK(ssc_proximity_register(&f.c) == -ENOMEM && !f.s->input && !f.starts);
	finish();
	setup(); f.register_error = -EIO;
	CHECK(ssc_proximity_register(&f.c) == -EIO && !f.s->input && !f.starts);
	finish();
	setup(); f.s->ready = false;
	CHECK(ssc_proximity_register(&f.c) == 0 && !f.allocs); finish();
	setup(); f.c.paused = true;
	CHECK(ssc_proximity_register(&f.c) == 0 && !f.allocs); finish();
	setup(); f.c.removed = true;
	CHECK(ssc_proximity_register(&f.c) == 0 && !f.allocs); finish();
	setup(); f.s->description = &ssc_descriptions[6];
	CHECK(ssc_proximity_register(&f.c) == 0 && !f.allocs); finish();

	setup(); CHECK(ssc_proximity_register(&f.c) == 0);
	f.sample_on_start = false; f.sample_on_wait = true; f.value = 0;
	CHECK(open_input() == 0 && !f.s->input->near && f.waits == 1 && f.reports == 1);
	finish();
	setup(); CHECK(ssc_proximity_register(&f.c) == 0);
	f.sample_on_start = false;
	CHECK(open_input() == -ETIMEDOUT && !f.s->input_open && !f.s->stream_users && f.stops == 1);
	finish();
	setup(); CHECK(ssc_proximity_register(&f.c) == 0);
	f.sample_on_start = false; f.reset_on_wait = true;
	CHECK(open_input() == -ENOTCONN && !f.s->stream_users && !f.reports);
	finish();
	setup(); CHECK(ssc_proximity_register(&f.c) == 0);
	f.start_error = -EIO;
	CHECK(open_input() == -EIO && !f.s->stream_users && !f.reports);
	finish();
	setup(); CHECK(ssc_proximity_register(&f.c) == 0); f.value = 2;
	CHECK(open_input() == -ENODATA && !f.s->stream_users && !f.reports); finish();

	/* Raw IIO and input share one SUID request; neither releases the other. */
	setup(); CHECK(ssc_proximity_register(&f.c) == 0);
	mutex_lock(&f.c.control);
	CHECK(ssc_stream_get(f.s, SSC_STREAM_BUFFER) == 0);
	f.s->buffered = true;
	mutex_unlock(&f.c.control);
	CHECK(open_input() == 0 && f.starts == 1);
	publish(0); CHECK(f.pushes == 1 && !f.s->input->near);
	close_input(); CHECK(!f.stops && f.s->stream_users == SSC_STREAM_BUFFER);
	mutex_lock(&f.c.control);
	CHECK(ssc_stream_put(f.s, SSC_STREAM_BUFFER) == 0);
	mutex_unlock(&f.c.control);
	CHECK(f.stops == 1); finish();

	setup(); CHECK(ssc_proximity_register(&f.c) == 0 && open_input() == 0);
	mutex_lock(&f.c.control);
	CHECK(ssc_stream_get(f.s, SSC_STREAM_DIRECT) == 0);
	CHECK(ssc_stream_put(f.s, SSC_STREAM_DIRECT) == 0);
	mutex_unlock(&f.c.control);
	CHECK(f.starts == 1 && !f.stops && f.s->stream_users == SSC_STREAM_INPUT);
	/* A different SUID's auxiliary/ALS demand cannot own proximity. */
	f.c.sensor[SSC_FRONT_LIGHT].stream_users = SSC_STREAM_DUAL;
	close_input();
	CHECK(f.stops == 1 && f.c.sensor[SSC_FRONT_LIGHT].stream_users == SSC_STREAM_DUAL);
	finish();

	/* Namespace reset/suspend withdraws data, retains demand and replays a
	 * fresh admitted sample after normal reconcile has restored the stream. */
	setup(); CHECK(ssc_proximity_register(&f.c) == 0 && open_input() == 0);
	ssc_invalidate_locked(&f.c);
	publish(0); CHECK(f.reports == 1 && f.s->stream_users == SSC_STREAM_INPUT);
	f.c.client_generation = f.c.generation;
	f.s->ready = true;
	mutex_lock(&f.c.control);
	f.value = 0;
	CHECK(ssc_start(f.s) == 0);
	mutex_unlock(&f.c.control);
	CHECK(!f.s->input->near && f.reports == 2);
	f.c.paused = true; publish(1); CHECK(f.reports == 2);
	f.c.paused = false; publish(1); CHECK(f.reports == 3 && f.s->input->near);
	f.s->buffer_fault = true;
	CHECK(ssc_stream_wanted(f.s) == SSC_STREAM_INPUT);
	f.stop_error = -EIO; finish(); CHECK(f.stops == 1);
	printf("SSC proximity actual callbacks: %u assertions; no physical acceptance.\n", assertions);
	return 0;
}

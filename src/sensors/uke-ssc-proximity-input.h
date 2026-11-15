/* SPDX-License-Identifier: GPL-2.0-only */
/* A second, standard consumer of the existing validated SSC proximity stream.
 * Raw IIO values, wire format, SUID ownership and calibration are unchanged.
 */
static bool ssc_proximity_sample_locked(const struct ssc_sensor *s)
{
	return s->description->kind == SSC_PROXIMITY && s->input &&
	       ssc_current(s->controller) && s->ready && s->stream_active &&
	       !s->error && s->ticks &&
	       (s->sample[0] == 0 || s->sample[0] == 1);
}

static void ssc_proximity_feed_locked(struct ssc_sensor *s)
{
	if (!s->input_open || !ssc_proximity_sample_locked(s))
		return;
	input_report_switch(s->input, SW_FRONT_PROXIMITY, s->sample[0]);
	input_sync(s->input);
}

static int ssc_proximity_open(struct input_dev *input)
{
	struct ssc_sensor *s = input_get_drvdata(input);
	struct ssc_controller *c = s->controller;
	unsigned long flags;
	bool cached;
	int ret;

	mutex_lock(&c->control);
	if (s->description->kind != SSC_PROXIMITY || s->input != input) {
		ret = -ENODEV;
		goto out;
	}
	ret = ssc_stream_get(s, SSC_STREAM_INPUT);
	if (ret)
		goto out;
	spin_lock_irqsave(&c->state, flags);
	cached = ssc_proximity_sample_locked(s);
	spin_unlock_irqrestore(&c->state, flags);
	/* Initial EVIOCGSW must observe an admitted current sample, not the
	 * input core's zero-initialized bitmap. Wait on the existing completion.
	 */
	if (!cached && !wait_for_completion_timeout(&s->sample_done, SSC_TIMEOUT))
		ret = -ETIMEDOUT;
	spin_lock_irqsave(&c->state, flags);
	if (!ret) {
		if (!ssc_proximity_sample_locked(s))
			ret = s->error ? s->error : -ENODATA;
		else {
			s->input_open = true;
			ssc_proximity_feed_locked(s);
		}
	}
	spin_unlock_irqrestore(&c->state, flags);
	if (ret)
		ssc_stream_put(s, SSC_STREAM_INPUT);
out:
	mutex_unlock(&c->control);
	return ret;
}

static void ssc_proximity_close(struct input_dev *input)
{
	struct ssc_sensor *s = input_get_drvdata(input);
	struct ssc_controller *c = s->controller;
	unsigned long flags;
	bool held;
	int ret = 0;

	mutex_lock(&c->control);
	spin_lock_irqsave(&c->state, flags);
	s->input_open = false;
	held = !!(s->stream_users & SSC_STREAM_INPUT);
	spin_unlock_irqrestore(&c->state, flags);
	if (held)
		ret = ssc_stream_put(s, SSC_STREAM_INPUT);
	mutex_unlock(&c->control);
	if (ret && !READ_ONCE(c->removed))
		dev_warn_ratelimited(c->dev, "Proximity input stop failed: %d\n", ret);
}

/* Called only by the existing ordered reconcile worker, outside control.
 * Input registration can synchronously connect a handler which opens the
 * device; that callback must be able to acquire control itself.
 */
static int ssc_proximity_register(struct ssc_controller *c)
{
	struct ssc_sensor *s = NULL;
	struct input_dev *input;
	unsigned long flags;
	unsigned int i;
	bool ready, held;
	int ret;

	for (i = 0; i < SSC_SENSOR_COUNT; i++)
		if (c->sensor[i].declared &&
		    c->sensor[i].description->kind == SSC_PROXIMITY)
			s = &c->sensor[i];
	if (!s)
		return 0;
	mutex_lock(&c->control);
	spin_lock_irqsave(&c->state, flags);
	ready = ssc_current(c) && s->ready && s->registered && !s->input;
	spin_unlock_irqrestore(&c->state, flags);
	if (!ready) {
		mutex_unlock(&c->control);
		return 0;
	}
	input = input_allocate_device();
	if (!input) {
		mutex_unlock(&c->control);
		return -ENOMEM;
	}
	input->name = "Uke SSC Proximity";
	input->phys = "uke-ssc/proximity/input0";
	input->id.bustype = BUS_HOST;
	input->dev.parent = &s->iio->dev;
	input->open = ssc_proximity_open;
	input->close = ssc_proximity_close;
	input_set_drvdata(input, s);
	input_set_capability(input, EV_SW, SW_FRONT_PROXIMITY);
	spin_lock_irqsave(&c->state, flags);
	s->input = input;
	spin_unlock_irqrestore(&c->state, flags);
	mutex_unlock(&c->control);
	ret = input_register_device(input);
	mutex_lock(&c->control);
	spin_lock_irqsave(&c->state, flags);
	if (ret) {
		s->input = NULL;
		s->input_open = false;
	}
	s->input_registered = !ret;
	held = ret && (s->stream_users & SSC_STREAM_INPUT);
	spin_unlock_irqrestore(&c->state, flags);
	if (held)
		ssc_stream_put(s, SSC_STREAM_INPUT);
	mutex_unlock(&c->control);
	if (ret)
		input_free_device(input);
	return ret;
}

/* The caller has invalidated QMI and drained reconcile before this function.
 * Withdraw the input device before unregistering its IIO parent, and never
 * hold control across input_unregister_device's synchronous close callback.
 */
static void ssc_proximity_unregister(struct ssc_controller *c)
{
	struct input_dev *input;
	unsigned long flags;
	unsigned int i;
	bool registered;

	for (i = 0; i < SSC_SENSOR_COUNT; i++) {
		struct ssc_sensor *s = &c->sensor[i];

		mutex_lock(&c->control);
		spin_lock_irqsave(&c->state, flags);
		input = s->input;
		registered = s->input_registered;
		s->input = NULL;
		s->input_registered = false;
		s->input_open = false;
		spin_unlock_irqrestore(&c->state, flags);
		mutex_unlock(&c->control);
		if (!input)
			continue;
		if (registered)
			input_unregister_device(input);
		else
			input_free_device(input);
	}
}

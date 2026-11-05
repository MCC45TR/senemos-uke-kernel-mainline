// SPDX-License-Identifier: GPL-2.0-only
/* Actual provider clock/voltage/PM functions, with only OS/transport boundaries modeled. */
#define CAMCC_CLOCKS_MAIN original_clock_checks
#include "camcc-clocks-check.c"

static struct cam_cc_crm_lut crm_rates = {
	.rates = {{100000000, 0}, {200000000, 6}, {400000000, 6}}, .count = 3,
};
static struct cam_cc_crm_clock client;
static int send_calls, send_error, require_level, idle_calls, resume_calls, pm_error;
static u32 sent_value;

static int send_vote(void *context, u32 kind, u32 resource, u32 value)
{
	assert(context == &client && kind == client.kind && resource == client.resource);
	assert(cam_cc_power.iface_on && cam_cc_power.votes == CAM_CC_POWER_RAILS);
	/* Assert the actual voltage is sufficient at the transport boundary. */
	if (require_level) {
		assert(cam_cc_mm.level_votes[require_level] == 1);
		assert(cam_cc_mxc.level_votes[require_level] == 1);
	}
	send_calls++;
	sent_value = value;
	return send_error;
}

static void crm_reset(struct device *dev, bool prepared)
{
	clock_reset(dev, true);
	assert(cam_cc_clocks_init() == 0);
	client = (struct cam_cc_crm_clock) {
		.table = &crm_rates, .send = send_vote, .context = &client,
		.kind = CAM_CC_CRM_PERF, .resource = 0, .desired = 200000000,
	};
	struct cam_cc_clock *clock = cam_cc_clock_find(&test_clocks[3].hw);
	clock->crm = &client;
	send_calls = send_error = require_level = 0;
	if (prepared) {
		require_level = VDD_LOW;
		prepare_clock(3);
		assert(send_calls == 1 && sent_value == 2 && client.prepared);
	}
}

static void prepared_transitions(void)
{
	struct device dev;
	crm_reset(&dev, true);
	struct clk_hw *hw = &test_clocks[3].hw;
	const struct clk_ops *ops = hw->init->ops;
	int native_before = native_calls;
	require_level = VDD_NOMINAL;
	assert(ops->pre_rate_change(hw, 200000000, 400000000) == 0);
	assert(send_calls == 2 && sent_value == 3 && client.desired == 200000000);
	assert(ops->set_rate(hw, 400000000, 1) == 0);
	hw->rate = client.desired;
	assert(send_calls == 2 && client.desired == 400000000);
	assert(ops->post_rate_change(hw, 200000000, 400000000) == 0);
	assert(!client.staged && !client.committed);
	/* Down-rate PRE keeps high voltage until the new vote is acknowledged. */
	assert(ops->pre_rate_change(hw, 400000000, 100000000) == 0);
	assert(send_calls == 3 && sent_value == 1);
	assert(ops->set_rate(hw, 100000000, 1) == 0);
	hw->rate = client.desired;
	assert(ops->post_rate_change(hw, 400000000, 100000000) == 0);
	assert(cam_cc_mm.level_votes[VDD_LOWER_D1] == 1);
	assert(!cam_cc_mm.level_votes[VDD_NOMINAL]);
	require_level = VDD_LOWER_D1;
	unprepare_clock(3);
	assert(send_calls == 4 && sent_value == 0 && !client.prepared);
	assert(!cam_cc_mm.level_votes[VDD_LOWER_D1]);
	assert(native_calls == native_before && !cam_cc_power.fault);
	puts("CRM CCF: prepare/up/down/unprepare use acknowledged software votes and actual voltage ordering");
}

static void abort_transitions(void)
{
	struct device dev;
	for (int down = 0; down < 2; down++) {
		crm_reset(&dev, true);
		struct clk_hw *hw = &test_clocks[3].hw;
		const struct clk_ops *ops = hw->init->ops;
		unsigned long target = down ? 100000000 : 400000000;
		require_level = down ? VDD_LOW : VDD_NOMINAL;
		assert(ops->pre_rate_change(hw, 200000000, target) == 0);
		assert(ops->post_rate_change(hw, target, 200000000) == 0);
		assert(send_calls == 3 && sent_value == 2 && client.desired == 200000000);
		assert(cam_cc_mm.level_votes[VDD_LOW] == 1 && !client.staged);
		int before = send_calls;
		assert(ops->post_rate_change(hw, target, 200000000) == 0);
		assert(send_calls == before && cam_cc_mm.level_votes[VDD_LOW] == 1);
	}
	puts("CRM CCF: PRE abort restores the prior acknowledged vote before voltage cleanup; unreached/repeat ABORT does nothing");
}

static void stopped_and_invalid(void)
{
	struct device dev;
	crm_reset(&dev, false);
	struct clk_hw *hw = &test_clocks[3].hw;
	const struct clk_ops *ops = hw->init->ops;
	assert(ops->pre_rate_change(hw, 200000000, 400000000) == 0);
	assert(ops->set_rate(hw, 400000000, 1) == 0);
	hw->rate = client.desired;
	assert(ops->post_rate_change(hw, 200000000, 400000000) == 0);
	assert(send_calls == 0 && !cam_cc_mm.level_votes[VDD_NOMINAL]);
	require_level = VDD_NOMINAL;
	prepare_clock(3);
	assert(send_calls == 1 && sent_value == 3);
	int before = operations;
	assert(ops->pre_rate_change(hw, 400000000, 200000001) == -ERANGE);
	assert(send_calls == 1 && operations == before && !cam_cc_power.fault);
	u32 value;
	client.kind = CAM_CC_CRM_BW;
	assert(cam_cc_crm_clock_value(&client, 400000000, &value) == 0 && value == 400);
	struct cam_cc_crm_lut fractional = {
		.rates = {{100000001, 0}, {100999999, 0}}, .count = 2,
	};
	client.table = &fractional;
	assert(cam_cc_crm_clock_value(&client, 100999999, &value) == -ERANGE);
	puts("CRM CCF: stopped set caches without I/O; unsupported rates and unsafe whole-MHz CP boundaries refuse before voltage");
}

static void rate_faults(void)
{
	struct device dev;
	for (int phase = 0; phase < 4; phase++) {
		crm_reset(&dev, phase != 0);
		struct clk_hw *hw = &test_clocks[3].hw;
		const struct clk_ops *ops = hw->init->ops;
		if (phase == 2) {
			require_level = VDD_NOMINAL;
			assert(ops->pre_rate_change(hw, 200000000, 400000000) == 0);
		}
		send_error = -ETIMEDOUT;
		if (phase == 0) assert(ops->prepare(hw) == -EIO);
		if (phase == 1) {
			require_level = VDD_NOMINAL;
			assert(ops->pre_rate_change(hw, 200000000, 400000000) == -EIO);
		}
		if (phase == 2) assert(ops->post_rate_change(hw, 400000000, 200000000) == -EIO);
		if (phase == 3) unprepare_clock(3);
		assert(client.fault == -ETIMEDOUT && cam_cc_power.primary_error == -ETIMEDOUT);
		assert(cam_cc_clock_find(hw)->voted);
		int retained_level = phase == 1 || phase == 2 ? VDD_NOMINAL : VDD_LOW;
		assert(cam_cc_mm.level_votes[retained_level] == 1 && cam_cc_mxc.level_votes[retained_level] == 1);
		int before = send_calls + operations;
		assert(ops->pre_rate_change(hw, 200000000, 400000000) == -EIO);
		assert(ops->set_rate(hw, 400000000, 1) == -EIO);
		assert(ops->post_rate_change(hw, 400000000, 200000000) == -EIO);
		ops->unprepare(hw);
		assert(send_calls + operations == before);
	}
	crm_reset(&dev, true);
	assert(test_clocks[3].hw.init->ops->set_rate(&test_clocks[3].hw, 400000000, 1) == -EIO);
	assert(client.desired == 200000000 && send_calls == 1 && client.fault == -EUCLEAN);
	puts("CRM CCF: prepare/PRE/ABORT/unprepare failures and set without checked PRE retain votes and prohibit retry");
}

static int idle_hook(void *context)
{
	assert(context == &client && cam_cc_power.iface_on);
	assert(cam_cc_power.votes == CAM_CC_POWER_RAILS && iface.count == 1);
	idle_calls++;
	return pm_error;
}
static int resume_hook(void *context)
{
	assert(context == &client && cam_cc_power.iface_on);
	assert(cam_cc_power.votes == CAM_CC_POWER_RAILS && iface.count == 1);
	resume_calls++;
	return pm_error;
}
static void pm_transitions(void)
{
	struct device dev;
	for (int phase = 0; phase < 4; phase++) {
		crm_reset(&dev, false);
		cam_cc_power.before_suspend = idle_hook;
		cam_cc_power.after_resume = resume_hook;
		cam_cc_power.transport_context = &client;
		idle_calls = resume_calls = pm_error = 0;
		if (phase < 2) {
			pm_error = phase ? -EUCLEAN : -EBUSY;
			int before = operations;
			assert(dev.ops->runtime_suspend(&dev) == (phase ? -EIO : -EBUSY));
			assert(idle_calls == 1 && operations == before && cam_cc_power.iface_on);
			assert(!!cam_cc_power.fault == !!phase);
			if (!phase) { pm_error = 0; assert(dev.ops->runtime_suspend(&dev) == 0); }
			continue;
		}
		assert(dev.ops->runtime_suspend(&dev) == 0 && idle_calls == 1);
		assert(!cam_cc_power.votes && !cam_cc_power.iface_on);
		pm_error = phase == 3 ? -EREMOTEIO : 0;
		assert(dev.ops->runtime_resume(&dev) == (pm_error ? -EIO : 0));
		assert(resume_calls == 1 && cam_cc_power.iface_on && iface.count == 1 && cam_cc_power.votes == CAM_CC_POWER_RAILS);
		for (int i = 0; i < 3; i++) assert(regulators[i].count == 1);
		if (pm_error) {
			int before = operations;
			assert(dev.ops->runtime_suspend(&dev) == -EIO);
			assert(dev.ops->runtime_resume(&dev) == -EIO && operations == before);
			assert(resume_calls == 1);
		}
	}
	puts("CRM PM: idle/drain before power-off; EBUSY retains active state; failed rearm retains all rails/interface without rollback or retry");
}

int main(void)
{
	assert(original_clock_checks() == 0);
	prepared_transitions(); abort_transitions(); stopped_and_invalid(); rate_faults(); pm_transitions();
	puts("CRM CCF/PM callback contract passed; source model only, no firmware or camera activation");
	return 0;
}

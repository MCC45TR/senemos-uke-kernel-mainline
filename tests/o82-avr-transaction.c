// SPDX-License-Identifier: GPL-2.0-only
/* Actual encoder transaction, controlled MMIO providers, no device access. */
static struct {
	unsigned int reads[2], writes[2], restores[2], disables[2], checks;
	int setup_error, snapshot_error, final_error, final_mismatch;
	int restore_error, restore_mismatch;
	bool target_mismatch, fail_after_write, revoke_on_lock;
} f;
static struct dpu_encoder_virt *current;

static void lock(int *held)
{
	assert(!*held);
	*held = 1;
	if (f.revoke_on_lock)
		current->avr_enabled = false;
}

static void unlock(int *held)
{
	assert(*held == 1);
	*held = 0;
}

static int get(struct dpu_hw_intf *intf, u32 *period)
{
	assert(current->enc_spinlock == 1);
	f.reads[intf->id]++;
	if (f.snapshot_error == (int)intf->id && f.reads[intf->id] == 1)
		return -EIO;
	if (f.final_error == (int)intf->id && f.reads[intf->id] == 2)
		return -EIO;
	*period = intf->period;
	if (f.final_mismatch == (int)intf->id && f.reads[intf->id] == 2)
		(*period)++;
	return *period ? 0 : -EIO;
}

static int setup(struct dpu_hw_intf *intf, u32 lines, u32 *period)
{
	assert(current->enc_spinlock == 1 && f.reads[0] && f.reads[1]);
	f.writes[intf->id]++;
	if (f.setup_error == (int)intf->id && !f.fail_after_write)
		return -EIO;
	intf->period = lines * 842 + (f.target_mismatch && intf->id == 1);
	if (f.setup_error == (int)intf->id)
		return -EIO;
	*period = intf->period;
	return 0;
}

static int restore(struct dpu_hw_intf *intf, u32 period)
{
	assert(current->enc_spinlock == 1);
	f.restores[intf->id]++;
	if (f.restore_error == (int)intf->id)
		return -EIO;
	intf->period = period + (f.restore_mismatch == (int)intf->id);
	return 0;
}

static void enable(struct dpu_hw_intf *intf, bool on)
{
	assert(current->enc_spinlock == 1 && !on);
	f.disables[intf->id]++;
}

static void reset(struct dpu_encoder_virt *enc, struct dpu_hw_intf hw[2],
		  struct dpu_encoder_phys phys[2])
{
	unsigned int checks = f.checks;

	f = (typeof(f)) { .checks = checks, .setup_error = -1,
		.snapshot_error = -1, .final_error = -1, .final_mismatch = -1,
		.restore_error = -1, .restore_mismatch = -1 };
	for (unsigned int i = 0; i < 2; i++) {
		hw[i] = (struct dpu_hw_intf) {
			.ops = { .setup_avr = setup, .get_avr_period = get,
				.set_avr_period = restore, .enable_avr = enable },
			.id = i, .period = 1000,
		};
		phys[i] = (struct dpu_encoder_phys) {
			.hw_intf = &hw[i], .enable_state = DPU_ENC_ENABLED,
		};
	}
	*enc = (struct dpu_encoder_virt) {
		.avr_enabled = true, .num_phys_encs = 2,
		.phys_encs = { &phys[0], &phys[1] },
	};
	current = enc;
	admitted = true;
}

static void restored(struct dpu_encoder_virt *enc, struct dpu_hw_intf hw[2])
{
	assert(hw[0].period == 1000 && hw[1].period == 1000);
	assert(f.restores[0] == 1 && f.restores[1] == 1);
	assert(!f.disables[0] && !f.disables[1]);
	assert(enc->avr_enabled && enc->avr_failed && !enc->enc_spinlock);
	f.checks++;
}

int main(void)
{
	struct dpu_hw_intf hw[2];
	struct dpu_encoder_phys phys[2];
	struct dpu_encoder_virt enc;
	struct drm_crtc_state state = {
		.vrr_enabled = true, .adjusted_mode = { .lines = 11088 },
	};

	reset(&enc, hw, phys);
	assert(!dpu_encoder_uke_avr_retime(&enc.base, &state));
	assert(hw[0].period == 11088 * 842 && hw[1].period == hw[0].period);
	assert(f.reads[0] == 2 && f.reads[1] == 2);
	assert(f.writes[0] == 1 && f.writes[1] == 1);
	assert(!f.restores[0] && !f.restores[1] && !enc.enc_spinlock);
	assert(enc.avr_enabled && !enc.avr_failed);
	f.checks++;
	for (unsigned int gate = 0; gate < 12; gate++) {
		reset(&enc, hw, phys);
		state.adjusted_mode.lines = 11088;
		switch (gate) {
		case 0: enc.avr_enabled = false; break;
		case 1: enc.avr_failed = true; break;
		case 2: enc.num_phys_encs = 1; break;
		case 3: admitted = false; break;
		case 4: state.adjusted_mode.lines = -EINVAL; break;
		case 5: phys[1].hw_intf = NULL; break;
		case 6: phys[1].enable_state = DPU_ENC_DISABLED; break;
		case 7: hw[1].ops.get_avr_period = NULL; break;
		case 8: hw[1].ops.set_avr_period = NULL; break;
		case 9: hw[1].ops.enable_avr = NULL; break;
		case 10: phys[1].hw_intf = &hw[0]; break;
		case 11: f.revoke_on_lock = true; break;
		}
		assert(dpu_encoder_uke_avr_retime(&enc.base, &state) < 0);
		assert(!f.writes[0] && !f.writes[1] && !enc.enc_spinlock);
		f.checks++;
	}
	state.adjusted_mode.lines = 11088;
	for (int side = 0; side < 2; side++) {
		reset(&enc, hw, phys);
		f.snapshot_error = side;
		assert(dpu_encoder_uke_avr_retime(&enc.base, &state) == -EIO);
		assert(!f.writes[0] && !f.writes[1] && !enc.enc_spinlock);
		f.checks++;
		for (int partial = 0; partial < 2; partial++) {
			reset(&enc, hw, phys);
			f.setup_error = side;
			f.fail_after_write = partial;
			assert(dpu_encoder_uke_avr_retime(&enc.base, &state) == -EIO);
			restored(&enc, hw);
		}
		reset(&enc, hw, phys);
		f.final_error = side;
		assert(dpu_encoder_uke_avr_retime(&enc.base, &state) == -EIO);
		restored(&enc, hw);
		reset(&enc, hw, phys);
		f.final_mismatch = side;
		assert(dpu_encoder_uke_avr_retime(&enc.base, &state) == -EIO);
		restored(&enc, hw);
		for (int mismatch = 0; mismatch < 2; mismatch++) {
			reset(&enc, hw, phys);
			f.setup_error = 1;
			f.fail_after_write = true;
			if (mismatch)
				f.restore_mismatch = side;
			else
				f.restore_error = side;
			assert(dpu_encoder_uke_avr_retime(&enc.base, &state) == -EIO);
			assert(f.restores[0] == 1 && f.restores[1] == 1);
			assert(f.disables[0] == 1 && f.disables[1] == 1);
			assert(!enc.avr_enabled && enc.avr_failed && !enc.enc_spinlock);
			f.checks++;
		}
	}
	reset(&enc, hw, phys);
	hw[1].period++;
	assert(dpu_encoder_uke_avr_retime(&enc.base, &state) == -EINVAL);
	assert(!f.writes[0] && !f.writes[1] && !f.restores[0] && !f.restores[1]);
	f.checks++;
	reset(&enc, hw, phys);
	f.target_mismatch = true;
	assert(dpu_encoder_uke_avr_retime(&enc.base, &state) == -EINVAL);
	restored(&enc, hw);
	reset(&enc, hw, phys);
	state.vrr_enabled = false;
	assert(!dpu_encoder_uke_avr_retime(&enc.base, &state));
	assert(!f.reads[0] && !f.reads[1] && !f.writes[0] && !f.writes[1]);
	f.checks++;
	printf("Actual dual-INTF transaction scenarios passed:%u; no physical display claim.\n", f.checks);
	return 0;
}

/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual 7.3.1 driver data/callbacks, with modeled V4L2 and mutex boundaries. */
#include <assert.h>
#include <errno.h>
#include <time.h>
#include <linux/v4l2-subdev.h>
#include <linux/media-bus-format.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef uint8_t u8;
typedef uint32_t u32;
typedef int32_t s32;
typedef uint64_t u64;
typedef int64_t s64;
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#define do_div(n, base) ((n) /= (base))
#define to_ov08d10(sd_) ((struct ov08d10 *)((char *)(sd_) - offsetof(struct ov08d10, sd)))

#include "geometry-data.h"

struct mutex { unsigned held, acquisitions; };
struct v4l2_subdev { int unused; };
struct v4l2_subdev_state {
	struct v4l2_mbus_framefmt fmt;
	struct v4l2_rect crop;
};
struct v4l2_subdev_fh { struct v4l2_subdev_state *state; };
struct v4l2_ctrl { s64 val, minimum, maximum, step, def; };
struct ov08d10 {
	struct v4l2_subdev sd;
	struct mutex mutex;
	const struct ov08d10_lane_cfg *priv_lane;
	const struct ov08d10_mode *cur_mode;
	u8 modes_size;
	struct v4l2_ctrl *link_freq, *pixel_rate, *vblank, *hblank, *vflip, *hflip;
};
static struct ov08d10 *observed;
static unsigned control_calls;
static void mutex_lock(struct mutex *m)
{
	assert(!m->held);
	m->held = 1;
	m->acquisitions++;
}
static void mutex_unlock(struct mutex *m)
{
	assert(m->held == 1);
	m->held = 0;
}
static struct v4l2_mbus_framefmt *v4l2_subdev_state_get_format(
	struct v4l2_subdev_state *state, unsigned pad)
{
	assert(observed->mutex.held && state && !pad);
	return &state->fmt;
}
static __attribute__((unused)) struct v4l2_rect *v4l2_subdev_state_get_crop(
	struct v4l2_subdev_state *state, unsigned pad)
{
	assert(observed->mutex.held && state && !pad);
	return &state->crop;
}
static int __v4l2_ctrl_s_ctrl(struct v4l2_ctrl *ctrl, s32 val)
{
	assert(observed->mutex.held);
	control_calls++;
	ctrl->val = val;
	return 0;
}
static int __v4l2_ctrl_s_ctrl_int64(struct v4l2_ctrl *ctrl, s64 val)
{
	assert(observed->mutex.held);
	control_calls++;
	ctrl->val = val;
	return 0;
}
static int __v4l2_ctrl_modify_range(struct v4l2_ctrl *ctrl, s64 min,
	s64 max, u64 step, s64 def)
{
	assert(observed->mutex.held);
	control_calls++;
	ctrl->minimum = min;
	ctrl->maximum = max;
	ctrl->step = step;
	ctrl->def = def;
	return 0;
}
static const struct ov08d10_mode *nearest(const struct ov08d10_mode *modes,
	unsigned count, u32 width, u32 height)
{
	const struct ov08d10_mode *best = NULL;
	u64 minimum = UINT64_MAX;
	for (unsigned i = 0; i < count; ++i) {
		u64 d = llabs((s64)modes[i].width - width) +
			llabs((s64)modes[i].height - height);
		if (d < minimum) { minimum = d; best = &modes[i]; }
	}
	return best;
}
#define v4l2_find_nearest_size(m, n, wf, hf, w, h) nearest(m, n, w, h)
struct v4l2_subdev_pad_ops {
	int (*set_fmt)(struct v4l2_subdev *, struct v4l2_subdev_state *, struct v4l2_subdev_format *);
	int (*get_fmt)(struct v4l2_subdev *, struct v4l2_subdev_state *, struct v4l2_subdev_format *);
	int (*enum_mbus_code)(struct v4l2_subdev *, struct v4l2_subdev_state *, struct v4l2_subdev_mbus_code_enum *);
	int (*enum_frame_size)(struct v4l2_subdev *, struct v4l2_subdev_state *, struct v4l2_subdev_frame_size_enum *);
	int (*get_selection)(struct v4l2_subdev *, struct v4l2_subdev_state *, struct v4l2_subdev_selection *);
};

#include "geometry-functions.c"

/* Independent expected geometry from the pinned authored proposal. */
static const struct v4l2_rect expected[] = {
	{ .left = 4, .top = 8, .width = 3280, .height = 2460 },
	{ .left = 12, .top = 16, .width = 3264, .height = 2448 },
	{ .left = 12, .top = 16, .width = 3264, .height = 2448 },
};
static const struct v4l2_rect native = { .width = 3288, .height = 2476 };
static const struct v4l2_rect bounds = { .left = 4, .top = 8, .width = 3280, .height = 2464 };
static void rect_equal(struct v4l2_rect a, struct v4l2_rect b)
{
	assert(a.left == b.left && a.top == b.top &&
	       a.width == b.width && a.height == b.height);
}
static void check_selection(struct ov08d10 *sensor,
	struct v4l2_subdev_state *state, unsigned which, unsigned index)
{
	const unsigned targets[] = { V4L2_SEL_TGT_NATIVE_SIZE,
		V4L2_SEL_TGT_CROP_BOUNDS, V4L2_SEL_TGT_CROP_DEFAULT, V4L2_SEL_TGT_CROP };
	unsigned controls_before = control_calls;
	const struct ov08d10_mode *active_before = sensor->cur_mode;
	struct v4l2_subdev_state state_before = *state;
	for (unsigned repeat = 0; repeat < 3; ++repeat) {
		for (unsigned t = 0; t < ARRAY_SIZE(targets); ++t) {
			struct v4l2_subdev_selection sel = { .which = which, .target = targets[t] };
			assert(!ov08d10_pad_ops.get_selection(&sensor->sd, state, &sel));
			rect_equal(sel.r, t == 0 ? native : t == 3 ? expected[index] : bounds);
			assert(!sensor->mutex.held);
		}
	}
	assert(control_calls == controls_before && sensor->cur_mode == active_before);
	assert(!memcmp(state, &state_before, sizeof(*state)));
	assert(expected[index].left >= bounds.left && expected[index].top >= bounds.top);
	assert(expected[index].left + expected[index].width <= bounds.left + bounds.width);
	assert(expected[index].top + expected[index].height <= bounds.top + bounds.height);
	assert(expected[index].width == lane_cfg_2.sp_modes[index].width * (index == 2 ? 2 : 1));
	assert(expected[index].height == lane_cfg_2.sp_modes[index].height * (index == 2 ? 2 : 1));
}
static void set_format(struct ov08d10 *sensor, struct v4l2_subdev_state *state,
	unsigned which, unsigned index)
{
	struct v4l2_subdev_format fmt = { .which = which, .format = {
		.width = lane_cfg_2.sp_modes[index].width,
		.height = lane_cfg_2.sp_modes[index].height,
	} };
	assert(!ov08d10_pad_ops.set_fmt(&sensor->sd, state, &fmt));
	assert(!sensor->mutex.held && fmt.format.field == V4L2_FIELD_NONE);
	struct v4l2_subdev_format readback = { .which = which };
	assert(!ov08d10_pad_ops.get_fmt(&sensor->sd, state, &readback));
	assert(!memcmp(&fmt.format, &readback.format, sizeof(fmt.format)));
}
int main(void)
{
	fputs("OV08D10 geometry requires the actual get_selection callback\n", stderr);
	assert(ov08d10_pad_ops.get_selection);
	struct v4l2_ctrl ctrls[6] = {0};
	struct ov08d10 sensor = { .priv_lane = &lane_cfg_2, .modes_size = 3,
		.cur_mode = &lane_cfg_2.sp_modes[2], .link_freq = &ctrls[0],
		.pixel_rate = &ctrls[1], .vblank = &ctrls[2], .hblank = &ctrls[3],
		.vflip = &ctrls[4], .hflip = &ctrls[5] };
	observed = &sensor;
	sensor.modes_size = ov08d10_modes_num(&sensor);
	assert(sensor.modes_size == 3);
	for (unsigned flip = 0; flip < 4; ++flip) {
		sensor.vflip->val = flip >> 1;
		sensor.hflip->val = flip & 1;
		struct v4l2_subdev_state a = {0}, b = {0};
		struct v4l2_subdev_fh fa = { .state = &a }, fb = { .state = &b };
		const struct ov08d10_mode *active_before = sensor.cur_mode;
		unsigned controls_before = control_calls;
		assert(!ov08d10_open(&sensor.sd, &fa));
		assert(!ov08d10_open(&sensor.sd, &fb));
		assert(sensor.cur_mode == active_before && control_calls == controls_before);
		check_selection(&sensor, &a, V4L2_SUBDEV_FORMAT_TRY, 0);
		check_selection(&sensor, &b, V4L2_SUBDEV_FORMAT_TRY, 0);
		for (unsigned active = 0; active < 3; ++active) {
			struct v4l2_subdev_state a_before = a, b_before = b;
			controls_before = control_calls;
			set_format(&sensor, &a, V4L2_SUBDEV_FORMAT_ACTIVE, active);
			assert(control_calls == controls_before + 5);
			assert(sensor.cur_mode == &lane_cfg_2.sp_modes[active]);
			assert(!memcmp(&a, &a_before, sizeof(a)) && !memcmp(&b, &b_before, sizeof(b)));
			assert(sensor.vblank->def == (s64)lane_cfg_2.sp_modes[active].vts_def - lane_cfg_2.sp_modes[active].height);
			assert(sensor.link_freq->val == lane_cfg_2.sp_modes[active].link_freq_index);
			check_selection(&sensor, &a, V4L2_SUBDEV_FORMAT_ACTIVE, active);
			for (unsigned trial = 0; trial < 3; ++trial) {
				controls_before = control_calls;
				set_format(&sensor, &a, V4L2_SUBDEV_FORMAT_TRY, trial);
				assert(control_calls == controls_before && sensor.cur_mode == &lane_cfg_2.sp_modes[active]);
				assert(!memcmp(&b, &b_before, sizeof(b)));
				check_selection(&sensor, &a, V4L2_SUBDEV_FORMAT_TRY, trial);
				check_selection(&sensor, &a, V4L2_SUBDEV_FORMAT_ACTIVE, active);
				check_selection(&sensor, &b, V4L2_SUBDEV_FORMAT_TRY, 0);
			}
		}
		for (unsigned invalid = 0; invalid < 3; ++invalid) {
			struct v4l2_subdev_selection sel = { .which = V4L2_SUBDEV_FORMAT_ACTIVE,
				.target = V4L2_SEL_TGT_CROP, .r = { .left = -91, .top = -92, .width = 93, .height = 94 } };
			if (invalid == 0) sel.target = UINT32_MAX;
			if (invalid == 1) sel.pad = 1;
			if (invalid == 2) sel.which = UINT32_MAX;
			struct v4l2_rect original = sel.r;
			assert(ov08d10_pad_ops.get_selection(&sensor.sd, &a, &sel) == -EINVAL);
			rect_equal(sel.r, original);
			assert(!sensor.mutex.held);
		}
	}
	puts("OV08D10 actual data/callback geometry: all3 modes,2 independent TRY files,4 flips, ACTIVE controls, crop/binning, invalid inputs and repeat reads passed");
	return 0;
}

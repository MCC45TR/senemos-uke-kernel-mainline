/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef _UKE_RGB_POLICY_H
#define _UKE_RGB_POLICY_H
#include "uke-rgb-uapi.h"
struct uke_rgb_frame { __u32 rgb, brightness, delay_ms; };
#define UKE_RGB_CHARGE_NOTICE_MS 4500
struct uke_rgb_charge { int target, armed; };
/* A target already reached at boot or changed below SOC is not a new charge.
 * Keep the latch across disconnects and missing telemetry. Only an observed
 * two-percentage-point drop rearms it; repeated full/limit events stay quiet.
 */
static inline int uke_rgb_charge_event(struct uke_rgb_charge *state,
				      int target, int soc, int complete, int powered)
{
	if (!state || target < 1 || target > 100 || soc < 0 || soc > 100)
		return 0;
	if (state->target != target) {
		state->target = target;
		state->armed = soc <= target - 2;
		return 0;
	}
	if (soc <= target - 2)
		state->armed = 1;
	if (state->armed && soc >= target && complete && powered) {
		state->armed = 0;
		return 1;
	}
	return 0;
}
static inline enum uke_rgb_mode uke_rgb_battery_mode(int soc, enum uke_rgb_mode previous)
{
	if (soc < 0 || soc > 100)
		return previous;
	return soc <= 5 ? UKE_RGB_CRITICAL_BATTERY : soc <= 15 ? UKE_RGB_LOW_BATTERY : UKE_RGB_OFF;
}
static inline enum uke_rgb_mode uke_rgb_select(int camera, int test,
					      enum uke_rgb_mode battery, int manual)
{
	if (camera)
		return UKE_RGB_FRONT_CAMERA;
	if (test)
		return UKE_RGB_TEST;
	if (battery == UKE_RGB_CRITICAL_BATTERY || battery == UKE_RGB_LOW_BATTERY)
		return battery;
	return manual ? UKE_RGB_MANUAL : UKE_RGB_OFF;
}
static inline struct uke_rgb_frame uke_rgb_frame(enum uke_rgb_mode mode, __u64 elapsed,
						__u32 manual_rgb, __u32 manual_brightness)
{
	static const unsigned char breath[16] = {0, 0, 1, 2, 4, 6, 7, 8, 8, 8, 7, 6, 4, 2, 1, 0};
	struct uke_rgb_frame f = {0, 0, 0};
	__u32 t, step, r = 0, g = 0, b = 0, period, duration, n;

	if (mode == UKE_RGB_MANUAL) {
		f.rgb = manual_rgb;
		f.brightness = manual_brightness > UKE_RGB_LIMIT ? UKE_RGB_LIMIT : manual_brightness;
	} else if (mode == UKE_RGB_CRITICAL_BATTERY || mode == UKE_RGB_LOW_BATTERY) {
		duration = mode == UKE_RGB_CRITICAL_BATTERY ? 500 : 1000;
		period = 2000 + duration + (mode == UKE_RGB_CRITICAL_BATTERY ? 3000 : 10000);
		t = elapsed % period;
		f.rgb = 0xff0000;
		if (t < 1000) {
			step = t * UKE_RGB_LIMIT / 1000;
			f.brightness = step;
			f.delay_ms = (step + 1) * 1000 / UKE_RGB_LIMIT - t;
		} else if (t < 1000 + duration) {
			f.brightness = UKE_RGB_LIMIT;
			f.delay_ms = 1000 + duration - t;
		} else if (t < 2000 + duration) {
			t -= 1000 + duration;
			step = t * UKE_RGB_LIMIT / 1000;
			f.brightness = UKE_RGB_LIMIT - step;
			f.delay_ms = (step + 1) * 1000 / UKE_RGB_LIMIT - t;
		} else {
			f.delay_ms = period - t;
		}
	} else if (mode == UKE_RGB_CHARGE_COMPLETE && elapsed < UKE_RGB_CHARGE_NOTICE_MS) {
		t = elapsed % 1500;
		f.rgb = 0x0000ff;
		f.brightness = t < 1000 ? 0 : UKE_RGB_LIMIT;
		f.delay_ms = t < 1000 ? 1000 - t : 1500 - t;
	} else if (mode == UKE_RGB_TEST && elapsed < UKE_RGB_TEST_MS) {
		n = elapsed * 48 / UKE_RGB_TEST_MS;
		step = (n % 8) * 255 / 8;
		switch (n / 8) {
		case 0: r = 255; g = step; break;
		case 1: r = 255 - step; g = 255; break;
		case 2: g = 255; b = step; break;
		case 3: g = 255 - step; b = 255; break;
		case 4: r = step; b = 255; break;
		default: r = 255; b = 255 - step; break;
		}
		f.rgb = (r << 16) | (g << 8) | b;
		f.brightness = UKE_RGB_LIMIT;
		f.delay_ms = ((n + 1) * UKE_RGB_TEST_MS + 47) / 48 - elapsed;
	} else if (mode == UKE_RGB_FRONT_CAMERA) {
		period = 2000;
		duration = 2000;
		t = elapsed % period;
		f.rgb = 0x00ff00;
		if (t < duration) {
			step = t * 16 / duration;
			f.brightness = breath[step];
			f.delay_ms = ((step + 1) * duration + 15) / 16 - t;
		} else {
			f.delay_ms = period - t;
		}
	}
	return f;
}
#endif

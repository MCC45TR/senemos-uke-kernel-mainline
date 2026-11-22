/* SPDX-License-Identifier: GPL-2.0-only */
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

typedef uint32_t u32;
#define DIV_ROUND_CLOSEST(value, divisor) (((value) + (divisor) / 2) / (divisor))
#define DIV_ROUND_CLOSEST_ULL(value, divisor) DIV_ROUND_CLOSEST(value, divisor)
#define mul_u32_u32(left, right) ((uint64_t)(left) * (right))

struct drm_color_lut {
	uint16_t red, green, blue, reserved;
};

struct drm_property_blob {
	size_t length;
	const void *data;
};

#include "gamma-helper.inc"

static void set_ramp(struct drm_color_lut *lut, unsigned int rounding)
{
	unsigned int i;

	for (i = 0; i < DPU_GAMMA_LUT_SIZE; i++) {
		uint16_t sample = (i * UINT16_MAX + rounding) /
				  (DPU_GAMMA_LUT_SIZE - 1);

		lut[i] = (struct drm_color_lut){sample, sample, sample, 0};
	}
}

int main(void)
{
	struct drm_color_lut lut[DPU_GAMMA_LUT_SIZE] = {};
	struct drm_property_blob blob = {sizeof(lut), lut};
	const unsigned int middle = DPU_GAMMA_LUT_SIZE / 2;
	const unsigned int last = DPU_GAMMA_LUT_SIZE - 1;

	set_ramp(lut, 0);
	assert(dpu_crtc_gamma_is_identity(&blob));
	set_ramp(lut, last - 1);
	assert(dpu_crtc_gamma_is_identity(&blob));
	set_ramp(lut, last / 2);
	assert(dpu_crtc_gamma_is_identity(&blob));

	/* Preserve real color changes on each channel and at either endpoint. */
	lut[middle].red += 80;
	assert(!dpu_crtc_gamma_is_identity(&blob));
	set_ramp(lut, 0);
	lut[middle].green -= 80;
	assert(!dpu_crtc_gamma_is_identity(&blob));
	set_ramp(lut, 0);
	lut[0].blue = 100;
	assert(!dpu_crtc_gamma_is_identity(&blob));
	set_ramp(lut, 0);
	lut[last].blue -= 100;
	assert(!dpu_crtc_gamma_is_identity(&blob));

	for (unsigned int i = 0; i < DPU_GAMMA_LUT_SIZE; i++)
		lut[i] = (struct drm_color_lut){i * 64, i * 64, i * 64, 0};
	assert(!dpu_crtc_gamma_is_identity(&blob));

	set_ramp(lut, 0);
	blob.length -= 1;
	assert(!dpu_crtc_gamma_is_identity(&blob));
	blob.length = sizeof(lut) + 1;
	assert(!dpu_crtc_gamma_is_identity(&blob));
	puts("Native DPU gamma identity and genuine transforms passed.");
}

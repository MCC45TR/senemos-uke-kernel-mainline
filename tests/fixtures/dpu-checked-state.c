/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual Linux callbacks/iterator with synthetic state; no physical claim. */
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef uint64_t u64;
typedef uint32_t u32;
struct drm_plane_state { unsigned int marker; };
struct dpu_plane_state {
	struct drm_plane_state base;
	u64 plane_fetch_bw, plane_clk;
};
struct drm_plane { unsigned int index; struct drm_plane_state *state; };
struct drm_device { struct drm_plane *planes[4]; };
struct drm_atomic_commit {
	struct drm_device *dev;
	struct drm_plane_state *updates[4];
};
struct drm_display_mode { unsigned int vtotal, hdisplay, refresh; };
struct drm_crtc_state {
	struct drm_atomic_commit *state;
	u32 plane_mask;
	struct drm_display_mode adjusted_mode;
};
struct drm_crtc { struct drm_device *dev; struct drm_crtc_state *state; };
struct dpu_perf_cfg {
	u32 bw_inefficiency_factor, clk_inefficiency_factor, min_dram_ib;
};
struct dpu_core_perf { const struct dpu_perf_cfg *perf_cfg; };
struct dpu_core_perf_params { u64 bw_ctl, core_clk_rate; u32 max_per_pipe_ib; };

#define DPU_ERROR(...) ((void)0)
#define DRM_DEBUG_ATOMIC(...) ((void)0)
#define max(a,b) ((a) > (b) ? (a) : (b))
#define do_div(a,b) ((a) /= (b))
#define to_dpu_plane_state(s) ((struct dpu_plane_state *)(void *)(s))
#define drm_mode_vrefresh(m) ((m)->refresh)
#define for_each_if(c) if (!(c)) {} else
#define drm_for_each_plane_mask(p,d,m) \
	for (unsigned int cursor = 0; cursor < 4; cursor++) \
		for_each_if (((m) & (1U << cursor)) && (((p) = (d)->planes[cursor]), 1))
static struct drm_plane_state *
drm_atomic_get_new_plane_state(const struct drm_atomic_commit *state,
			      struct drm_plane *plane)
{
	return state->updates[plane->index];
}

/* Extracted unchanged from the prepared kernel, including fallback semantics. */
#include "atomic-current.inc"
#include "atomic-iterators.inc"
#include "dpu-callbacks.inc"

static unsigned int checked;
static void scenario(u32 old_mask, u32 new_mask, u32 update_mask, u32 factor)
{
	struct dpu_plane_state current[4] = {0}, incoming[4] = {0};
	struct drm_plane planes[4] = {0};
	struct drm_device dev = {0};
	struct drm_atomic_commit commit = { .dev = &dev };
	struct drm_crtc_state old = { .state = &commit, .plane_mask = old_mask };
	struct drm_crtc_state next = {
		.state = &commit, .plane_mask = new_mask,
		.adjusted_mode = { .vtotal = 1000, .hdisplay = 2000, .refresh = 60 },
	};
	struct drm_crtc crtc = { .dev = &dev, .state = &old };
	struct dpu_perf_cfg cfg = {
		.bw_inefficiency_factor = factor,
		.clk_inefficiency_factor = 105, .min_dram_ib = 800000,
	};
	struct dpu_core_perf perf = { .perf_cfg = &cfg };
	struct dpu_core_perf_params result = {0};
	u64 expected = 0;
	unsigned char old_bytes[sizeof(current)], new_bytes[sizeof(incoming)];

	for (unsigned int i = 0; i < 4; i++) {
		current[i].base.marker = 100 + i;
		incoming[i].base.marker = 200 + i;
		current[i].plane_fetch_bw = 1000000000ULL * (i + 1);
		incoming[i].plane_fetch_bw = 7000000000ULL + 101 * i;
		current[i].plane_clk = incoming[i].plane_clk = 100;
		planes[i].index = i;
		planes[i].state = &current[i].base;
		dev.planes[i] = &planes[i];
		if (update_mask & (1U << i)) commit.updates[i] = &incoming[i].base;
		if (new_mask & (1U << i))
			expected += update_mask & (1U << i) ?
				7000000000ULL + 101 * i : 1000000000ULL * (i + 1);
	}
	if (factor) expected = expected * factor / 100;
	memcpy(old_bytes, current, sizeof(current));
	memcpy(new_bytes, incoming, sizeof(incoming));
	_dpu_core_perf_calc_crtc(&perf, &crtc, &next, &result);
	assert(result.bw_ctl == expected);
	assert(result.max_per_pipe_ib == 800000);
	assert(result.core_clk_rate == 126000000);
	assert(crtc.state == &old && old.plane_mask == old_mask);
	assert(next.plane_mask == new_mask && next.state == &commit);
	assert(!memcmp(old_bytes, current, sizeof(current)));
	assert(!memcmp(new_bytes, incoming, sizeof(incoming)));
	for (unsigned int i = 0; i < 4; i++) assert(planes[i].state == &current[i].base);
	checked++;
}

int main(void)
{
	/* Resume/DPMS: committed state has no planes; incoming state does. */
	scenario(0, 1, 1, 120);
	/* Unchanged attached plane falls back to its current state. */
	scenario(1, 1, 0, 120);
	/* Add/remove overlay and update an attached plane independently. */
	scenario(1, 3, 2, 120);
	scenario(3, 1, 1, 120);
	scenario(1, 1, 1, 120);
	scenario(15, 0, 15, 120);
	for (u32 old_mask = 0; old_mask < 16; old_mask++)
		for (u32 new_mask = 0; new_mask < 16; new_mask++)
			for (u32 update_mask = 0; update_mask < 16; update_mask++) {
				scenario(old_mask, new_mask, update_mask, 120);
				scenario(old_mask, new_mask, update_mask, 0);
			}
	printf("Actual DPU callbacks/iterator: %u old/new/update-mask, fallback, 64-bit, factor and no-mutation cases passed; synthetic state only\n", checked);
	return 0;
}

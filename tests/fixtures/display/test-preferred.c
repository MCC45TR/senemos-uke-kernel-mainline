/* SPDX-License-Identifier: GPL-2.0-only */
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>

#define DRM_MODE_TYPE_DRIVER 0x40
#define DRM_MODE_TYPE_PREFERRED 0x08
#define ARRAY_SIZE(values) (sizeof(values) / sizeof((values)[0]))
#define container_of(ptr, type, member) ((type *)((char *)(ptr) - offsetof(type, member)))

struct drm_panel { int unused; };
struct drm_display_mode { int refresh, type; };
struct drm_connector {
	void *dev;
	struct { int bpc, width_mm, height_mm; } display_info;
	struct drm_display_mode modes[7];
	unsigned int count;
};
struct o82_profile { int unused; };
struct o82_panel {
	struct drm_panel panel;
	struct drm_connector *connector;
	const struct o82_profile *profiles;
	bool initial_60hz_only, initial_120hz_only, oem_refresh_modes;
	void *dsi[2];
};

static const struct o82_profile o82_42_02_0b_profiles[1];
static const struct o82_profile o82_36_02_0a_profiles[1];
static const struct { struct drm_display_mode mode; } o82_modes[] = {
	{{120, 0}}, {{144, 0}}, {{90, 0}}, {{60, 0}},
	{{50, 0}}, {{48, 0}}, {{30, 0}},
};

static int drm_mode_vrefresh(const struct drm_display_mode *mode)
{
	return mode->refresh;
}

static struct drm_display_mode *drm_mode_duplicate(void *dev,
					const struct drm_display_mode *mode)
{
	static struct drm_display_mode copy;

	(void)dev;
	copy = *mode;
	return &copy;
}

static void drm_mode_set_name(struct drm_display_mode *mode) { (void)mode; }

static void drm_mode_probed_add(struct drm_connector *connector,
			       struct drm_display_mode *mode)
{
	assert(connector->count < ARRAY_SIZE(connector->modes));
	connector->modes[connector->count++] = *mode;
}

static void qcom_uke_dsi_update_vrr(void *dsi, struct drm_connector *connector)
{
	(void)dsi;
	assert(connector->count);
}

#include "preferred-modes.inc"

static void check(struct o82_panel panel, unsigned int count, int expected)
{
	struct drm_connector connector = {};
	unsigned int preferred = 0;

	assert(o82_get_modes(&panel.panel, &connector) == (int)count);
	assert(connector.count == count);
	for (unsigned int i = 0; i < connector.count; i++) {
		const struct drm_display_mode *mode = &connector.modes[i];

		assert(mode->type & DRM_MODE_TYPE_DRIVER);
		if (mode->type & DRM_MODE_TYPE_PREFERRED) {
			assert(mode->refresh == expected);
			preferred++;
		}
	}
	assert(preferred == 1);
	assert(connector.display_info.bpc == 10);
}

int main(void)
{
	check((struct o82_panel){.profiles = o82_42_02_0b_profiles,
				 .oem_refresh_modes = true}, 7, 144);
	check((struct o82_panel){.profiles = o82_36_02_0a_profiles,
				 .oem_refresh_modes = true}, 7, 60);
	check((struct o82_panel){.profiles = o82_42_02_0b_profiles,
				 .initial_120hz_only = true}, 1, 120);
	check((struct o82_panel){.profiles = o82_42_02_0b_profiles,
				 .initial_60hz_only = true}, 1, 60);
	check((struct o82_panel){.profiles = o82_42_02_0b_profiles}, 7, 60);
	puts("Native O82 preferred mode and five fitted profile cases passed.");
}

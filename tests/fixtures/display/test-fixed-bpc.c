#include <assert.h>
#include <stdint.h>
#include <stdio.h>

enum { DRM_MODE_CONNECTOR_DSI = 16, DRM_MODE_CONNECTOR_DisplayPort = 10 };
struct drm_property { unsigned num_values; uint64_t values[2]; };
struct drm_connector_state { unsigned max_requested_bpc, max_bpc; };
struct drm_bridge_connector { unsigned bridge_hdmi; };
struct drm_connector {
	const struct drm_property *max_bpc_property;
	unsigned connector_type;
	struct drm_bridge_connector bridge;
};
static struct drm_connector_state fresh;
static struct drm_connector_state err;
static int allocation_fails;
static int hdmi_init_calls;
#define IS_ERR(state) ((state) == &err)

static struct drm_bridge_connector *to_drm_bridge_connector(struct drm_connector *connector)
{
	return &connector->bridge;
}

static struct drm_connector_state *
drm_atomic_helper_connector_create_state(struct drm_connector *connector)
{
	assert(connector);
	fresh = (struct drm_connector_state){ 0 };
	return allocation_fails ? &err : &fresh;
}

static void __drm_atomic_helper_connector_hdmi_state_init(
	struct drm_connector *connector, struct drm_connector_state *state)
{
	assert(connector->bridge.bridge_hdmi);
	assert(!state->max_requested_bpc && !state->max_bpc);
	hdmi_init_calls++;
}

#include "create-state.inc"

int main(void)
{
	const struct drm_property fixed10 = { 2, { 10, 10 } };
	const struct drm_property fixed8 = { 2, { 8, 8 } };
	const struct drm_property variable = { 2, { 8, 10 } };
	const struct drm_property malformed = { 1, { 10, 10 } };
	struct drm_connector connector = { &fixed10, DRM_MODE_CONNECTOR_DSI, { 0 } };
	struct drm_connector_state *state;

	state = drm_bridge_connector_create_state(&connector);
	assert(state->max_requested_bpc == 10 && state->max_bpc == 10);
	state->max_requested_bpc = 0;
	state = drm_bridge_connector_create_state(&connector);
	assert(state->max_requested_bpc == 10 && state->max_bpc == 10);

	connector.max_bpc_property = &fixed8;
	state = drm_bridge_connector_create_state(&connector);
	assert(state->max_requested_bpc == 8 && state->max_bpc == 8);

	connector.max_bpc_property = &variable;
	state = drm_bridge_connector_create_state(&connector);
	assert(!state->max_requested_bpc && !state->max_bpc);

	connector.max_bpc_property = &malformed;
	state = drm_bridge_connector_create_state(&connector);
	assert(!state->max_requested_bpc && !state->max_bpc);

	connector.max_bpc_property = NULL;
	state = drm_bridge_connector_create_state(&connector);
	assert(!state->max_requested_bpc && !state->max_bpc);

	connector.max_bpc_property = &fixed10;
	connector.connector_type = DRM_MODE_CONNECTOR_DisplayPort;
	state = drm_bridge_connector_create_state(&connector);
	assert(!state->max_requested_bpc && !state->max_bpc);

	connector.bridge.bridge_hdmi = 1;
	state = drm_bridge_connector_create_state(&connector);
	assert(!state->max_requested_bpc && !state->max_bpc && hdmi_init_calls == 1);

	allocation_fails = 1;
	assert(drm_bridge_connector_create_state(&connector) == &err);
	assert(hdmi_init_calls == 1);
	puts("Eight fixed-DSI state creation, reset and preservation cases passed.");
}

/* SPDX-License-Identifier: GPL-2.0-or-later */
#include <assert.h>
#include <stdbool.h>
#include <string.h>
#include "../src/input/nt36532-uke-protocol.h"
#define MT_TOOL_FINGER 0
struct input_dev {
	bool active[10], seen[10];
	u16 x[10], y[10];
	unsigned int slot, frames, syncs;
};
struct touchscreen_properties { u16 max_x, max_y; };
struct spi_device { int dev; };
struct nvt_uke_touch {
	struct input_dev *wake_input;
	struct touchscreen_properties prop;
	struct spi_device *spi;
	u8 *frame;
	unsigned long long input_packets, input_errors;
	u16 contacts_active;
};
static unsigned int warnings;
#define dev_warn_ratelimited(...) do { warnings++; } while (0)
static void input_mt_slot(struct input_dev *input, unsigned int slot)
{
	assert(slot < 10); input->slot = slot;
}
static void input_mt_report_slot_state(struct input_dev *input, int tool, bool active)
{
	assert(tool == MT_TOOL_FINGER);
	input->active[input->slot] = active;
	input->seen[input->slot] = active;
}
static void touchscreen_report_pos(struct input_dev *input,
	const struct touchscreen_properties *prop, u16 x, u16 y, bool mt)
{
	assert(mt && x <= prop->max_x && y <= prop->max_y);
	input->x[input->slot] = x; input->y[input->slot] = y;
}
static void input_mt_sync_frame(struct input_dev *input)
{
	for (unsigned int i = 0; i < 10; i++) {
		if (!input->seen[i]) input->active[i] = false;
		input->seen[i] = false;
	}
	input->frames++;
}
static void input_sync(struct input_dev *input) { input->syncs++; }
#include "production-contacts.h"
static void checksum(u8 *packet)
{
	unsigned int sum = 0;
	for (unsigned int i = 0; i < 64; i++) sum += packet[i];
	packet[64] = (u8)-sum;
}
int main(void)
{
	u8 packet[65];
	struct input_dev input = { 0 };
	struct nvt_uke_touch touch = {
		.wake_input = &input, .prop = { 3199, 2135 }, .frame = packet,
	};
	memset(packet, 0xff, sizeof(packet)); checksum(packet);
	nvt_publish_contacts(&touch, 0);
	assert(touch.input_packets == 1 && !touch.contacts_active && input.syncs == 1);
	packet[0] = 1 << 3 | 1; packet[1] = 10; packet[2] = 20; packet[3] = 0x34;
	packet[6] = 10 << 3 | 2; packet[7] = 30; packet[8] = 40; packet[9] = 0x56;
	checksum(packet); nvt_publish_contacts(&touch, 0);
	assert(touch.contacts_active == 0x201 && input.active[0] && input.active[9]);
	assert(input.x[0] == 163 && input.y[0] == 324);
	assert(input.x[9] == 485 && input.y[9] == 646);
	packet[0] = 0xff; checksum(packet); nvt_publish_contacts(&touch, 0);
	assert(touch.contacts_active == 0x200 && !input.active[0] && input.active[9]);
	packet[64] ^= 1; nvt_publish_contacts(&touch, 0);
	assert(!touch.contacts_active && !input.active[9] && touch.input_errors == 1 && warnings == 1);
	packet[64] ^= 1; nvt_publish_contacts(&touch, 0);
	assert(input.active[9]);
	nvt_publish_contacts(&touch, -5);
	assert(!input.active[9] && touch.input_errors == 2 && warnings == 2);
	nvt_publish_contacts(&touch, 0); nvt_release_contacts(&touch);
	assert(!touch.contacts_active && !input.active[9]);
	assert(input.frames == input.syncs);
}

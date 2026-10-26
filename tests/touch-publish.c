/* SPDX-License-Identifier: GPL-2.0-or-later */
#include <assert.h>
#include <stdbool.h>
#include <string.h>
#include "../src/input/nt36532-uke-matrix.h"
#define MT_TOOL_FINGER 0
#define msecs_to_jiffies(ms) (ms)
#define time_after(a,b) ((long)((b)-(a)) < 0)
static unsigned long jiffies = 1000;
struct input_mt_pos { int x, y; };
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
    struct nvt_uke_matrix matrix;
    u8 *frame;
    unsigned long last_valid;
    unsigned long long input_packets, input_errors;
    u16 contacts_active;
};
static unsigned int warnings;
static int decode_error, assign_error;
static struct nvt_uke_contacts decoded;
static int assigned[] = { 9, 2 };
#define dev_warn_ratelimited(...) do { warnings++; } while (0)
int nvt_uke_decode(const u8 *data, size_t size, struct nvt_uke_frame *frame)
{
    assert(data && size == NVT_UKE_FRAME_SIZE);memset(frame, 0, sizeof(*frame));return decode_error;
}
int nvt_uke_matrix_process(struct nvt_uke_matrix *matrix, const struct nvt_uke_frame *frame,
    u16 max_x, u16 max_y, struct nvt_uke_contacts *contacts)
{
    assert(matrix && frame && max_x == 31999 && max_y == 21359);*contacts = decoded;return 0;
}
static int input_mt_assign_slots(struct input_dev *input, int *slots,
    const struct input_mt_pos *positions, unsigned int count, unsigned int distance)
{
    assert(input && count <= 2 && distance == 3199);
    for (unsigned int i = 0; i < count; i++) {
        assert(positions[i].x == decoded.x[i] && positions[i].y == decoded.y[i]);slots[i] = assigned[i];
    }
    return assign_error;
}
static void input_mt_slot(struct input_dev *input, unsigned int slot)
{
    assert(slot < 10);input->slot = slot;
}
static void input_mt_report_slot_state(struct input_dev *input, int tool, bool active)
{
    assert(tool == MT_TOOL_FINGER);input->active[input->slot] = active;input->seen[input->slot] = active;
}
static void touchscreen_report_pos(struct input_dev *input,
    const struct touchscreen_properties *prop, int x, int y, bool mt)
{
    assert(mt && x >= 0 && y >= 0 && x <= prop->max_x && y <= prop->max_y);
    input->x[input->slot] = (u16)x;input->y[input->slot] = (u16)y;
}
static void input_mt_sync_frame(struct input_dev *input)
{
    for (unsigned int i = 0; i < 10; i++) {
        if (!input->seen[i])input->active[i] = false;
        input->seen[i] = false;
    }
    input->frames++;
}
static void input_sync(struct input_dev *input) { input->syncs++; }
#include "production-contacts.h"
int main(void)
{
    u8 packet[NVT_UKE_FRAME_SIZE] = { 0 };
    struct input_dev input = { 0 };
    struct nvt_uke_touch touch = { .wake_input = &input, .prop = {31999,21359}, .frame = packet };
    nvt_publish_contacts(&touch, 0);
    assert(touch.input_packets == 1 && !touch.contacts_active && input.syncs == 1);
    decoded = (struct nvt_uke_contacts) { .active=3, .x={1000,2000}, .y={3000,4000} };
    nvt_publish_contacts(&touch, 0);
    assert(touch.contacts_active == 0x204 && input.active[9] && input.active[2]);
    assert(input.x[9] == 1000 && input.y[2] == 4000);
    decoded.active = 1;nvt_publish_contacts(&touch, 0);
    assert(touch.contacts_active == 0x200 && input.active[9] && !input.active[2]);
    decode_error = -5;jiffies += 50;nvt_publish_contacts(&touch, 0);
    assert(input.active[9] && touch.input_errors == 1);
    jiffies += 51;nvt_publish_contacts(&touch, 0);
    assert(!input.active[9] && !touch.contacts_active && warnings == 2);
    decode_error = 0;nvt_publish_contacts(&touch, 0);assert(input.active[9]);
    assign_error = -5;nvt_publish_contacts(&touch, 0);assert(!input.active[9]);
    assign_error = 0;nvt_publish_contacts(&touch, 0);nvt_release_contacts(&touch);
    assert(!input.active[9] && !touch.contacts_active);
    assigned[0] = -1;nvt_publish_contacts(&touch, 0);assert(!touch.contacts_active);
}

// SPDX-License-Identifier: GPL-2.0-or-later
/* Integer matrix processing for the measured Uke CSOT THP format.
 * Uses a live startup baseline, local ascent and weighted electrode positions.
 * No userspace contact-core source or device-private reference is embedded.
 */
#include <linux/errno.h>
#include <linux/string.h>
#include <linux/unaligned.h>
#include "nt36532-uke-matrix.h"

#define NVT_NO_PARENT 0xffff

void nvt_uke_matrix_reset(struct nvt_uke_matrix *m)
{
	memset(m->reference, 0, sizeof(m->reference));
	m->samples = 0;
	m->quiet = 0;
	m->previous_count = 0;
	m->pending_count = 0;
	m->counter_valid = false;
}

static unsigned int nvt_distance(unsigned int a, unsigned int b)
{
	int x = (int)(a % NVT_UKE_COLUMNS) - (int)(b % NVT_UKE_COLUMNS);
	int y = (int)(a / NVT_UKE_COLUMNS) - (int)(b / NVT_UKE_COLUMNS);

	return (unsigned int)(x * x + y * y);
}

static bool nvt_confirmed(const struct nvt_uke_matrix *m, const u16 *roots,
			 unsigned int count, unsigned int index, u16 down)
{
	unsigned int i, distance, best = 9, previous = m->previous_count;

	for (i = 0; i < m->previous_count; i++) {
		distance = nvt_distance(roots[index], m->previous_roots[i]);
		if (distance < best) {
			best = distance;
			previous = i;
		}
	}
	if (previous == m->previous_count)
		return false;
	/* One old peak cannot confirm both sides of a transient split. */
	for (i = 0; i < count; i++) {
		if (!(down & (1U << i)) || i == index)
			continue;
		distance = nvt_distance(roots[i], m->previous_roots[previous]);
		if (distance < best || (distance == best && i < index))
			return false;
	}
	return true;
}

static unsigned int nvt_root(struct nvt_uke_matrix *m, unsigned int node)
{
	unsigned int root = node, next;

	while (m->parent[root] != root)
		root = m->parent[root];
	while (m->parent[node] != node) {
		next = m->parent[node];
		m->parent[node] = (u16)root;
		node = next;
	}
	return root;
}

static u16 nvt_axis(u64 weighted, u32 weight, const u32 *map,
		    unsigned int count, u16 maximum)
{
	u32 value = (u32)(weighted / weight);

	/* Extend the outer electrode centres to the active surface edges. */
	if (value <= map[0])
		return 0;
	if (value >= map[count - 1])
		return maximum;
	return (u16)(((u64)(value - map[0]) * maximum) /
		     (map[count - 1] - map[0]));
}

int nvt_uke_matrix_process(struct nvt_uke_matrix *m,
	const struct nvt_uke_frame *frame, u16 max_x, u16 max_y,
	struct nvt_uke_contacts *contacts)
{
	struct {
		u64 x, y;
		u32 weight;
		unsigned int root, nodes;
	} blobs[NVT_UKE_CONTACTS] = { 0 };
	unsigned int node, other, root, count = 0, output = 0, i;
	unsigned int noise, up, down, total, bin, magnitude;
	u16 histogram[32] = { 0 }, roots[NVT_UKE_CONTACTS], starting = 0;
	bool fresh;
	int dx, dy, row, column, next_row, next_column, top = 0, bottom = 0;
	s32 value, best;

	if (!m || !frame || !frame->matrix_le || !contacts || !max_x || !max_y ||
	    (frame->scan_mode != 2 && frame->scan_mode != 4))
		return -EINVAL;
	memset(contacts, 0, sizeof(*contacts));
	for (node = 0; node < NVT_UKE_COLUMNS; node++)
		if (m->columns[node] > max_x ||
		    (node && m->columns[node] <= m->columns[node - 1]))
			return -EINVAL;
	for (node = 0; node < NVT_UKE_ROWS; node++)
		if (m->rows[node] > max_y ||
		    (node && m->rows[node] <= m->rows[node - 1]))
			return -EINVAL;
	fresh = !m->counter_valid || m->counter != frame->counter;
	if (fresh) {
		if (m->counter_valid && (u16)(frame->counter - m->counter) > 4)
			m->pending_count = 0;
		m->previous_count = m->pending_count;
		memcpy(m->previous_roots, m->pending_roots, sizeof(m->previous_roots));
		m->counter = frame->counter;
		m->counter_valid = true;
	}
	if (m->samples < NVT_UKE_CALIBRATION_FRAMES) {
		if (!fresh)
			return 0;
		for (node = 0; node < NVT_UKE_NODES; node++)
			m->reference[node] += (s16)get_unaligned_le16(frame->matrix_le + node * 2);
		m->samples++;
		/* The sum of 32 frames is the baseline in Q5 units. */
		return 0;
	}
	for (node = 0; node < NVT_UKE_NODES; node++) {
		value = (s16)get_unaligned_le16(frame->matrix_le + node * 2);
		m->delta[node] = value - m->reference[node] / 32;
		if (m->delta[node] > top)
			top = m->delta[node];
		if (m->delta[node] < bottom)
			bottom = m->delta[node];
		magnitude = (u32)(m->delta[node] < 0 ? -m->delta[node] : m->delta[node]);
		bin = magnitude / 4;
		if (bin > 31)
			bin = 31;
		histogram[bin]++;
		m->parent[node] = NVT_NO_PARENT;
	}
	/* Sparse fingers do not dominate the median absolute background signal. */
	for (bin = 0, total = 0; bin < 32; bin++) {
		total += histogram[bin];
		if (total > NVT_UKE_NODES / 2)
			break;
	}
	m->pending_count = 0;
	if (bin == 31) {
		m->quiet = 0;
		return 0;
	}
	noise = (bin + 1) * 12;
	if (noise < NVT_UKE_NOISE_FLOOR)
		noise = NVT_UKE_NOISE_FLOOR;
	up = noise * 2;
	down = noise * 5 / 2;
	for (node = 0; node < NVT_UKE_NODES; node++) {
		if (m->delta[node] < (s32)noise)
			continue;
		row = (int)(node / NVT_UKE_COLUMNS);
		column = (int)(node % NVT_UKE_COLUMNS);
		root = node;
		best = m->delta[node];
		for (dy = -1; dy <= 1; dy++) {
			next_row = row + dy;
			if (next_row < 0 || next_row >= NVT_UKE_ROWS)
				continue;
			for (dx = -1; dx <= 1; dx++) {
				next_column = column + dx;
				if (next_column < 0 || next_column >= NVT_UKE_COLUMNS)
					continue;
				other = (unsigned int)(next_row * NVT_UKE_COLUMNS + next_column);
				if (m->delta[other] > best ||
				    (m->delta[other] == best && other < root)) {
					root = other;
					best = m->delta[other];
				}
			}
		}
		m->parent[node] = (u16)root;
		if (root == node && best >= (s32)up) {
			/* A broad/noisy frame must not become truncated phantom fingers. */
			if (count == NVT_UKE_CONTACTS) {
				m->quiet = 0;
				return 0;
			}
			blobs[count++].root = root;
		}
	}
	for (node = 0; node < NVT_UKE_NODES; node++) {
		if (m->parent[node] == NVT_NO_PARENT)
			continue;
		root = nvt_root(m, node);
		for (i = 0; i < count; i++) {
			if (blobs[i].root != root)
				continue;
			value = m->delta[node] - (s32)noise + 1;
			blobs[i].nodes++;
			blobs[i].weight += (u32)value;
			blobs[i].x += (u64)value * m->columns[node % NVT_UKE_COLUMNS];
			blobs[i].y += (u64)value * m->rows[node / NVT_UKE_COLUMNS];
			break;
		}
	}
	for (i = 0; i < count; i++) {
		if (blobs[i].nodes < 2 || blobs[i].nodes > 80)
			continue;
		contacts->x[output] = nvt_axis(blobs[i].x, blobs[i].weight,
			m->columns, NVT_UKE_COLUMNS, max_x);
		contacts->y[output] = nvt_axis(blobs[i].y, blobs[i].weight,
			m->rows, NVT_UKE_ROWS, max_y);
		contacts->peak[output] = (u16)m->delta[blobs[i].root];
		roots[output] = (u16)blobs[i].root;
		if (contacts->peak[output] >= down) {
			starting |= (u16)(1U << output);
			m->pending_roots[m->pending_count++] = roots[output];
		}
		contacts->active |= (u16)(1U << output++);
	}
	for (i = 0; i < output; i++)
		if ((starting & (1U << i)) && nvt_confirmed(m, roots, output, i, starting))
			contacts->starting |= (u16)(1U << i);
	/* Adapt only after a sustained quiet interval; held fingers keep their baseline. */
	if (!fresh)
		return 0;
	if (top < NVT_UKE_NOISE_FLOOR * 2 && bottom > -NVT_UKE_NOISE_FLOOR * 2 && !contacts->active) {
		if (m->quiet < 64)
			m->quiet++;
		if (m->quiet == 64)
			for (node = 0; node < NVT_UKE_NODES; node++) {
				value = (s16)get_unaligned_le16(frame->matrix_le + node * 2);
				m->reference[node] += (value * 32 - m->reference[node]) / 64;
			}
	} else {
		m->quiet = 0;
	}
	return 0;
}

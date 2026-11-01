/* SPDX-License-Identifier: GPL-2.0-or-later */
#ifndef NT36532_UKE_MATRIX_H
#define NT36532_UKE_MATRIX_H

#include "nt36532-uke-protocol.h"

#define NVT_UKE_ROWS 40
#define NVT_UKE_COLUMNS 60
#define NVT_UKE_CALIBRATION_FRAMES 32
#define NVT_UKE_NOISE_FLOOR 25

struct nvt_uke_matrix {
	s32 reference[NVT_UKE_NODES], delta[NVT_UKE_NODES];
	u16 parent[NVT_UKE_NODES];
	u32 columns[NVT_UKE_COLUMNS], rows[NVT_UKE_ROWS];
	unsigned int samples, quiet;
	u16 previous_roots[NVT_UKE_CONTACTS], pending_roots[NVT_UKE_CONTACTS];
	unsigned int previous_count, pending_count;
	u16 counter;
	bool counter_valid;
};

void nvt_uke_matrix_reset(struct nvt_uke_matrix *matrix);
int nvt_uke_matrix_process(struct nvt_uke_matrix *matrix,
	const struct nvt_uke_frame *frame, u16 max_x, u16 max_y,
	struct nvt_uke_contacts *contacts);

#endif

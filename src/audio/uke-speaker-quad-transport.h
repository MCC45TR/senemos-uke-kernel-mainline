/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef UKE_SPEAKER_QUAD_TRANSPORT_H
#define UKE_SPEAKER_QUAD_TRANSPORT_H
struct q6apm_graph;
struct audioreach_module;

int audioreach_uke_quad_matrix(struct q6apm_graph *graph,
			      const struct audioreach_module *module,
			      const unsigned int *map);
int audioreach_uke_surround_matrix(struct q6apm_graph *graph,
				  const struct audioreach_module *module,
				  const unsigned int *map);
#endif

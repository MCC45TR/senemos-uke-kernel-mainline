/* SPDX-License-Identifier: GPL-2.0-only */
/* Included by audioreach.c, within the existing snd-q6apm composite. */
#include "uke-speaker-quad.h"
#include "uke-speaker-quad-wire.h"
#include "uke-speaker-quad-transport.h"

int audioreach_uke_quad_matrix(struct q6apm_graph *graph,
			      const struct audioreach_module *module,
			      const unsigned int *map)
{
	return uke_quad_send_matrix(graph, module, map);
}
EXPORT_SYMBOL_GPL(audioreach_uke_quad_matrix);

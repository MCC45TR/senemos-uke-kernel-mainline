/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef UKE_FS19XX_RUNTIME_H
#define UKE_FS19XX_RUNTIME_H
struct q6apm;
struct q6apm_graph;
struct audioreach_graph;
struct snd_soc_component;
int q6apm_fs19xx_init(struct q6apm *apm);
int q6apm_fs19xx_controls(struct snd_soc_component *component);
int q6apm_fs19xx_claim(struct audioreach_graph *graph);
void q6apm_fs19xx_quiesce(struct audioreach_graph *graph);
void q6apm_fs19xx_release(struct audioreach_graph *graph);
int q6apm_fs19xx_prepare(struct q6apm_graph *graph);
int q6apm_fs19xx_prepared(struct q6apm_graph *graph);
int q6apm_fs19xx_started(struct q6apm_graph *graph);
void q6apm_fs19xx_stopped(struct q6apm_graph *graph, bool failed);
void q6apm_fs19xx_shutdown(struct q6apm *apm);
bool q6apm_fs19xx_graph(struct q6apm_graph *graph);
#endif

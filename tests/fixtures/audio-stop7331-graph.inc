/* SPDX-License-Identifier: GPL-2.0-only */
/* Exact qualified7331 runtime d9bf7898 and STOP e6569ecf functions, unmodified. */
int q6apm_graph_stop(struct q6apm_graph *graph)
{
	struct audioreach_graph *ar_graph = graph->ar_graph;
	int ret, mute_ret;

	if (ar_graph->start_count == 0)
		return 0;

	if (--ar_graph->start_count > 0)
		return 0;

	mute_ret = q6apm_fs19xx_stopping(graph);
	ret = audioreach_graph_mgmt_cmd(ar_graph, APM_CMD_GRAPH_STOP);
	q6apm_fs19xx_stopped(graph, mute_ret || ret);
	return mute_ret ? mute_ret : ret;
}

/* SPDX-License-Identifier: GPL-2.0-only */
/* Exact qualified7331 runtime d9bf7898 and STOP e6569ecf functions, unmodified. */
static int fs19xx_gate(unsigned int mode)
{
	unsigned long flags;
	int ret = 0;

	guard(mutex)(&fs19xx_listeners_lock);
	if (mode && fs19xx_positions != 15)
		return -ENODEV;
	spin_lock_irqsave(&fs19xx_guard_lock, flags);
	ret = uke_fs_guard_mode(&fs19xx_guard, mode);
	spin_unlock_irqrestore(&fs19xx_guard_lock, flags);
	if (ret)
		return ret;
	ret = notifier_to_errno(blocking_notifier_call_chain(&fs19xx_listeners, mode, NULL));
	spin_lock_irqsave(&fs19xx_guard_lock, flags);
	if (mode && (!uke_fs_guard_configured(&fs19xx_guard) || fs19xx_guard.mode != mode))
		ret = -EIO;
	if (ret) {
		uke_fs_guard_trip(&fs19xx_guard);
	}
	spin_unlock_irqrestore(&fs19xx_guard_lock, flags);
	if (ret)
		blocking_notifier_call_chain(&fs19xx_listeners, 0, NULL);
	return ret;
}

bool q6apm_fs19xx_graph(struct q6apm_graph *graph)
{
	return graph->apm->fs19xx && graph->apm->fs19xx->admitted && graph->id == 40;
}

int q6apm_fs19xx_stopping(struct q6apm_graph *graph)
{
	struct q6apm_fs19xx *fs = graph->apm->fs19xx;
	int ret;

	if (!q6apm_fs19xx_graph(graph)) return 0;
	guard(mutex)(&fs->lock);
	if (fs->removing || fs->owner != graph->ar_graph ||
	    (fs->data.status != UKE_FS_RUNNING && fs->data.status != UKE_FS_PREPARED))
		return -ENODATA;
	/* Read-back DAC mute on every amplifier; retain VI until DSP STOP replies. */
	ret = fs19xx_gate(1);
	if (ret) {
		/* Also cover admission refusals before the notifier chain ran. */
		fs19xx_gate(0);
		uke_fs19xx_erase(&fs->data);
		fs->data.status = UKE_FS_FAULT;
	}
	return ret;
}

void q6apm_fs19xx_stopped(struct q6apm_graph *graph, bool failed)
{
	struct q6apm_fs19xx *fs = graph->apm->fs19xx;
	if (!q6apm_fs19xx_graph(graph)) return;
	guard(mutex)(&fs->lock);
	fs19xx_gate(0);
	if (failed) {
		uke_fs19xx_erase(&fs->data);
		fs->data.status = UKE_FS_FAULT;
	} else if (fs->data.status == UKE_FS_RUNNING) {
		fs->data.status = UKE_FS_PREPARED;
	}
}

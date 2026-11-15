/* SPDX-License-Identifier: GPL-2.0-only */
/* Exact qualified7331 runtime d9bf7898 and STOP e6569ecf functions, unmodified. */
bool q6apm_fs19xx_output_fault(void)
{
	unsigned long flags;

	spin_lock_irqsave(&fs19xx_guard_lock, flags);
	if (!fs19xx_guard.faulted && fs19xx_guard.mode == 0) {
		spin_unlock_irqrestore(&fs19xx_guard_lock, flags);
		return false;
	}
	uke_fs_guard_trip(&fs19xx_guard);
	spin_unlock_irqrestore(&fs19xx_guard_lock, flags);
	queue_work(system_highpri_wq, &fs19xx_fault_work);
	return true;
}

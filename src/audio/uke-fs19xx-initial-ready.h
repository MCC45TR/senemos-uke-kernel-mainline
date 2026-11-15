/* SPDX-License-Identifier: GPL-2.0-only */
/* One bounded initial wait, before graph OPEN and ID publication. */
static bool fs19xx_initial_pending(unsigned int state)
{
	return state == UKE_FS_EMPTY || state == UKE_FS_STAGING;
}

static int fs19xx_wait_initial_ready(struct q6apm_fs19xx *fs)
{
	unsigned long remaining;
	unsigned int state;

	for (;;) {
		mutex_lock(&fs->lock);
		state = fs->data.status;
		if (fs->removing || fs->owner ||
		    (!fs19xx_initial_pending(state) && state != UKE_FS_READY)) {
			mutex_unlock(&fs->lock);
			return -ENODATA;
		}
		if (state == UKE_FS_READY) {
			mutex_unlock(&fs->lock);
			return 0;
		}
		if (!fs->ready_wait_started) {
			fs->ready_wait_started = true;
			fs->ready_deadline = jiffies + msecs_to_jiffies(2000);
		}
		if (time_after_eq(jiffies, fs->ready_deadline)) {
			mutex_unlock(&fs->lock);
			return -ENODATA;
		}
		remaining = fs->ready_deadline - jiffies;
		mutex_unlock(&fs->lock);
		/* Provisioning needs this mutex; never wait while holding it. */
		if (!wait_event_timeout(fs->ready_wait,
			READ_ONCE(fs->removing) || READ_ONCE(fs->owner) ||
			!fs19xx_initial_pending(READ_ONCE(fs->data.status)), remaining))
			return -ENODATA;
	}
}

/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef UKE_FS19XX_SAFETY_H
#define UKE_FS19XX_SAFETY_H
#ifdef __KERNEL__
#include <linux/types.h>
#include <linux/errno.h>
typedef u64 uke_fs_generation;
#else
#include <stdint.h>
#include <stdbool.h>
#include <errno.h>
typedef uint64_t uke_fs_generation;
#endif

/* Every access, including observations, is serialized by the caller's lock. */
struct uke_fs_guard {
	uke_fs_generation generation;
	unsigned int mode;
	bool faulted;
};

static inline bool uke_fs_guard_configured(const struct uke_fs_guard *guard)
{
	return !guard->faulted && guard->mode >= 1;
}

static inline bool uke_fs_guard_running(const struct uke_fs_guard *guard)
{
	return !guard->faulted && guard->mode == 2;
}

static inline void uke_fs_guard_trip(struct uke_fs_guard *guard)
{
	guard->generation++;
	guard->faulted = true;
	guard->mode = 0;
}

static inline int uke_fs_guard_mode(struct uke_fs_guard *guard, unsigned int mode)
{
	if (mode > 2)
		return -EINVAL;
	if (mode && guard->faulted)
		return -EIO;
	guard->mode = mode;
	return 0;
}

/* A complete transaction cannot erase a fault that occurred after BEGIN. */
static inline int uke_fs_guard_reprovision(struct uke_fs_guard *guard,
					 uke_fs_generation generation)
{
	if (guard->mode || guard->generation != generation)
		return -EAGAIN;
	guard->faulted = false;
	return 0;
}
#endif

/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef UKE_FS19XX_GUARD_H
#define UKE_FS19XX_GUARD_H
#include <linux/errno.h>
#include <linux/kconfig.h>
#include <linux/notifier.h>

/* Only the explicit protected DT profile registers amplifier listeners. */
#if IS_REACHABLE(CONFIG_SND_SOC_QDSP6_APM)
int q6apm_fs19xx_register(struct notifier_block *listener, unsigned int position);
void q6apm_fs19xx_unregister(struct notifier_block *listener, unsigned int position);
bool q6apm_fs19xx_configured(void);
bool q6apm_fs19xx_running(void);
#else
static inline int q6apm_fs19xx_register(struct notifier_block *n, unsigned int p)
{ return -EOPNOTSUPP; }
static inline void q6apm_fs19xx_unregister(struct notifier_block *n, unsigned int p) {}
static inline bool q6apm_fs19xx_configured(void) { return false; }
static inline bool q6apm_fs19xx_running(void) { return false; }
#endif
#endif

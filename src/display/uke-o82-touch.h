/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef UKE_O82_TOUCH_H
#define UKE_O82_TOUCH_H

struct drm_panel;
struct notifier_block;

/* The synchronous callback receives a u64 generation/ready pair. It must not
 * call back into the panel. Registration also delivers the current state.
 */
int uke_o82_touch_register(struct drm_panel *panel, struct notifier_block *nb);
void uke_o82_touch_unregister(struct drm_panel *panel, struct notifier_block *nb);

#endif

/* SPDX-License-Identifier: GPL-2.0-only */
/* Legacy callback fixtures keep DT protection disabled. Actual protected codec
 * and protocol behavior is exercised by audio-speaker-safety-contract.sh. */
#ifndef UKE_AUDIO_PROTECTION_MOCK_H
#define UKE_AUDIO_PROTECTION_MOCK_H
#include <stdbool.h>
struct q6apm;
struct q6apm_graph;
struct audioreach_graph;
struct snd_soc_component;
struct notifier_block { int (*notifier_call)(struct notifier_block *, unsigned long, void *); };
#define UKE_FIXTURE_UNUSED __attribute__((unused))
static int UKE_FIXTURE_UNUSED legacy_claim_error;
static int UKE_FIXTURE_UNUSED q6apm_fs19xx_claim(struct audioreach_graph *p) { (void)p; return legacy_claim_error; }
static void UKE_FIXTURE_UNUSED q6apm_fs19xx_release(struct audioreach_graph *p) { (void)p; }
static void UKE_FIXTURE_UNUSED q6apm_fs19xx_quiesce(struct audioreach_graph *p) { (void)p; }
static void UKE_FIXTURE_UNUSED q6apm_fs19xx_shutdown(struct q6apm *p) { (void)p; }
static int UKE_FIXTURE_UNUSED q6apm_fs19xx_init(struct q6apm *p) { (void)p; return 0; }
static int UKE_FIXTURE_UNUSED q6apm_fs19xx_controls(struct snd_soc_component *p) { (void)p; return 0; }
static bool UKE_FIXTURE_UNUSED q6apm_fs19xx_configured(void) { return false; }
static bool UKE_FIXTURE_UNUSED q6apm_fs19xx_running(void) { return false; }
static void UKE_FIXTURE_UNUSED q6apm_fs19xx_fault(void) {}
static int UKE_FIXTURE_UNUSED q6apm_fs19xx_register(struct notifier_block *p, unsigned position) { (void)p;(void)position;return 0; }
static void UKE_FIXTURE_UNUSED q6apm_fs19xx_unregister(struct notifier_block *p, unsigned position) { (void)p;(void)position; }
#endif

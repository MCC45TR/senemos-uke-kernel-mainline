/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef UKE_AUDIO_CONFIG_MEMORY_H
#define UKE_AUDIO_CONFIG_MEMORY_H
#include <linux/dma-mapping.h>

/* One dedicated lease; its DMA context survives APM/PDR driver removal. */
struct uke_audio_config_memory {
	void *area;
	dma_addr_t dma;
	u64 dsp_address;
	u32 bytes;
	u32 first_token;
};

int uke_audio_config_acquire(struct device *apm,
			     struct uke_audio_config_memory *memory);
void uke_audio_config_release(struct uke_audio_config_memory *memory,
			      bool uncertain);
#endif

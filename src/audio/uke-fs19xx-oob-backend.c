// SPDX-License-Identifier: GPL-2.0-only
// Small independent APM control port; private tuning stays in dedicated RAM.
#include <linux/dma-mapping.h>
#include <linux/jiffies.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/spinlock.h>
#include <linux/wait.h>
#include <linux/soc/qcom/apr.h>
#include <linux/soc/qcom/uke-audio-config-memory.h>
#include "q6apm.h"
#include "uke-fs19xx-oob.h"
#include "uke-fs19xx-oob-backend.h"

#define UKE_OOB_MAP_REPLY 0x02001001
#define UKE_OOB_APM_PORT 1

struct uke_oob_client {
	spinlock_t lock;
	wait_queue_head_t wait;
	gpr_port_t *port;
	struct device *device;
	struct uke_audio_config_memory memory;
	struct uke_oob_buffer buffer;
	u32 port_id, token, command, next_token;
	bool pending, done, complete, retained;
	int error;
	u32 handle;
};

static int uke_oob_callback(const struct gpr_resp_pkt *reply, void *context, int op)
{
	struct uke_oob_client *client = context;
	const struct gpr_hdr *header;
	unsigned long flags;
	u32 response_command, status;
	bool wake = false;

	if (!reply || op)
		return 0;
	header = &reply->hdr;
	spin_lock_irqsave(&client->lock, flags);
	if (!client->pending || header->token != client->token ||
	    header->src_domain != GPR_DOMAIN_ID_ADSP ||
	    header->dest_domain != GPR_DOMAIN_ID_APPS ||
	    header->src_port != UKE_OOB_APM_PORT || header->dest_port != client->port_id)
		goto out;
	/* A matching but malformed reply is ambiguous, never a completion fence. */
	if (header->version != GPR_PKT_VER || header->reserved ||
	    header->hdr_size != GPR_PKT_HEADER_WORD_SIZE ||
	    reply->payload_size < 0 || !reply->payload ||
	    (size_t)header->pkt_size != GPR_HDR_SIZE + (size_t)reply->payload_size)
		goto malformed;
	if (header->opcode == GPR_BASIC_EVT_ACCEPTED && reply->payload_size == 4 &&
	    uke_oob_get32(reply->payload) == client->command)
		goto out;
	if (client->command == UKE_OOB_MAP && header->opcode == UKE_OOB_MAP_REPLY) {
		if (reply->payload_size != 4)
			goto malformed;
		client->handle = uke_oob_get32(reply->payload);
		if (!client->handle)
			goto malformed;
		client->error = 0;
	} else if (header->opcode == GPR_BASIC_RSP_RESULT && reply->payload_size == 8) {
		response_command = uke_oob_get32(reply->payload);
		status = uke_oob_get32((const u8 *)reply->payload + 4);
		if (response_command != client->command)
			goto malformed;
		/* A successful MAP BASIC_RSP carries no mapping handle. Wait for MAP_RSP. */
		if (client->command == UKE_OOB_MAP && !status)
			goto out;
		client->error = status ? -EREMOTEIO : 0;
	} else {
		goto malformed;
	}
	client->complete = true;
	goto finished;
malformed:
	client->complete = false;
	client->error = -EPROTO;
finished:
	client->pending = false;
	client->done = true;
	wake = true;
out:
	spin_unlock_irqrestore(&client->lock, flags);
	if (wake)
		wake_up(&client->wait);
	return 0;
}

static int uke_oob_allocate(void *context, struct uke_oob_buffer *buffer)
{
	struct uke_oob_client *client = context;
	int ret = uke_audio_config_acquire(client->device, &client->memory);

	if (ret)
		return ret;
	buffer->data = client->memory.area;
	buffer->address_low = lower_32_bits(client->memory.dsp_address);
	buffer->address_high = upper_32_bits(client->memory.dsp_address);
	buffer->bytes = client->memory.bytes;
	client->next_token = client->memory.first_token;
	return 0;
}

static struct uke_oob_reply uke_oob_command(void *context, u32 command,
					  const u8 *payload, size_t bytes)
{
	struct uke_oob_client *client = context;
	struct uke_oob_reply reply = { .error = -EINVAL };
	struct gpr_pkt *packet;
	unsigned long flags;
	size_t expected;
	int ret, packet_bytes;

	switch (command) {
	case UKE_OOB_MAP: expected = 20; break;
	case UKE_OOB_SET_CFG: expected = 16; break;
	case UKE_OOB_UNMAP: expected = 4; break;
	default: return reply;
	}
	if (bytes != expected || !payload ||
	    client->next_token < client->memory.first_token ||
	    client->next_token - client->memory.first_token >= 3)
		return reply;
	packet_bytes = GPR_HDR_SIZE + bytes;
	packet = kzalloc(packet_bytes, GFP_KERNEL);
	if (!packet) {
		reply.error = -ENOMEM;
		return reply;
	}
	packet->hdr.version = GPR_PKT_VER;
	packet->hdr.hdr_size = GPR_PKT_HEADER_WORD_SIZE;
	packet->hdr.pkt_size = packet_bytes;
	packet->hdr.src_domain = GPR_DOMAIN_ID_APPS;
	packet->hdr.dest_domain = GPR_DOMAIN_ID_ADSP;
	packet->hdr.src_port = client->port_id;
	packet->hdr.dest_port = UKE_OOB_APM_PORT;
	packet->hdr.token = client->next_token++;
	packet->hdr.opcode = command;
	memcpy(packet->payload, payload, bytes);
	spin_lock_irqsave(&client->lock, flags);
	client->token = packet->hdr.token;
	client->command = command;
	client->pending = true;
	client->done = false;
	client->complete = false;
	client->error = 0;
	client->handle = 0;
	spin_unlock_irqrestore(&client->lock, flags);
	dma_wmb();
	/* Even an error after a send attempt is conservatively ambiguous. No
	 * transport-specific assumption that an error proves nonpublication.
	 */
	reply.sent = true;
	ret = gpr_send_port_pkt(client->port, packet);
	kfree(packet);
	if (ret == packet_bytes)
		wait_event_timeout(client->wait, READ_ONCE(client->done), 5 * HZ);
	spin_lock_irqsave(&client->lock, flags);
	client->pending = false;
	if (ret != packet_bytes) {
		reply.error = ret < 0 ? ret : -EIO;
	} else if (!client->done) {
		reply.error = -ETIMEDOUT;
	} else {
		reply.complete = client->complete;
		reply.error = client->error;
		reply.handle = client->handle;
	}
	spin_unlock_irqrestore(&client->lock, flags);
	/* The DSP writes module status into shared coherent memory before reply. */
	if (reply.complete)
		dma_rmb();
	return reply;
}

static void uke_oob_erase(void *context, struct uke_oob_buffer *buffer)
{
	(void)context;
	if (buffer->data && buffer->bytes) {
		memzero_explicit(buffer->data, buffer->bytes);
		dma_wmb();
	}
}

static void uke_oob_release_memory(void *context, struct uke_oob_buffer *buffer)
{
	struct uke_oob_client *client = context;

	(void)buffer;
	uke_audio_config_release(&client->memory, false);
}

static void uke_oob_quarantine(void *context, struct uke_oob_buffer *buffer)
{
	struct uke_oob_client *client = context;

	(void)buffer;
	/* Preallocated client, port, module reference and permanent DMA supplier
	 * remain owned. No later unmap ACK or driver unbind releases these pages.
	 * Reboot is the initial bounded recovery; no callback touches APM state.
	 */
	client->retained = true;
	uke_audio_config_release(&client->memory, true);
}

static const struct uke_oob_ops uke_oob_native_ops = {
	.allocate = uke_oob_allocate,
	.command = uke_oob_command,
	.erase = uke_oob_erase,
	.release = uke_oob_release_memory,
	.quarantine = uke_oob_quarantine,
};

int q6apm_fs19xx_oob_ready(void)
{
	return uke_audio_config_ready();
}

/* Called with the existing FS19xx mutex held, before any amplifier unmute.
 * The native callback only uses its own lock/immutable identity, never that
 * mutex, a graph, calibration staging or removable APM driver data.
 */
int q6apm_fs19xx_oob_send(struct q6apm *apm, u32 instance, u32 parameter,
			 const u8 *data, size_t bytes)
{
	struct uke_oob_client *client;
	int ret;

	if (!apm || !data || instance != UKE_OOB_TUNING_IID ||
	    parameter != UKE_OOB_TUNING_PARAM || bytes != UKE_OOB_TUNING_BYTES)
		return -EINVAL;
	if (!try_module_get(THIS_MODULE))
		return -ENODEV;
	client = kzalloc(sizeof(*client), GFP_KERNEL);
	if (!client) {
		ret = -ENOMEM;
		goto put_module;
	}
	spin_lock_init(&client->lock);
	init_waitqueue_head(&client->wait);
	client->device = get_device(apm->dev);
	client->port = gpr_alloc_port(apm->gdev, client->device, uke_oob_callback, client);
	if (IS_ERR(client->port)) {
		ret = PTR_ERR(client->port);
		goto free_client;
	}
	client->port_id = client->port->id;
	ret = uke_fs19xx_oob_transfer(&client->buffer, &uke_oob_native_ops, client,
				     instance, parameter, data, bytes);
	if (client->retained)
		return ret;
	/* Complete callback drain precedes freeing the independent client. */
	gpr_free_port(client->port);
free_client:
	put_device(client->device);
	kfree_sensitive(client);
put_module:
	module_put(THIS_MODULE);
	return ret;
}

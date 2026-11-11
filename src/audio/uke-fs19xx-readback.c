// SPDX-License-Identifier: GPL-2.0-only
// Read two fixed enable parameters, without shared memory or configuration writes.
#include <linux/atomic.h>
#include <linux/device.h>
#include <linux/jiffies.h>
#include <linux/slab.h>
#include <linux/spinlock.h>
#include <linux/wait.h>
#include <linux/soc/qcom/apr.h>
#include "q6apm.h"
#include "uke-fs19xx-readback.h"

struct uke_rb_client {
	spinlock_t lock;
	wait_queue_head_t wait;
	struct uke_rb_query query;
};
/* Never recycle a token during this module lifetime, including timed-out reads.
 * These diagnostics cannot authorize gain or act as a cross-reload safety lease.
 */
static atomic64_t uke_rb_tokens = ATOMIC64_INIT(0);

static int uke_rb_callback(const struct gpr_resp_pkt *reply, void *context, int op)
{
	struct uke_rb_client *client = context;
	struct uke_rb_envelope h;
	unsigned long flags;
	int complete = 0;

	spin_lock_irqsave(&client->lock, flags);
	if (op && client->query.pending) {
		uke_rb_cancel(&client->query, -ENODEV);
		complete = 1;
	} else if (reply && reply->payload_size >= 0) {
		h = (struct uke_rb_envelope) {
			.version = reply->hdr.version,
			.header_words = reply->hdr.hdr_size,
			.packet_bytes = reply->hdr.pkt_size,
			.reserved = reply->hdr.reserved,
			.source_domain = reply->hdr.src_domain,
			.destination_domain = reply->hdr.dest_domain,
			.source_port = reply->hdr.src_port,
			.destination_port = reply->hdr.dest_port,
			.token = reply->hdr.token,
			.opcode = reply->hdr.opcode,
		};
		complete = uke_rb_reply(&client->query, &h, reply->payload, reply->payload_size);
	}
	spin_unlock_irqrestore(&client->lock, flags);
	if (complete)
		wake_up(&client->wait);
	return 0;
}

/* Internal integration API, not exported outside the existing APM module.
 * Caller holds the admitted FS19xx graph/owner mutex through this call.
 * gpr_free_port must include the cumulative callback-drain fix0088.
 * Failure is diagnostic only: never reset/reprovision/mute a healthy stream.
 */
int q6apm_fs19xx_read_enables(struct q6apm *apm, unsigned int *enabled);
int q6apm_fs19xx_read_enables(struct q6apm *apm, unsigned int *enabled)
{
	struct uke_rb_client *client;
	struct gpr_pkt *packet;
	gpr_port_t *port;
	unsigned long flags;
	u64 last;
	unsigned int channel, mask = 0;
	int ret = -EINVAL;
	const int packet_bytes = GPR_HDR_SIZE + UKE_RB_REQUEST_BYTES;

	if (!apm || !enabled)
		return ret;
	*enabled = 0;
	last = atomic64_add_return(2, &uke_rb_tokens);
	if (last > U32_MAX)
		return -EOVERFLOW;
	client = kzalloc(sizeof(*client), GFP_KERNEL);
	if (!client)
		return -ENOMEM;
	packet = kzalloc(packet_bytes, GFP_KERNEL);
	if (!packet) {
		ret = -ENOMEM;
		goto free_client;
	}
	spin_lock_init(&client->lock);
	init_waitqueue_head(&client->wait);
	port = gpr_alloc_port(apm->gdev, apm->dev, uke_rb_callback, client);
	if (IS_ERR(port)) {
		ret = PTR_ERR(port);
		goto free_packet;
	}
	for (channel = 0; channel < 2; channel++) {
		memset(packet, 0, packet_bytes);
		packet->hdr.version = GPR_PKT_VER;
		packet->hdr.hdr_size = GPR_PKT_HEADER_WORD_SIZE;
		packet->hdr.pkt_size = packet_bytes;
		packet->hdr.src_domain = GPR_DOMAIN_ID_APPS;
		packet->hdr.dest_domain = GPR_DOMAIN_ID_ADSP;
		packet->hdr.src_port = port->id;
		packet->hdr.dest_port = 1;
		packet->hdr.token = last - 1 + channel;
		packet->hdr.opcode = UKE_RB_GET_CFG;
		spin_lock_irqsave(&client->lock, flags);
		ret = uke_rb_begin(&client->query, port->id, packet->hdr.token,
				   channel, (u8 *)packet->payload, UKE_RB_REQUEST_BYTES);
		spin_unlock_irqrestore(&client->lock, flags);
		if (ret)
			break;
		ret = gpr_send_port_pkt(port, packet);
		if (ret == packet_bytes)
			wait_event_timeout(client->wait, !READ_ONCE(client->query.pending),
					   msecs_to_jiffies(250));
		spin_lock_irqsave(&client->lock, flags);
		if (ret != packet_bytes)
			uke_rb_cancel(&client->query, ret < 0 ? ret : -EIO);
		else if (client->query.pending)
			uke_rb_cancel(&client->query, -ETIMEDOUT);
		ret = client->query.error;
		if (!ret && client->query.enabled)
			mask |= 1U << channel;
		spin_unlock_irqrestore(&client->lock, flags);
		if (ret)
			break;
	}
	/* No remote buffer address was sent; late replies have no DMA ownership.
	 * Drain callbacks before freeing their private query and wait queue.
	 */
	gpr_free_port(port);
	if (!ret)
		*enabled = mask;
free_packet:
	kfree(packet);
free_client:
	kfree(client);
	return ret;
}

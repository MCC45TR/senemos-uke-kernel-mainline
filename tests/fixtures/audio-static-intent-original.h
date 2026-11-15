/* SPDX-License-Identifier: GPL-2.0-only */
/* Copyright (c) 2020, Linaro Limited. */
/* Unchanged Linux7.3.1 audioreach.c synchronous helper, blob cce0ad31ff0c036e0cadd113e3a3e88b6344e02f. */
int audioreach_send_cmd_sync(struct device *dev, gpr_device_t *gdev,
			     struct gpr_ibasic_rsp_result_t *result, struct mutex *cmd_lock,
			     gpr_port_t *port, wait_queue_head_t *cmd_wait,
			     const struct gpr_pkt *pkt, uint32_t rsp_opcode)
{

	const struct gpr_hdr *hdr = &pkt->hdr;
	int rc;

	mutex_lock(cmd_lock);
	result->opcode = 0;
	result->status = 0;

	if (port)
		rc = gpr_send_port_pkt(port, pkt);
	else if (gdev)
		rc = gpr_send_pkt(gdev, pkt);
	else
		rc = -EINVAL;

	if (rc < 0)
		goto err;

	if (rsp_opcode)
		rc = wait_event_timeout(*cmd_wait, (result->opcode == hdr->opcode) ||
					(result->opcode == rsp_opcode),	5 * HZ);
	else
		rc = wait_event_timeout(*cmd_wait, (result->opcode == hdr->opcode), 5 * HZ);

	if (!rc) {
		dev_err(dev, "CMD timeout for [%x] opcode\n", hdr->opcode);
		rc = -ETIMEDOUT;
	} else if (result->status > 0) {
		dev_err(dev, "DSP returned error[%x] %x\n", hdr->opcode, result->status);
		rc = -EINVAL;
	} else {
		/* DSP successfully finished the command */
		rc = 0;
	}

err:
	mutex_unlock(cmd_lock);
	return rc;
}

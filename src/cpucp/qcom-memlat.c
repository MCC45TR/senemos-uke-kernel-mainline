// SPDX-License-Identifier: GPL-2.0-only
/*
 * Qualcomm MEMLAT typed reads; wire contract from the Uke OEM vendor protocol.
 * Copyright (c) 2022 Qualcomm Innovation Center, Inc. All rights reserved.
 */

#include <linux/scmi_qcom_memlat.h>

#include "../../protocols.h"

#define QCOM_SCMI_GET_PARAM	0x11
#define QCOM_MEMLAT_ALGORITHM	0x4d454d4c4154ULL
#define QCOM_MEMLAT_ADAPTIVE	22
#define QCOM_MEMLAT_CURRENT	35
#define QCOM_MEMLAT_TIMESTAMP	38

struct qcom_memlat_request {
	__le32 extended_id;
	__le32 algorithm_low;
	__le32 algorithm_high;
	__le32 parameter;
	__le32 hardware;
	__le32 monitor;
	__le32 value;
};

static_assert(sizeof(struct qcom_memlat_request) == 28);

static int qcom_memlat_read(const struct scmi_protocol_handle *ph, u32 parameter,
			    u32 hardware, u32 monitor, void *reply)
{
	struct qcom_memlat_request msg = {
		.algorithm_low = cpu_to_le32(lower_32_bits(QCOM_MEMLAT_ALGORITHM)),
		.algorithm_high = cpu_to_le32(upper_32_bits(QCOM_MEMLAT_ALGORITHM)),
		.parameter = cpu_to_le32(parameter),
		.hardware = cpu_to_le32(hardware),
		.monitor = cpu_to_le32(monitor),
	};
	struct scmi_xfer *t;
	size_t tx_size, rx_size;
	int ret;

	if (!ph || !ph->xops || !reply)
		return -EINVAL;

	switch (parameter) {
	case QCOM_MEMLAT_TIMESTAMP:
		tx_size = 16;
		rx_size = sizeof(__le64);
		break;
	case QCOM_MEMLAT_CURRENT:
	case QCOM_MEMLAT_ADAPTIVE:
		tx_size = sizeof(msg);
		rx_size = sizeof(__le32);
		break;
	default:
		return -EINVAL;
	}

	/* Shared-memory transport clips replies to the requested capacity. */
	ret = ph->xops->xfer_get_init(ph, QCOM_SCMI_GET_PARAM, tx_size,
				    rx_size + sizeof(__le32), &t);
	if (ret)
		return ret;

	memcpy(t->tx.buf, &msg, tx_size);
	ret = ph->xops->do_xfer(ph, t);
	if (!ret && t->rx.len != rx_size)
		ret = -EPROTO;
	if (!ret)
		memcpy(reply, t->rx.buf, rx_size);
	ph->xops->xfer_put(ph, t);
	return ret;
}

static int qcom_memlat_timestamp_raw(const struct scmi_protocol_handle *ph, u64 *value)
{
	__le64 reply;
	int ret;

	if (!value)
		return -EINVAL;
	ret = qcom_memlat_read(ph, QCOM_MEMLAT_TIMESTAMP, 0, 0, &reply);
	if (!ret)
		*value = le64_to_cpu(reply);
	return ret;
}

static int qcom_memlat_current_raw(const struct scmi_protocol_handle *ph,
				  u32 hardware, u32 monitor, u32 *value)
{
	__le32 reply;
	int ret;

	if (!value)
		return -EINVAL;
	ret = qcom_memlat_read(ph, QCOM_MEMLAT_CURRENT, hardware, monitor, &reply);
	if (!ret)
		*value = le32_to_cpu(reply);
	return ret;
}

static int qcom_memlat_adaptive_raw(const struct scmi_protocol_handle *ph,
				   u32 hardware, u32 *value)
{
	__le32 reply;
	int ret;

	if (!value)
		return -EINVAL;
	ret = qcom_memlat_read(ph, QCOM_MEMLAT_ADAPTIVE, hardware, 0, &reply);
	if (!ret)
		*value = le32_to_cpu(reply);
	return ret;
}

const struct scmi_qcom_memlat_ops scmi_qcom_memlat_read_ops = {
	.timestamp_raw = qcom_memlat_timestamp_raw,
	.current_raw = qcom_memlat_current_raw,
	.adaptive_raw = qcom_memlat_adaptive_raw,
};

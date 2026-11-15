/* SPDX-License-Identifier: GPL-2.0-only */
/* Closed metadata protocol from Qualcomm TPM v4 (19 October 2026).
 * No TPM2 command, initialization, transfer, key, PCR or NV operation.
 */
#ifndef UKE_QTEE_TPM_INFO_CORE_H
#define UKE_QTEE_TPM_INFO_CORE_H

#include <linux/types.h>

#define UKE_QTEE_TPM_UID 81U
#define UKE_QTEE_TPM_VERSION 0x1000U
#define UKE_QTEE_TPM_TYPE 0x80000U
#define UKE_QTEE_TPM_RESPONSE_BYTES 12U

enum uke_qtee_info_stage {
	UKE_QTEE_INFO_UNREQUESTED,
	UKE_QTEE_INFO_CONTEXT,
	UKE_QTEE_INFO_ENVIRONMENT,
	UKE_QTEE_INFO_SERVICE,
	UKE_QTEE_INFO_VERSION,
	UKE_QTEE_INFO_TYPE,
	UKE_QTEE_INFO_DONE,
};

enum uke_qtee_info_kind {
	UKE_QTEE_INFO_UNKNOWN,
	UKE_QTEE_INFO_FIRMWARE,
	UKE_QTEE_INFO_DISCRETE,
	UKE_QTEE_INFO_NONE,
};

struct uke_qtee_info_report {
	enum uke_qtee_info_stage stage;
	enum uke_qtee_info_kind kind;
	int transport, remote;
	__u32 invocation_attempts, vendor_queries;
	__u16 major, minor;
	bool malformed;
};

/* A non-NULL returned object belongs to the caller, including on refusal.
 * The kernel adapter never returns a dangling output from a failed invoke.
 * Releasing means local reference release; it is not a TA teardown attestation.
 */
struct uke_qtee_info_ops {
	int (*begin)(void *context);
	int (*environment)(void *context, void **object, int *remote);
	int (*service)(void *context, void *environment, void **object, int *remote);
	int (*query)(void *context, void *service, __u32 command,
		     __u8 response[UKE_QTEE_TPM_RESPONSE_BYTES],
		     __u32 *response_bytes, int *remote);
	void (*release)(void *context, void *object);
	void (*end)(void *context);
};

static inline __u32 uke_qtee_info_word(const __u8 *p)
{
	return (__u32)p[0] | (__u32)p[1] << 8 |
	       (__u32)p[2] << 16 | (__u32)p[3] << 24;
}

static inline void
uke_qtee_info_run(const struct uke_qtee_info_ops *ops, void *context,
		  struct uke_qtee_info_report *report)
{
	struct uke_qtee_info_report r = {
		.stage = UKE_QTEE_INFO_CONTEXT, .kind = UKE_QTEE_INFO_UNKNOWN,
		.transport = 0, .remote = 0, .invocation_attempts = 0,
		.vendor_queries = 0, .major = 0, .minor = 0, .malformed = false,
	};
	__u8 response[UKE_QTEE_TPM_RESPONSE_BYTES] = { 0 };
	__u32 size = sizeof(response), version, type;
	void *environment = 0, *service = 0;

	r.transport = ops->begin(context);
	if (r.transport)
		goto out;
	r.stage = UKE_QTEE_INFO_ENVIRONMENT;
	++r.invocation_attempts;
	r.transport = ops->environment(context, &environment, &r.remote);
	if (r.transport || r.remote)
		goto out;
	if (!environment) {
		r.malformed = true;
		goto out;
	}
	r.stage = UKE_QTEE_INFO_SERVICE;
	++r.invocation_attempts;
	r.transport = ops->service(context, environment, &service, &r.remote);
	if (r.transport || r.remote)
		goto out;
	if (!service) {
		r.malformed = true;
		goto out;
	}
	r.stage = UKE_QTEE_INFO_VERSION;
	++r.invocation_attempts;
	++r.vendor_queries;
	r.transport = ops->query(context, service, UKE_QTEE_TPM_VERSION,
				 response, &size, &r.remote);
	if (r.transport || r.remote)
		goto out;
	if (size != sizeof(response) || uke_qtee_info_word(response) ||
	    uke_qtee_info_word(response + 4) != UKE_QTEE_TPM_VERSION) {
		r.malformed = true;
		goto out;
	}
	version = uke_qtee_info_word(response + 8);
	r.major = version >> 16;
	r.minor = version;
	/* Never accept a stale version reply as the following type response. */
	for (size = 0; size < sizeof(response); ++size)
		response[size] = 0;
	size = sizeof(response);
	r.stage = UKE_QTEE_INFO_TYPE;
	++r.invocation_attempts;
	++r.vendor_queries;
	r.transport = ops->query(context, service, UKE_QTEE_TPM_TYPE,
				 response, &size, &r.remote);
	if (r.transport || r.remote)
		goto out;
	if (size != sizeof(response) ||
	    uke_qtee_info_word(response) != UKE_QTEE_TPM_TYPE ||
	    uke_qtee_info_word(response + 4)) {
		r.malformed = true;
		goto out;
	}
	type = uke_qtee_info_word(response + 8);
	switch (type) {
	case 0x6654504dU:
		r.kind = UKE_QTEE_INFO_FIRMWARE;
		break;
	case 0x6454504dU:
		r.kind = UKE_QTEE_INFO_DISCRETE;
		break;
	case 0x4e6f6e65U:
		r.kind = UKE_QTEE_INFO_NONE;
		break;
	default:
		r.malformed = true;
		goto out;
	}
	r.stage = UKE_QTEE_INFO_DONE;
out:
	if (service)
		ops->release(context, service);
	if (environment)
		ops->release(context, environment);
	ops->end(context);
	*report = r;
}
#endif

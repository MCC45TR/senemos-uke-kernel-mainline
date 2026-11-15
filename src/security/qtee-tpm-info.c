// SPDX-License-Identifier: GPL-2.0-only
/* One explicit Uke metadata request through the existing kernel QTEE client.
 * No firmware request at probe or parameter read. No TPM registration/startup.
 */
#include <linux/capability.h>
#include <linux/errno.h>
#include <linux/kernel.h>
#include <linux/mm.h>
#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/mutex.h>
#include <linux/of.h>
#include <linux/slab.h>
#include <linux/string.h>

#include "qcomtee.h"
#include "qtee-tpm-info.h"
#include "qtee-tpm-info-core.h"

static DEFINE_MUTEX(uke_info_lifecycle);
static DEFINE_MUTEX(uke_info_result);
static struct qcomtee *uke_info_provider;
static struct uke_qtee_info_report uke_info_report;
static bool uke_info_seen, uke_info_ambiguous;
static bool uke_info_requested, uke_info_busy, uke_info_present;

struct uke_info_context {
	struct tee_context *tee;
	struct qcomtee_object_invoke_ctx *invocation;
};

static int uke_info_begin(void *context)
{
	struct uke_info_context *c = context;

	c->invocation = qcomtee_object_invoke_ctx_alloc(c->tee);
	return c->invocation ? 0 : -ENOMEM;
}

static int uke_info_environment(void *context, void **object, int *remote)
{
	struct uke_info_context *c = context;
	struct qcomtee_arg args[3] = { 0 };
	int ret;

	/* Exactly the existing get_client_env() privileged kernel contract.
	 * This never passes through or relaxes the userspace ioctl restriction.
	 */
	args[0].type = QCOMTEE_ARG_TYPE_IO;
	args[0].o = NULL_QCOMTEE_OBJECT;
	args[1].type = QCOMTEE_ARG_TYPE_OO;
	ret = qcomtee_object_do_invoke(c->invocation, ROOT_QCOMTEE_OBJECT,
				      QCOMTEE_ROOT_OP_REG_WITH_CREDENTIALS,
				      args, remote);
	if (!ret && !*remote)
		*object = args[1].o;
	return ret;
}

static int uke_info_service(void *context, void *environment, void **object,
			    int *remote)
{
	struct uke_info_context *c = context;
	struct qcomtee_arg args[3] = { 0 };
	u32 uid = UKE_QTEE_TPM_UID;
	int ret;

	args[0].type = QCOMTEE_ARG_TYPE_IB;
	args[0].b.addr = &uid;
	args[0].b.size = sizeof(uid);
	args[1].type = QCOMTEE_ARG_TYPE_OO;
	ret = qcomtee_object_do_invoke(c->invocation, environment,
				      QCOMTEE_CLIENT_ENV_OPEN, args, remote);
	if (!ret && !*remote)
		*object = args[1].o;
	return ret;
}

static int uke_info_query(void *context, void *service, __u32 command,
			  __u8 response[UKE_QTEE_TPM_RESPONSE_BYTES],
			  __u32 *response_bytes, int *remote)
{
	struct uke_info_context *c = context;
	struct qcomtee_arg args[4] = { 0 };
	u8 request[4], locality = 0;
	int ret;

	if ((command != UKE_QTEE_TPM_VERSION && command != UKE_QTEE_TPM_TYPE) ||
	    *response_bytes != UKE_QTEE_TPM_RESPONSE_BYTES)
		return -EINVAL;
	request[0] = command;
	request[1] = command >> 8;
	request[2] = command >> 16;
	request[3] = command >> 24;
	args[0].type = QCOMTEE_ARG_TYPE_IB;
	args[0].b.addr = &locality;
	args[0].b.size = sizeof(locality);
	args[1].type = QCOMTEE_ARG_TYPE_IB;
	args[1].b.addr = request;
	args[1].b.size = sizeof(request);
	args[2].type = QCOMTEE_ARG_TYPE_OB;
	args[2].b.addr = response;
	args[2].b.size = UKE_QTEE_TPM_RESPONSE_BYTES;
	ret = qcomtee_object_do_invoke(c->invocation, service, 0, args, remote);
	if (!ret && !*remote) {
		if (locality || uke_qtee_info_word(request) != command ||
		    args[2].b.addr != response ||
		    args[2].b.size > UKE_QTEE_TPM_RESPONSE_BYTES)
			return -EPROTO;
		*response_bytes = args[2].b.size;
	}
	return ret;
}

static void uke_info_release(void *context, void *object)
{
	(void)context;
	qcomtee_object_put(object);
}

static void uke_info_end(void *context)
{
	struct uke_info_context *c = context;

	kfree(c->invocation);
	c->invocation = NULL;
}

static const struct uke_qtee_info_ops uke_info_ops = {
	.begin = uke_info_begin,
	.environment = uke_info_environment,
	.service = uke_info_service,
	.query = uke_info_query,
	.release = uke_info_release,
	.end = uke_info_end,
};

static bool uke_info_board(void)
{
	return of_machine_is_compatible("xiaomi,uke") &&
	       of_machine_is_compatible("qcom,sm7675");
}

static int uke_info_set(const char *value, const struct kernel_param *parameter)
{
	struct uke_qtee_info_report result;
	struct uke_info_context context = { 0 };
	int ret = 0;

	(void)parameter;
	if (!capable(CAP_SYS_ADMIN))
		return -EPERM;
	if (!sysfs_streq(value, "1"))
		return -EINVAL;
	if (!uke_info_board())
		return -ENODEV;
	/* Serializes an invocation with provider teardown. Cached reads use a
	 * separate short lock and never wait for the synchronous firmware call.
	 */
	mutex_lock(&uke_info_lifecycle);
	if (!uke_info_provider || uke_info_ambiguous) {
		ret = -ENODEV;
		goto unlock;
	}
	mutex_lock(&uke_info_result);
	if (uke_info_requested) {
		mutex_unlock(&uke_info_result);
		ret = -EALREADY;
		goto unlock;
	}
	uke_info_requested = true;
	uke_info_busy = true;
	mutex_unlock(&uke_info_result);
	context.tee = uke_info_provider->ctx;
	uke_qtee_info_run(&uke_info_ops, &context, &result);
	mutex_lock(&uke_info_result);
	uke_info_report = result;
	uke_info_busy = false;
	mutex_unlock(&uke_info_result);
unlock:
	mutex_unlock(&uke_info_lifecycle);
	return ret;
}

static int uke_info_get(char *buffer, const struct kernel_param *parameter)
{
	struct uke_qtee_info_report r;
	bool requested, busy, present;

	(void)parameter;
	mutex_lock(&uke_info_result);
	r = uke_info_report;
	requested = uke_info_requested;
	busy = uke_info_busy;
	present = uke_info_present;
	mutex_unlock(&uke_info_result);
	return scnprintf(buffer, PAGE_SIZE,
		"schema=1 requested=%u busy=%u present=%u stage=%u transport=%d remote=%d malformed=%u kind=%u major=%u minor=%u invocation_attempts=%u vendor_queries=%u\n",
		requested, busy, present, r.stage, r.transport, r.remote,
		r.malformed, r.kind, r.major, r.minor,
		r.invocation_attempts, r.vendor_queries);
}

static const struct kernel_param_ops uke_info_parameter_ops = {
	.set = uke_info_set,
	.get = uke_info_get,
};
module_param_cb(uke_tpm_information, &uke_info_parameter_ops, NULL, 0600);
MODULE_PARM_DESC(uke_tpm_information,
	"Uke diagnostic: write 1 once after provider probe; read cached TPM vendor information only");

void uke_qtee_tpm_info_attach(struct qcomtee *qcomtee)
{
	if (!uke_info_board())
		return;
	mutex_lock(&uke_info_lifecycle);
	if (uke_info_seen) {
		uke_info_ambiguous = true;
		uke_info_provider = NULL;
	} else {
		uke_info_seen = true;
		uke_info_provider = qcomtee;
	}
	mutex_lock(&uke_info_result);
	uke_info_present = !!uke_info_provider;
	mutex_unlock(&uke_info_result);
	mutex_unlock(&uke_info_lifecycle);
}

void uke_qtee_tpm_info_detach(struct qcomtee *qcomtee)
{
	mutex_lock(&uke_info_lifecycle);
	if (uke_info_provider == qcomtee) {
		uke_info_provider = NULL;
		mutex_lock(&uke_info_result);
		uke_info_present = false;
		mutex_unlock(&uke_info_result);
	}
	mutex_unlock(&uke_info_lifecycle);
}

/* SPDX-License-Identifier: GPL-2.0-only */
/* Execute the real query implementation against a recording SCM transport. */
#include <assert.h>
#include <errno.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>

#define CONFIG_QCOM_UKE_EL2_QUERY 1
#define QCOM_SCM_SVC_INFO 6
#define QCOM_SCM_INFO_IS_CALL_AVAIL 1
#define QCOM_SCM_SVC_BOOT 1
#define QCOM_SCM_ARGS(n) (n)
#define ARM_SMCCC_OWNER_SIP 2
#define ARM_SMCCC_OWNER_SHIFT 24
#define SCM_SMC_FNID(s, c) (((s) << 8) | (c))
#define SCM_LEGACY_FNID(s, c) (((s) << 10) | (c))
typedef uint64_t u64;
struct device { int unused; };
struct device_attribute { int attr; };
struct attribute { int unused; };
struct attribute_group { struct attribute **attrs; };
struct qcom_scm_desc { unsigned int svc, cmd, arginfo, owner; u64 args[10]; };
struct qcom_scm_res { u64 result[3]; };
enum { SMC_CONVENTION_ARM_64, SMC_CONVENTION_ARM_32,
       SMC_CONVENTION_LEGACY, SMC_CONVENTION_UNKNOWN };
static int convention, transport, calls, publications;
static bool uke = true;
static struct qcom_scm_res response;
#define read_sysreg(reg) 4UL
#define is_hyp_mode_available() false
#define DEVICE_ATTR_RO(name) struct { struct attribute attr; } dev_attr_##name
#define dev_info(dev, ...) ((void)(dev))
#define dev_warn(dev, ...) ((void)(dev))
static bool of_machine_is_compatible(const char *name)
{ assert(strcmp(name, "xiaomi,uke") == 0); return uke; }
static int __get_convention(void) { return convention; }
static int devm_device_add_group(struct device *dev, const struct attribute_group *group)
{ (void)dev; assert(group->attrs[0]); publications++; return 0; }
static int qcom_scm_call(struct device *dev, const struct qcom_scm_desc *desc,
			struct qcom_scm_res *res)
{
	(void)dev;
	assert(desc->svc == QCOM_SCM_SVC_INFO);
	assert(desc->cmd == QCOM_SCM_INFO_IS_CALL_AVAIL);
	assert(desc->arginfo == QCOM_SCM_ARGS(1));
	assert(desc->owner == ARM_SMCCC_OWNER_SIP);
	assert(desc->args[0] == (convention == SMC_CONVENTION_LEGACY ?
		SCM_LEGACY_FNID(1, 0x21) : 0x02000121));
	for (unsigned int i = 1; i < 10; i++) assert(desc->args[i] == 0);
	calls++;
	*res = response;
	return transport;
}
static ssize_t sysfs_emit(char *buf, const char *format, ...)
{
	va_list args; va_start(args, format);
	int n = vsnprintf(buf, 4096, format, args);
	va_end(args); return n;
}
#include "../src/boot/uke-el2-query.h"

static void scenario(int mode, int error, u64 available, const char *expected)
{
	struct device dev = {};
	char text[4096];
	memset(&uke_el2_query, 0, sizeof(uke_el2_query));
	convention = mode; transport = error; calls = publications = 0;
	response = (struct qcom_scm_res){ .result = {available, 0x12345678, 0xabcdef} };
	uke_el2_query_run(&dev);
	assert(calls == (mode != SMC_CONVENTION_UNKNOWN));
	assert(publications == 1);
	assert(uke_el2_query.transport == error);
	uke_el2_query_show(&dev, NULL, text);
	assert(strstr(text, expected));
	assert(strstr(text, "exit_requested=0\n"));
	if (calls) assert(strstr(text, "result1=0x12345678\n"));
	uke_el2_query_show(&dev, NULL, text);
	assert(calls == (mode != SMC_CONVENTION_UNKNOWN));
}
int main(void)
{
	scenario(SMC_CONVENTION_ARM_64, 0, 1, "availability=advertised\n");
	scenario(SMC_CONVENTION_ARM_32, 0, 0, "availability=not-advertised\n");
	scenario(SMC_CONVENTION_LEGACY, 0, 1, "availability=advertised\n");
	scenario(SMC_CONVENTION_ARM_64, -EIO, 1, "availability=unknown\n");
	scenario(SMC_CONVENTION_UNKNOWN, -EOPNOTSUPP, 0, "availability=unknown\n");
	uke = false; calls = publications = 0;
	uke_el2_query_run(&(struct device){});
	assert(calls == 0 && publications == 0);
	puts("SCM query transport, errors, legacy IDs, passive reads and board gate passed");
	return 0;
}

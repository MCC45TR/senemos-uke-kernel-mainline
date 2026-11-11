// SPDX-License-Identifier: GPL-2.0-only
// Actual Linux callbacks, with deterministic W1C and IRQ/poller boundaries.
#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include "registers.inc"

typedef uint32_t u32;
typedef int irqreturn_t;
enum { IRQ_HANDLED = 1 };
struct a6xx_gmu {
	u32 pending, after_read, cleared, last_clear;
	unsigned reads, writes, faults, fault_logs, errors;
	bool irq_before_poll;
	void *dev;
};
struct completion { bool done; unsigned waits; struct a6xx_gmu *owner; };
struct adreno_gpu { struct completion fault_coredump_done; };
struct a6xx_gpu { struct adreno_gpu base; struct a6xx_gmu gmu; };
#define container_of(ptr, type, member) ((type *)((char *)(ptr) - offsetof(type, member)))
static u32 gmu_read(struct a6xx_gmu *gmu, u32 reg)
{
	assert(reg == REG_A6XX_GMU_GMU2HOST_INTR_INFO);
	u32 observed = gmu->pending;
	++gmu->reads;
	gmu->pending |= gmu->after_read;
	gmu->after_read = 0;
	return observed;
}
static void gmu_write(struct a6xx_gmu *gmu, u32 reg, u32 value)
{
	assert(reg == REG_A6XX_GMU_GMU2HOST_INTR_CLR);
	++gmu->writes;
	gmu->last_clear = value;
	gmu->cleared |= value;
	gmu->pending &= ~value;
}
static void fault_log(void *dev) { ++((struct a6xx_gmu *)dev)->fault_logs; }
static void error_log(void *dev) { ++((struct a6xx_gmu *)dev)->errors; }
static void a6xx_gmu_fault(struct a6xx_gmu *gmu) { ++gmu->faults; }
#define dev_err_ratelimited(dev, ...) fault_log(dev)
#define DRM_DEV_ERROR(dev, ...) error_log(dev)
static bool completion_done(struct completion *event) { return event->done; }
static void wait_for_completion(struct completion *event)
{
	assert(!event->done && event->owner);
	++event->waits;
	event->done = true;
	/* An injected MMU-resume completion releases a genuine pending response. */
	event->owner->pending |= A6XX_GMU_GMU2HOST_INTR_INFO_MSGQ;
}
#include "irq.inc"

/* No timer, CPU sleep or MMIO. The IRQ runs at the response/poll boundary. */
#define gmu_poll_timeout(gmu, reg, value, condition, period, timeout) ({ \
	assert((period) == 100 && (timeout) == 1000000); \
	int _result = -ETIMEDOUT; \
	for (unsigned _poll = 0; _poll < 3; ++_poll) { \
		if ((gmu)->irq_before_poll) { \
			(gmu)->irq_before_poll = false; \
			assert(a6xx_hfi_irq(0, gmu) == IRQ_HANDLED); \
		} \
		(value) = gmu_read(gmu, reg); \
		if (condition) { _result = 0; break; } \
	} \
	_result; \
})
#include "wait.inc"

static void reset(struct a6xx_gpu *gpu, u32 pending)
{
	memset(gpu, 0, sizeof(*gpu));
	gpu->gmu.pending = pending;
	gpu->gmu.dev = &gpu->gmu;
	gpu->base.fault_coredump_done.done = true;
	gpu->base.fault_coredump_done.owner = &gpu->gmu;
}
static void isolated_irq(u32 before, u32 arrival)
{
	const u32 owned = A6XX_GMU_GMU2HOST_INTR_INFO_CM3_FAULT;
	struct a6xx_gpu gpu;
	reset(&gpu, before);
	gpu.gmu.after_read = arrival;
	assert(a6xx_hfi_irq(0, &gpu.gmu) == IRQ_HANDLED);
	assert(gpu.gmu.reads == 1 && gpu.gmu.writes == 1);
	assert(gpu.gmu.last_clear == (before & owned));
	assert(gpu.gmu.pending == ((before | arrival) & ~(before & owned)));
	assert(gpu.gmu.faults == !!(before & owned));
	assert(gpu.gmu.fault_logs == gpu.gmu.faults && !gpu.gmu.errors);
	/* A fault arriving after a zero snapshot must remain pending and dispatch. */
	if (!(before & owned) && (arrival & owned)) {
		assert(a6xx_hfi_irq(0, &gpu.gmu) == IRQ_HANDLED);
		assert(gpu.gmu.faults == 1 && gpu.gmu.fault_logs == 1);
		assert(!(gpu.gmu.pending & owned));
	}
}
int main(void)
{
	const u32 msgq = A6XX_GMU_GMU2HOST_INTR_INFO_MSGQ;
	const u32 fault = A6XX_GMU_GMU2HOST_INTR_INFO_CM3_FAULT;
	assert(msgq && !(msgq & (msgq - 1)) && fault && !(fault & (fault - 1)) && !(msgq & fault));
	struct a6xx_gpu gpu;
	reset(&gpu, msgq);
	gpu.gmu.irq_before_poll = true;
	int result = a6xx_hfi_wait_for_msg_interrupt(&gpu.gmu, HFI_H2F_MSG_GX_BW_PERF_VOTE, 272);
	assert(result == 0 && "HFI response must survive an unrelated fault IRQ");
	assert(!gpu.gmu.pending && gpu.gmu.writes == 2 && !gpu.gmu.errors && !gpu.gmu.faults);
	assert(!gpu.base.fault_coredump_done.waits);

	isolated_irq(0, 0);
	isolated_irq(UINT32_MAX, 0);
	for (unsigned bit = 0; bit < 32; ++bit) {
		u32 pending = UINT32_C(1) << bit;
		isolated_irq(pending, 0);
		isolated_irq(pending | fault, 0);
		for (unsigned late = 0; late < 32; ++late) {
			isolated_irq(pending, UINT32_C(1) << late);
			isolated_irq(pending | fault, UINT32_C(1) << late);
		}
	}
	u32 random = UINT32_C(0x83c6a029);
	for (unsigned i = 0; i < 4096; ++i) {
		random ^= random << 13; random ^= random >> 17; random ^= random << 5;
		isolated_irq(random, random ^ UINT32_C(0xa5913b7c));
	}
	/* Pending OOB/unknown bits survive both the IRQ and the actual MSGQ poller. */
	for (unsigned bit = 0; bit < 32; ++bit) {
		u32 other = UINT32_C(1) << bit;
		if (other & (msgq | fault)) continue;
		reset(&gpu, msgq | fault | other);
		gpu.gmu.irq_before_poll = true;
		assert(a6xx_hfi_wait_for_msg_interrupt(&gpu.gmu, HFI_H2F_MSG_GX_BW_PERF_VOTE, 273) == 0);
		assert(gpu.gmu.pending == other && gpu.gmu.faults == 1 && gpu.gmu.fault_logs == 1);
		assert(!gpu.gmu.errors && gpu.gmu.cleared == (msgq | fault));
	}
	/* Real absence still times out; the change cannot invent a response. */
	reset(&gpu, 0);
	assert(a6xx_hfi_wait_for_msg_interrupt(&gpu.gmu, HFI_H2F_MSG_GX_BW_PERF_VOTE, 274) == -ETIMEDOUT);
	assert(gpu.gmu.errors == 1 && !gpu.gmu.writes && !gpu.gmu.faults);
	/* Preserve the original fault-coredump completion and retry branch. */
	reset(&gpu, 0);
	gpu.base.fault_coredump_done.done = false;
	assert(a6xx_hfi_wait_for_msg_interrupt(&gpu.gmu, HFI_H2F_MSG_GX_BW_PERF_VOTE, 275) == 0);
	assert(gpu.base.fault_coredump_done.waits == 1 && !gpu.gmu.errors && !gpu.gmu.pending);
	puts("Actual HFI IRQ/waiter: response survives unsolicited IRQ; all32 latch bits, 2112 single/paired late arrivals, 4096 mixed statuses, OOB preservation, genuine timeout and fault completion pass; modeled W1C only.");
	return 0;
}

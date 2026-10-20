#!/usr/bin/env bash
# shellcheck disable=SC2129
# Actual IRQ/command/power-off functions; host-only kernel IRQ model.
set -Eeuo pipefail
iris=${1:?Pass the prepared Iris directory}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cat > "$work/check.cpp" <<'CPP'
#include <cassert>
#include <cerrno>
#include <string>
#include <vector>
using u32 = unsigned;
using irqreturn_t = int;
constexpr int IRQ_NONE=0, IRQ_HANDLED=1, IRQ_WAKE_THREAD=2;
constexpr int IRIS_CORE_INIT=1, IRIS_CORE_ERROR=2, IRIS_CORE_DEINIT=0;
struct device {};
struct iris_iface_q_info {};
struct iris_core;
struct vpu_ops { void (*power_off_hw)(iris_core *); int (*power_off_controller)(iris_core *); };
struct platform_data { const struct vpu_ops *vpu_ops; };
struct iris_hfi_sys_ops { void (*sys_hfi_response_handler)(iris_core *); };
struct iris_core {
    struct device *dev;
    const platform_data *iris_platform_data;
    const iris_hfi_sys_ops *hfi_sys_ops;
    int irq, lock, state;
    bool irq_enabled, removing;
    u32 intr_status;
    iris_iface_q_info command_queue;
};
static iris_core *expected_core;
static int lock_depth;
static unsigned irq_depth, enables, disables, reads, responses, queue_writes, raises;
static bool clocks_live, oneshot_mask, trigger_watchdog, stop_during_response;
static std::vector<std::string> events;
static void mutex_lock(int *held_mutex) { assert(held_mutex==&expected_core->lock && lock_depth++==0); }
static void mutex_unlock(int *held_mutex) { assert(held_mutex==&expected_core->lock && --lock_depth==0); }
#define lockdep_assert_held(held_mutex) assert((held_mutex)==&expected_core->lock && lock_depth==1)
static void enable_irq(int) {
    assert(lock_depth==1 && irq_depth==1); --irq_depth; ++enables; events.emplace_back("irq-on");
}
static void disable_irq_nosync(int) {
    assert(lock_depth==1); ++irq_depth; ++disables; events.emplace_back("irq-off");
}
[[maybe_unused]] static void disable_irq(int irq) {
    assert(!lock_depth); ++irq_depth; ++disables;
}
static void pm_runtime_mark_last_busy(device *) { assert(lock_depth==1); }
static void iris_vpu_clear_interrupt(iris_core *core) {
    assert(lock_depth==1 && clocks_live && oneshot_mask && !irq_depth && core->irq_enabled);
    ++reads; core->intr_status=trigger_watchdog ? 1 : 0;
}
static bool iris_vpu_watchdog(iris_core *, u32 status) { return status!=0; }
static int iris_opp_set_rate(device *, unsigned long freq) {
    assert(lock_depth==1 && !freq); events.emplace_back("opp-off"); return 0;
}
static int iris_unset_icc_bw(iris_core *) { assert(lock_depth==1); events.emplace_back("icc-off"); return 0; }
static void hardware_off(iris_core *core) {
    assert(lock_depth==1 && clocks_live && !core->irq_enabled && irq_depth==1); events.emplace_back("hw-off");
}
static int controller_off(iris_core *core) {
    assert(lock_depth==1 && !core->irq_enabled && irq_depth==1); clocks_live=false; events.emplace_back("ctrl-off"); return 0;
}
static int iris_hfi_queue_write(iris_iface_q_info *, void *, u32) { ++queue_writes; return 0; }
static void iris_vpu_raise_interrupt(iris_core *core) {
    assert(lock_depth==1 && clocks_live && core->irq_enabled && !irq_depth); ++raises;
}
#define dev_err(...) ((void)0)
void iris_vpu_power_off(iris_core *);
int iris_hfi_queue_cmd_write_locked(iris_core *, void *, u32);
static void response_handler(iris_core *core) {
    assert(!lock_depth); ++responses;
    if (stop_during_response) {
        mutex_lock(&core->lock); iris_vpu_power_off(core);
        unsigned packet{};
        assert(iris_hfi_queue_cmd_write_locked(core,&packet,sizeof(packet))==-EAGAIN);
        mutex_unlock(&core->lock);
    }
}
CPP
awk '/^#define IRQF_(TRIGGER_HIGH|NO_AUTOEN|ONESHOT)[[:space:]]/ {print}' \
    "$iris/../../../../../include/linux/interrupt.h" >> "$work/check.cpp"
printf 'constexpr unsigned probe_flags = ' >> "$work/check.cpp"
awk '/IRQF_TRIGGER_HIGH/ {sub(/,[[:space:]]*$/, ";"); print; exit}' \
    "$iris/iris_probe.c" >> "$work/check.cpp"
for name in iris_hfi_irq_enable iris_hfi_irq_disable iris_hfi_isr iris_hfi_isr_handler; do
    awk -v name="$name" '$0 ~ "^(void|irqreturn_t) " name "\\(" {emit=1} emit {print} emit && /^}/ {exit}' \
        "$iris/iris_hfi_common.c" |
        sed 's/struct iris_core \*core = data;/struct iris_core *core = (struct iris_core *)data;/' >> "$work/check.cpp"
done
awk '/^void iris_vpu_power_off\(/ {emit=1} emit {print} emit && /^}/ {exit}' \
    "$iris/iris_vpu_common.c" >> "$work/check.cpp"
awk '/^int iris_hfi_queue_cmd_write_locked\(/ {emit=1} emit {print} emit && /^}/ {exit}' \
    "$iris/iris_hfi_queue.c" >> "$work/check.cpp"
cat >> "$work/check.cpp" <<'CPP'
static const vpu_ops ops{hardware_off,controller_off};
static const platform_data platform{&ops};
static const iris_hfi_sys_ops hfi{response_handler};
static device dev;
static void reset(iris_core &core) {
    core={}; expected_core=&core; core.dev=&dev; core.iris_platform_data=&platform;
    core.hfi_sys_ops=&hfi; core.state=IRIS_CORE_INIT; core.irq=7;
    lock_depth=0; irq_depth=1; enables=disables=reads=responses=queue_writes=raises=0;
    clocks_live=true; oneshot_mask=trigger_watchdog=stop_during_response=false; events.clear();
}
static void enable(iris_core &core) { mutex_lock(&core.lock); iris_hfi_irq_enable(&core); mutex_unlock(&core.lock); }
static void run_irq(iris_core &core) {
    assert(!oneshot_mask && !irq_depth);
    assert(iris_hfi_isr(core.irq,&core)==IRQ_WAKE_THREAD && !irq_depth);
    oneshot_mask=true;
    assert(iris_hfi_isr_handler(core.irq,&core)==IRQ_HANDLED);
    oneshot_mask=false;
}
int main() {
    assert((probe_flags&IRQF_ONESHOT) && (probe_flags&IRQF_NO_AUTOEN) && (probe_flags&IRQF_TRIGGER_HIGH));
    iris_core core; reset(core);
    assert(iris_hfi_isr_handler(core.irq,nullptr)==IRQ_NONE);
    core.hfi_sys_ops=nullptr; oneshot_mask=true;
    assert(iris_hfi_isr_handler(core.irq,&core)==IRQ_HANDLED && !reads && !responses);
    reset(core); enable(core); enable(core);
    assert(enables==1 && irq_depth==0 && core.irq_enabled);
    run_irq(core);
    assert(reads==1 && responses==1 && enables==1 && !disables && !irq_depth);
    trigger_watchdog=true; run_irq(core);
    assert(reads==2 && responses==2 && disables==1 && !core.irq_enabled && irq_depth==1);
    mutex_lock(&core.lock); iris_vpu_power_off(&core); iris_hfi_irq_disable(&core); mutex_unlock(&core.lock);
    assert(disables==1 && irq_depth==1 && !clocks_live);
    clocks_live=true; trigger_watchdog=false; enable(core); enable(core);
    assert(enables==2 && !irq_depth);
    run_irq(core); assert(responses==3 && !irq_depth);

    reset(core); enable(core);
    assert(iris_hfi_isr(core.irq,&core)==IRQ_WAKE_THREAD && !irq_depth); oneshot_mask=true;
    events.clear(); mutex_lock(&core.lock); iris_vpu_power_off(&core); mutex_unlock(&core.lock);
    assert((events==std::vector<std::string>{"irq-off","opp-off","hw-off","ctrl-off","icc-off"}));
    core.hfi_sys_ops=nullptr;
    assert(iris_hfi_isr_handler(core.irq,&core)==IRQ_HANDLED);
    oneshot_mask=false; assert(!reads && !responses && irq_depth==1 && disables==1);

    reset(core); enable(core); stop_during_response=true;
    run_irq(core);
    assert(reads==1 && responses==1 && irq_depth==1 && !core.irq_enabled && !clocks_live);
    assert(!queue_writes && !raises && !lock_depth && disables==1 && enables==1);
}
CPP
"${CXX:-g++}" -std=c++20 -O2 -Wall -Wextra -Werror -Wno-unused-parameter \
    "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Actual Iris IRQ: probe flags, ONESHOT, balanced depth, watchdog, delayed thread and post-stop MMIO refusal passed\n'

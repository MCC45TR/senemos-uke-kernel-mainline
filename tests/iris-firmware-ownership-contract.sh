#!/usr/bin/env bash
# Actual firmware/core/PM functions with host-only PAS and DMA ownership faults.
set -Eeuo pipefail
iris=${1:?Pass the prepared Iris directory}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cat > "$work/check.cpp" <<'CPP'
#include <cassert>
#include <cerrno>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>
using phys_addr_t = std::uint64_t;
using u32 = std::uint32_t;
struct iris_core;
struct device { void *of_node; } device;
struct firmware {} firmware;
struct resource { phys_addr_t start, end; };
struct tz_cp_config { unsigned cp_start, cp_size, cp_nonpixel_start, cp_nonpixel_size; };
struct platform_data { const tz_cp_config *tz_cp_config_data; unsigned tz_cp_config_data_size; };
struct firmware_desc { const char *fwname; };
struct firmware_data { void (*init_hfi_ops)(iris_core *); };
struct work_struct { iris_core *owner; };
struct delayed_work { work_struct work; };
enum iris_core_state { IRIS_CORE_DEINIT, IRIS_CORE_INIT, IRIS_CORE_ERROR };
struct iris_core {
    struct device *dev;
    iris_core_state state;
    bool fw_owned;
    const platform_data *iris_platform_data;
    const firmware_desc *iris_firmware_desc;
    const firmware_data *iris_firmware_data;
    int lock, core_init_done;
    delayed_work sys_error_handler;
};
static std::vector<std::string> events;
static int fault, shutdown_error, pm_result, pm_error;
static unsigned allocs, frees, power_offs, shuts, sync_puts, idle_puts, pm_calls, releases;
static bool queues_live;
static unsigned response;
constexpr int failure = -EPROTO;
constexpr int IRIS_PAS_ID = 9, MAX_FIRMWARE_NAME_SIZE = 128, MEMREMAP_WC = 1;
constexpr unsigned HW_RESPONSE_TIMEOUT_VALUE = 1000;
static int step(const char *name, int stage) {
    events.emplace_back(name); return fault == stage ? failure : 0;
}
static int of_reserved_mem_region_to_resource(void *, unsigned, resource *r) {
    *r = {0x100000, 0x100fff}; return step("region", 1);
}
static std::uint64_t resource_size(const resource *r) { return r->end-r->start+1; }
static int request_firmware(const struct firmware **f, const char *, struct device *) {
    *f = &firmware; return step("request", 2);
}
static long qcom_mdt_get_size(const struct firmware *) { return fault == 3 ? -ENOEXEC : 1024; }
static void *memremap(phys_addr_t, std::size_t, int) { return fault == 4 ? nullptr : &firmware; }
static int qcom_mdt_load(struct device *, const struct firmware *, const char *, int id,
                         void *, phys_addr_t, std::size_t, void *) {
    assert(id == IRIS_PAS_ID); return step("mdt", 5);
}
static void memunmap(void *) { events.emplace_back("unmap-cpu"); }
static void release_firmware(const struct firmware *) { ++releases; }
static int of_property_read_string_index(void *, const char *, unsigned, const char **) {
    return -ENOENT;
}
static int qcom_scm_pas_auth_and_reset(int id) {
    assert(id == IRIS_PAS_ID); return step("auth", 6);
}
static int qcom_scm_mem_protect_video_var(unsigned start, unsigned, unsigned, unsigned) {
    return step("protect", start == 1 ? 7 : 8);
}
static int qcom_scm_pas_shutdown(int id) {
    assert(id == IRIS_PAS_ID); ++shuts; events.emplace_back("shutdown"); return shutdown_error;
}
#define dev_err(...) ((void)0)
int iris_fw_unload(iris_core *);
CPP
for name in iris_load_fw_to_memory iris_fw_load iris_fw_unload; do
    awk -v name="$name" '$0 ~ "^(static )?int " name "\\(" { emit=1 } emit { print } emit && /^}/ { exit }' \
        "$iris/iris_firmware.c" >> "$work/check.cpp"
done
cat >> "$work/check.cpp" <<'CPP'
static int pm_runtime_resume_and_get(struct device *) { return pm_result; }
static void mutex_lock(int *) {}
static void mutex_unlock(int *) {}
static void pm_runtime_put_sync(struct device *) { ++sync_puts; }
static void pm_runtime_put_noidle(struct device *) { ++idle_puts; }
static void iris_vpu_power_off(iris_core *) { ++power_offs; events.emplace_back("power-off"); }
static void iris_hfi_queues_deinit(iris_core *) {
    assert(queues_live); queues_live = false; ++frees; events.emplace_back("free");
}
static unsigned msecs_to_jiffies(unsigned value) { return value; }
static unsigned wait_for_completion_timeout(int *, unsigned) { return response; }
static int iris_hfi_queues_init(iris_core *) {
    ++allocs; const int ret = step("queues", 9); queues_live = !ret; return ret;
}
static int iris_vpu_power_on(iris_core *) { return step("power-on", 10); }
static int iris_vpu_boot_firmware(iris_core *) { return step("boot", 11); }
static int iris_vpu_switch_to_hwmode(iris_core *) { return step("hwmode", 12); }
static int iris_hfi_core_init(iris_core *) { return step("hfi-init", 13); }
CPP
for name in iris_core_deinit iris_wait_for_system_response iris_core_init; do
    awk -v name="$name" '$0 ~ "^(static )?int " name "\\(" { emit=1 } emit { print } emit && /^}/ { exit }' \
        "$iris/iris_core.c" >> "$work/check.cpp"
done
cat >> "$work/check.cpp" <<'CPP'
#define container_of(work, type, field) ((work)->owner)
#define __maybe_unused
static iris_core *device_core;
static iris_core *dev_get_drvdata(struct device *) { return device_core; }
static int iris_hfi_pm_suspend(iris_core *) { ++pm_calls; return pm_error; }
static int iris_hfi_pm_resume(iris_core *) { ++pm_calls; return pm_error; }
static void pm_runtime_mark_last_busy(struct device *) {}
CPP
for name in iris_sys_error_handler iris_pm_suspend iris_pm_resume; do
    awk -v name="$name" '$0 ~ "^static (int|void) (__maybe_unused )?" name "\\(" { emit=1 } emit { print } emit && /^}/ { exit }' \
        "$iris/iris_probe.c" >> "$work/check.cpp"
done
cat >> "$work/check.cpp" <<'CPP'
static void init_ops(iris_core *) {}
static const tz_cp_config configs[]{{1, 1, 1, 1}, {2, 1, 1, 1}};
static const platform_data platform{configs, 2};
static const firmware_desc description{"test.mbn"};
static const firmware_data data{init_ops};
static void reset(iris_core &core) {
    core = {}; core.dev = &device; core.iris_platform_data = &platform;
    core.iris_firmware_desc = &description; core.iris_firmware_data = &data;
    core.sys_error_handler.work.owner = &core; device_core = &core;
    events.clear(); fault = shutdown_error = pm_result = pm_error = 0;
    allocs = frees = power_offs = shuts = sync_puts = idle_puts = pm_calls = releases = 0;
    queues_live = false; response = 1;
}
int main() {
    iris_core core;
    reset(core);
    assert(iris_fw_unload(&core) == 0 && shuts == 0);
    assert(iris_fw_load(&core) == 0 && core.fw_owned && releases == 1);
    const auto loaded = events;
    assert(iris_fw_load(&core) == -EBUSY && events == loaded);
    shutdown_error = -ETIMEDOUT;
    assert(iris_fw_unload(&core) == -ETIMEDOUT && core.fw_owned);
    shutdown_error = 0;
    assert(iris_fw_unload(&core) == 0 && !core.fw_owned);
    assert(iris_fw_unload(&core) == 0 && shuts == 2);

    for (int stage = 1; stage <= 8; ++stage) {
        for (bool halt_fails : {false, true}) {
            reset(core); fault = stage; shutdown_error = halt_fails ? -ETIMEDOUT : 0;
            const int expected = stage == 3 ? -EINVAL : stage == 4 ? -ENOMEM : failure;
            assert(iris_fw_load(&core) == expected);
            assert(core.fw_owned == (stage >= 5 && halt_fails));
            assert(shuts == (stage >= 5 ? 1U : 0U));
            assert(releases == (stage >= 3 ? 1U : 0U));
        }
    }
    for (int stage = 1; stage <= 13; ++stage) {
        for (bool halt_fails : {false, true}) {
            reset(core); fault = stage; shutdown_error = halt_fails ? -ETIMEDOUT : 0;
            const int expected = stage == 3 ? -EINVAL : stage == 4 ? -ENOMEM : failure;
            assert(iris_core_init(&core) == expected);
            const bool owned = halt_fails && ((stage >= 5 && stage <= 8) || stage >= 11);
            assert(core.fw_owned == owned && queues_live == owned);
            assert(core.state == (owned ? IRIS_CORE_ERROR : IRIS_CORE_DEINIT));
            if (owned) {
                assert(frees == 0 && power_offs == 0);
                const auto retained = events;
                assert(iris_core_init(&core) == -EINVAL);
                assert(iris_core_init(&core) == -EINVAL && events == retained);
                assert(core.state == IRIS_CORE_ERROR);
                assert(iris_pm_suspend(&device) == -EBUSY);
                assert(iris_pm_resume(&device) == -EBUSY && pm_calls == 0);
                shutdown_error = 0;
                assert(iris_core_deinit(&core) == 0 && !core.fw_owned && !queues_live);
                assert(frees == 1 && power_offs == 1 && sync_puts == 1);
            }
        }
    }
    for (int pm : {0, 1, -EIO}) {
        reset(core); assert(iris_core_init(&core) == 0);
        pm_result = pm; shutdown_error = -ETIMEDOUT;
        assert(iris_core_deinit(&core) == -ETIMEDOUT);
        assert(queues_live && core.fw_owned && frees == 0 && power_offs == 0);
        assert(sync_puts == 0 && idle_puts == (pm >= 0 ? 1U : 0U));
        shutdown_error = 0;
        assert(iris_core_deinit(&core) == 0 && !queues_live && !core.fw_owned);
        assert(frees == 1 && power_offs == (pm >= 0 ? 1U : 0U));
    }
    reset(core); assert(iris_core_init(&core) == 0);
    shutdown_error = -ETIMEDOUT;
    iris_sys_error_handler(&core.sys_error_handler.work);
    assert(allocs == 1 && frees == 0 && core.state == IRIS_CORE_ERROR);
    shutdown_error = 0;
    iris_sys_error_handler(&core.sys_error_handler.work);
    assert(allocs == 2 && frees == 1 && core.state == IRIS_CORE_INIT);
    assert(iris_core_deinit(&core) == 0);

    reset(core); response = 0;
    assert(iris_core_init(&core) == -ETIMEDOUT && core.fw_owned && queues_live);
    assert(iris_core_init(&core) == -EINVAL && core.state == IRIS_CORE_ERROR);
    assert(iris_core_deinit(&core) == 0 && !queues_live);

    reset(core); assert(iris_pm_suspend(&device) == 0 && iris_pm_resume(&device) == 0);
    assert(pm_calls == 0); core.fw_owned = true;
    assert(iris_core_init(&core) == -EBUSY && allocs == 0);
    assert(iris_pm_suspend(&device) == -EBUSY && iris_pm_resume(&device) == -EBUSY);
    core.state = IRIS_CORE_INIT; pm_error = failure;
    assert(iris_pm_suspend(&device) == failure && iris_pm_resume(&device) == failure);
    assert(pm_calls == 2);
}
CPP
"${CXX:-g++}" -std=c++20 -O2 -Wall -Wextra -Werror -ffile-prefix-map="$work"=. \
    "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Actual Iris PAS ownership, failed-stop DMA retention, recovery, PM and errno fixtures passed; no firmware execution\n'

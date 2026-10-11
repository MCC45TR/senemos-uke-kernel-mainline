#!/usr/bin/env bash
# Host fault injection into the prepared PAS functions; no firmware/device writes.
set -Eeuo pipefail
source_file=${1:?Pass the Wi-Fi-patched qcom_q6v5_pas.c}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
{
    cat <<'CPP'
#include <cassert>
#include <cerrno>
#include <climits>
#include <cstring>
#include <iterator>
#define ARRAY_SIZE(a) static_cast<int>(std::size(a))
#define IS_ERR(p) false
#define PTR_ERR(p) (-ENODEV)
constexpr int turbo = 384;
struct regulator { int vote = 0; bool enabled = false; };
struct regulator_bulk_data { const char *supply; regulator *consumer; };
struct device { bool cx = true, mx = true; void *of_node = this; };
struct qcom_pas {
    device *dev;
    device *proxy_pds[3] {};
    unsigned int proxy_pd_count = 0, proxy_regulator_level = turbo;
    regulator_bulk_data proxy_regs[2] {};
    regulator *cx_supply = nullptr, *px_supply = nullptr;
};
regulator rails[2];
int fail_vote = -1, bulk_error = 0, get_error = 0, errors = 0, gets = 0;
int pd_gets = 0, pd_puts = 0;
bool of_property_present(void *node, const char *name) {
    auto *d = static_cast<device *>(node);
    return !std::strcmp(name, "cx-supply") ? d->cx : d->mx;
}
int dev_err_probe(device *, int error, const char *) { return error; }
template<class... T> void dev_err(device *, const char *, T...) { ++errors; }
int regulator_set_voltage(regulator *r, int value, int maximum) {
    assert(maximum == INT_MAX);
    if (value && r == &rails[fail_vote == 1 ? 1 : 0] && fail_vote >= 0) return -EIO;
    r->vote = value;
    return 0;
}
int regulator_bulk_enable(int count, regulator_bulk_data *regs) {
    if (bulk_error) return bulk_error; // Regulator core unwinds failed enables.
    for (int i = 0; i < count; ++i) regs[i].consumer->enabled = true;
    return 0;
}
int regulator_bulk_disable(int count, regulator_bulk_data *regs) {
    if (bulk_error) return bulk_error; // Core restores enables after a failure.
    for (int i = 0; i < count; ++i) regs[i].consumer->enabled = false;
    return 0;
}
int devm_regulator_bulk_get(device *, int count, regulator_bulk_data *regs) {
    ++gets;
    if (get_error) return get_error;
    assert(count == 2 && !std::strcmp(regs[0].supply, "cx") && !std::strcmp(regs[1].supply, "mx"));
    for (int i = 0; i < count; ++i) regs[i].consumer = &rails[i];
    return 0;
}
regulator *devm_regulator_get_optional(device *, const char *) { return nullptr; }
int regulator_set_load(regulator *, int) { return 0; }
void dev_pm_genpd_set_performance_state(device *, int) {}
int pm_runtime_get_sync(device *) { ++pd_gets; return 0; }
void pm_runtime_put(device *) { ++pd_puts; }
void pm_runtime_put_noidle(device *) {}
CPP
    awk '/^static void qcom_pas_proxy_unvote/ { emit=1 } /^static int qcom_pas_shutdown_poll_decrypt/ { emit=0 } emit { print }' "$source_file"
    awk '/^static int qcom_pas_init_regulator/ { emit=1 } /^static int qcom_pas_pds_attach/ { emit=0 } emit { print }' "$source_file"
    cat <<'CPP'
int main() {
    device dev;
    qcom_pas pas{&dev};
    for (int missing = 0; missing < 2; ++missing) {
        dev.cx = missing != 0; dev.mx = missing != 1;
        assert(qcom_pas_init_regulator(&pas) == -EINVAL && gets == 0);
    }
    dev.cx = dev.mx = true;
    get_error = -517; // Kernel EPROBE_DEFER must propagate unchanged.
    assert(qcom_pas_init_regulator(&pas) == -517);
    get_error = 0;
    assert(qcom_pas_init_regulator(&pas) == 0);
    for (int stage = 0; stage < 3; ++stage) {
        fail_vote = stage < 2 ? stage : -1;
        bulk_error = stage == 2 ? -EIO : 0;
        assert(qcom_pas_proxy_enable(&pas) == -EIO);
        for (const auto &r : rails) assert(!r.enabled && r.vote == 0);
    }
    fail_vote = -1; bulk_error = 0;
    assert(qcom_pas_proxy_enable(&pas) == 0);
    for (const auto &r : rails) assert(r.enabled && r.vote == turbo);
    bulk_error = -EIO;
    qcom_pas_proxy_disable(&pas);
    assert(errors == 1);
    for (const auto &r : rails) assert(r.enabled && r.vote == turbo);
    bulk_error = 0;
    qcom_pas_proxy_disable(&pas);
    for (const auto &r : rails) assert(!r.enabled && r.vote == 0);
    pas.proxy_regulator_level = 0; pas.proxy_pd_count = 2;
    assert(qcom_pas_init_regulator(&pas) == 0);
    assert(qcom_pas_proxy_enable(&pas) == 0 && pd_gets == 2);
    qcom_pas_proxy_disable(&pas);
    assert(pd_puts == 2);
}
CPP
} > "$work/check.cpp"
grep -F 'Cliffs PAS requires AOP load-state QMP' "$source_file" >/dev/null
grep -F '"qcom,cliffs-wpss-pas", .data = &cliffs_wpss_resource' "$source_file" >/dev/null
awk '/^static const struct qcom_pas_data cliffs_wpss_resource/ { emit=1 } emit { print } emit && /^};/ { exit }' "$source_file" > "$work/match"
for value in '.crash_reason_smem = 626' '.pas_id = 6' '.minidump_id = 4' '.auto_boot = false' '.ssctl_id = 0x19' '.proxy_regulator_level = RPMH_REGULATOR_LEVEL_TURBO'; do
    grep -F "$value" "$work/match" >/dev/null
done
grep -F '"qcom,cliffs-adsp-pas", .data = &cliffs_adsp_resource' "$source_file" >/dev/null
awk '/^static const struct qcom_pas_data cliffs_adsp_resource/ { emit=1 } emit { print } emit && /^};/ { exit }' "$source_file" > "$work/adsp-match"
for value in '.crash_reason_smem = 423' '.firmware_name = "adsp.mdt"' '.dtb_firmware_name = "adsp_dtb.mdt"' '.pas_id = 1,' '.dtb_pas_id = 0x24' '.minidump_id = 5' '.auto_boot = false' '.load_state = "adsp"' '.ssr_name = "lpass"' '.ssctl_id = 0x14' '.smem_host_id = 2' '.proxy_regulator_level = RPMH_REGULATOR_LEVEL_TURBO'; do
    grep -F "$value" "$work/adsp-match" >/dev/null
done
g++ -std=c++20 -O2 -Wall -Wextra -Werror "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Cliffs WPSS/ADSP descriptors, proxy faults, required supplies, deferred provider, vote cleanup and legacy genpd path: passed\n'

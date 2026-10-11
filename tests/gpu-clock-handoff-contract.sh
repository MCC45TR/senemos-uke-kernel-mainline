#!/usr/bin/env bash
# Host faults in the actual probe/sync functions; no clock or device writes.
set -Eeuo pipefail
source_file=${1:?Pass the prepared gpucc-cliffs.c}
oem_file=${2:?Pass the pinned Uke OEM gpucc-cliffs.c}
[[ $(sha256sum "$oem_file" | cut -d ' ' -f1) == fdeacf41b361b8e589674aea99928397f7e9262a88913d8359a9f39f5a305a97 ]]
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
awk '/^static (const )?struct (freq_tbl|parent_map|clk_parent_data|qcom_reset_map|regmap_config)/ { emit=1 } /^static struct clk_regmap \*gpu_cc_cliffs_clocks/ { emit=1 } emit { print } emit && /^};/ { emit=0 }' "$source_file" > "$work/ported.tables"
awk '/^static (const )?struct (freq_tbl|parent_map|clk_parent_data|qcom_reset_map|regmap_config)/ { emit=1 } /^static struct clk_regmap \*gpu_cc_cliffs_clocks/ { emit=1 } emit { print } emit && /^};/ { emit=0 }' "$oem_file" > "$work/oem.tables"
test -s "$work/ported.tables"
cmp "$work/ported.tables" "$work/oem.tables"
if grep -E 'regmap_(write|update_bits)|pll.*configure' "$source_file"; then
    printf 'Probe-time clock writes are not admitted\n' >&2
    exit 1
fi
grep -F '.compatible = "qcom,cliffs-gpucc"' "$source_file" >/dev/null
{
    cat <<'CPP'
#include <cassert>
#include <cerrno>
struct device {};
struct platform_device { device dev; };
struct regmap {};
struct qcom_cc_desc {};
qcom_cc_desc gpu_cc_cliffs_desc;
regmap map;
int init_error, action_error, map_error, vote_error, probe_error, sync_error, unvote_error;
int votes, unvotes, deinits, probes;
void (*cleanup)(void *);
void *cleanup_data;
#define IS_ERR(p) (map_error != 0)
#define PTR_ERR(p) map_error
int clk_regulator_init(device *, const qcom_cc_desc *) { return init_error; }
void clk_regulator_deinit(const qcom_cc_desc *) { ++deinits; }
int clk_vdd_proxy_vote(device *, const qcom_cc_desc *) { ++votes; return vote_error; }
int clk_vdd_proxy_unvote(device *, const qcom_cc_desc *) { ++unvotes; return unvote_error; }
int devm_add_action_or_reset(device *, void (*fn)(void *), void *data) {
    if (action_error) { fn(data); return action_error; }
    cleanup = fn; cleanup_data = data; return 0;
}
regmap *qcom_cc_map(platform_device *, const qcom_cc_desc *) { return &map; }
int qcom_cc_really_probe(device *, const qcom_cc_desc *, regmap *) { ++probes; return probe_error; }
int clk_sync_state(device *) { return sync_error; }
void dev_err(device *, const char *) {}
void dev_info(device *, const char *) {}
void dev_warn(device *, const char *) {}
CPP
    # The kernel's implicit void-pointer conversion needs an explicit C++ cast.
    awk '/^static bool gpu_cc_cliffs_proxy_active/ { emit=1 } /^static struct platform_driver/ { emit=0 } emit { print }' "$source_file" | sed 's/struct device \*dev = data;/struct device *dev = static_cast<device *>(data);/'
    cat <<'CPP'
void reset() {
    assert(!gpu_cc_cliffs_proxy_active);
    init_error = action_error = map_error = vote_error = probe_error = sync_error = unvote_error = 0;
    votes = unvotes = deinits = probes = 0; cleanup = nullptr;
}
int main() {
    platform_device pdev;
    for (int stage = 0; stage < 5; ++stage) {
        reset();
        int *errors[] = {&init_error, &action_error, &map_error, &vote_error, &probe_error};
        *errors[stage] = stage == 0 ? -517 : -EIO;
        assert(gpu_cc_cliffs_probe(&pdev) == *errors[stage]);
        if (cleanup) cleanup(cleanup_data);
        assert(!gpu_cc_cliffs_proxy_active && deinits == (stage != 0));
        assert(votes == (stage >= 3) && unvotes == (stage == 4));
        assert(probes == (stage == 4));
    }
    reset();
    assert(gpu_cc_cliffs_probe(&pdev) == 0 && gpu_cc_cliffs_proxy_active);
    sync_error = -EAGAIN;
    gpu_cc_cliffs_sync_state(&pdev.dev);
    assert(gpu_cc_cliffs_proxy_active && unvotes == 0);
    sync_error = 0; unvote_error = -EIO;
    gpu_cc_cliffs_sync_state(&pdev.dev);
    assert(gpu_cc_cliffs_proxy_active && unvotes == 1);
    cleanup(cleanup_data);
    assert(gpu_cc_cliffs_proxy_active && deinits == 0);
    unvote_error = 0;
    gpu_cc_cliffs_sync_state(&pdev.dev);
    assert(!gpu_cc_cliffs_proxy_active);
    cleanup(cleanup_data);
    assert(deinits == 1);
}
CPP
} > "$work/check.cpp"
g++ -std=c++20 -O2 -Wall -Wextra -Werror "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Exact OEM tables, probe faults, deferred provider and retained handoff votes: passed\n'

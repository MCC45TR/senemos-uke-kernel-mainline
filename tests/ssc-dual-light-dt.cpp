// SPDX-License-Identifier: GPL-2.0-only
#include <libfdt.h>
#include <cassert>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>
#define UKE_INIT
#include "../src/boot/uke-dual-light.h"

static unsigned assertions;
#define CHECK(expr) do { assertions++; assert(expr); } while (0)

static int node(void *dt, const char *path)
{
    int n = fdt_path_offset(dt, path);
    assert(n >= 0);
    return n;
}

static std::vector<char> fixture()
{
    std::vector<char> dt(8192);
    assert(!fdt_create_empty_tree(dt.data(), dt.size()));
    const char compatible[] = "xiaomi,uke\0qcom,sm7675";
    assert(!fdt_setprop(dt.data(), 0, "compatible", compatible, sizeof compatible));
    assert(fdt_add_subnode(dt.data(), 0, "firmware") >= 0);
    assert(fdt_add_subnode(dt.data(), node(dt.data(), "/firmware"), "ssc-sensors") >= 0);
    assert(!fdt_setprop_string(dt.data(), node(dt.data(), "/firmware/ssc-sensors"), "compatible", "xiaomi,uke-ssc-iio"));
    const char *names[] = { "front-light", "rear-light" };
    const char *types[] = { "ambient_light", "ambient_light_back" };
    for (unsigned i = 0; i < 2; i++) {
        int n = fdt_add_subnode(dt.data(), node(dt.data(), "/firmware/ssc-sensors"), names[i]);
        assert(n >= 0);
        assert(!fdt_setprop_string(dt.data(), n, "qcom,ssc-datatype", types[i]));
    }
    assert(fdt_add_subnode(dt.data(), 0, "hall-lid") >= 0);
    assert(!fdt_setprop_string(dt.data(), node(dt.data(), "/hall-lid"), "compatible", "qcom,smp2p-switch"));
    assert(!fdt_setprop_u32(dt.data(), node(dt.data(), "/hall-lid"), "linux,code", 0));
    const fdt32_t gpio[] = { cpu_to_fdt32(10), cpu_to_fdt32(99), cpu_to_fdt32(1) };
    assert(!fdt_setprop(dt.data(), node(dt.data(), "/hall-lid"), "state-gpios", gpio, sizeof gpio));
    return dt;
}

int main()
{
    for (bool existing : {false, true}) {
        auto dt = fixture();
        if (existing)
            assert(!fdt_setprop_u32(dt.data(), node(dt.data(), "/hall-lid"), "phandle", 91));
        CHECK(!uke_dual_light_lid(dt.data()));
        auto handle = fdt_get_phandle(dt.data(), node(dt.data(), "/hall-lid"));
        CHECK(handle && (!existing || handle == 91));
        int bytes;
        const auto *ref = static_cast<const fdt32_t *>(fdt_getprop(dt.data(), node(dt.data(), "/firmware/ssc-sensors"), "lid-switch", &bytes));
        CHECK(ref && bytes == 4 && fdt32_to_cpu(*ref) == handle);
        auto saved = dt;
        CHECK(!uke_dual_light_lid(dt.data()) && saved == dt);
        const auto *gpio = static_cast<const fdt32_t *>(fdt_getprop(dt.data(), node(dt.data(), "/hall-lid"), "state-gpios", &bytes));
        CHECK(gpio && bytes == 12 && fdt32_to_cpu(gpio[1]) == 99 && fdt32_to_cpu(gpio[2]) == 1);
    }
    for (unsigned fault = 0; fault < 10; fault++) {
        auto dt = fixture();
        switch (fault) {
        case 0: assert(!fdt_setprop_string(dt.data(), 0, "compatible", "qcom,sm7675")); break;
        case 1: assert(!fdt_setprop_string(dt.data(), 0, "compatible", "xiaomi,uke")); break;
        case 2: assert(!fdt_setprop_string(dt.data(), node(dt.data(), "/firmware/ssc-sensors"), "compatible", "unrelated")); break;
        case 3: assert(!fdt_del_node(dt.data(), node(dt.data(), "/firmware/ssc-sensors/front-light"))); break;
        case 4: assert(!fdt_setprop_string(dt.data(), node(dt.data(), "/firmware/ssc-sensors/rear-light"), "qcom,ssc-datatype", "ambient_light")); break;
        case 5: assert(!fdt_setprop_string(dt.data(), node(dt.data(), "/hall-lid"), "compatible", "unrelated")); break;
        case 6: assert(!fdt_setprop_u32(dt.data(), node(dt.data(), "/hall-lid"), "linux,code", 1)); break;
        case 7: assert(!fdt_setprop_string(dt.data(), node(dt.data(), "/hall-lid"), "linux,code", "0")); break;
        case 8: assert(!fdt_setprop_u32(dt.data(), node(dt.data(), "/firmware/ssc-sensors"), "lid-switch", 91)); break;
        case 9: assert(!fdt_del_node(dt.data(), node(dt.data(), "/hall-lid"))); break;
        }
        auto before = dt;
        CHECK(uke_dual_light_lid(dt.data()) < 0 && dt == before);
    }
    std::printf("Actual dual-light DT: %u checks passed; exact board/type/lid admission, existing handles, idempotence and refusal-before-write.\n", assertions);
}

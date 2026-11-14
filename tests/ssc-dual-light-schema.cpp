// SPDX-License-Identifier: GPL-2.0-only
// COPR-only synthetic input; execute the actual board metadata/link producers.
#include <libfdt.h>
#include <cassert>
#include <climits>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>
#define UKE_INIT
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#include "uke-hardware.h"
#include "uke-dual-light.h"

static int node(void *dt, const char *path)
{
    int value = fdt_path_offset(dt, path);
    assert(value >= 0);
    return value;
}

static void save(const std::vector<char> &dt, const std::string &path)
{
    FILE *output = std::fopen(path.c_str(), "wbx");
    assert(output);
    size_t bytes = static_cast<size_t>(fdt_totalsize(dt.data()));
    assert(std::fwrite(dt.data(), 1, bytes, output) == bytes);
    assert(!std::fclose(output));
}

int main(int argc, char **argv)
{
    assert(argc == 2);
    std::vector<char> dt(65536);
    assert(!fdt_create_empty_tree(dt.data(), dt.size()));
    const char compatible[] = "xiaomi,uke\0qcom,sm7675";
    assert(!fdt_setprop(dt.data(), 0, "compatible", compatible, sizeof compatible));
    for (const char *name : {"firmware", "cpus", "soc", "hall-lid"})
        assert(fdt_add_subnode(dt.data(), 0, name) >= 0);
    for (unsigned i = 0; i < 8; i++) {
        char name[32];
        std::snprintf(name, sizeof name, "cpu@%x", i * 0x100);
        assert(fdt_add_subnode(dt.data(), node(dt.data(), "/cpus"), name) >= 0);
    }
    assert(fdt_add_subnode(dt.data(), node(dt.data(), "/soc"), "remoteproc-adsp@03000000") >= 0);
    assert(!fdt_setprop_u32(dt.data(), node(dt.data(), "/soc/remoteproc-adsp@03000000"), "phandle", 23));
    assert(!fdt_setprop_string(dt.data(), node(dt.data(), "/hall-lid"), "compatible", "qcom,smp2p-switch"));
    assert(!fdt_setprop_u32(dt.data(), node(dt.data(), "/hall-lid"), "linux,code", 0));
    assert(!uke_hardware_names(dt.data()));
    const std::string directory(argv[1]);
    save(dt, directory + "/unlinked.dtb");
    assert(!uke_dual_light_lid(dt.data()));
    save(dt, directory + "/linked.dtb");
    auto previous = dt;
    assert(!uke_dual_light_lid(dt.data()) && previous == dt);
    std::puts("Actual board metadata plus dual-light link serialized from synthetic input; no private DT or physical acceptance.");
}

#!/usr/bin/env bash
# Host-only actual mapper, queue allocator and boot setup with fake DMA/MMIO.
set -Eeuo pipefail
iris=${1:?Pass the prepared Iris directory}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/include/linux"
cat > "$work/include/linux/types.h" <<'H'
#pragma once
#include <cstddef>
#include <cstdint>
using u8 = std::uint8_t;
using u16 = std::uint16_t;
using u32 = std::uint32_t;
using u64 = std::uint64_t;
using __le32 = u32;
using dma_addr_t = u64;
using phys_addr_t = u64;
H
cat > "$work/include/linux/align.h" <<'H'
#pragma once
#define ALIGN(value, align) (((value) + (decltype(value))(align) - 1) & ~((decltype(value))(align) - 1))
#define IS_ALIGNED(value, align) (!((value) & ((align) - 1)))
H
cat > "$work/include/linux/sizes.h" <<'H'
#pragma once
#define SZ_4K 0x1000U
#define SZ_1M 0x100000U
H
cat > "$work/check.cpp" <<'CPP'
#include <algorithm>
#include <array>
#include <cassert>
#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <string>
#include <utility>
#include <vector>
#include "iris_hfi_queue.h"
#include "iris_fw_mmap.h"
#define BIT(n) (u32{1} << (n))
#include "iris_vpu_register_defines.h"
#define DMA_BIT_MASK(n) ((u64{1} << (n)) - 1)
#define check_add_overflow(a, b, result) __builtin_add_overflow((a), (b), (result))
#define READ_ONCE(value) (value)
#define min(a, b) std::min((a), (b))
#define max(a, b) std::max((a), (b))
struct device { u64 mask; } device;
struct platform_device {} pdev;
struct resource { u64 start, end; };
struct iommu_domain { int type; } domain;
struct vpu_ops { void (*program_bootup_registers)(struct iris_core *); };
struct platform_data { bool fw_mmap; const struct vpu_ops *vpu_ops; };
struct firmware_data { u32 core_arch; };
struct iris_core {
    struct device *dev;
    u8 *reg_base;
    bool fw_owned;
    struct iris_fw_mmap fw_mmap;
    void *iface_q_table_vaddr, *sfr_vaddr;
    dma_addr_t iface_q_table_daddr, sfr_daddr;
    const platform_data *iris_platform_data;
    const firmware_data *iris_firmware_data;
    iris_iface_q_info command_queue, message_queue, debug_queue;
};
constexpr int IOMMU_DOMAIN_DMA = 1, IOMMU_DOMAIN_DMA_FQ = 2;
constexpr unsigned IORESOURCE_MEM = 1, DMA_BIDIRECTIONAL = 0, GFP_KERNEL = 0;
constexpr unsigned DMA_ATTR_WRITE_COMBINE = 1;
constexpr dma_addr_t DMA_MAPPING_ERROR = ~dma_addr_t{0};
static std::array<u8, 0xf0000> registers;
static std::array<resource, 3> resources;
static std::array<dma_addr_t, 3> mapped_addresses;
static std::vector<std::pair<dma_addr_t, std::size_t>> live_maps;
struct allocation { void *cpu; dma_addr_t dma; std::size_t size; };
static std::vector<allocation> allocations;
static std::vector<dma_addr_t> unmapped;
static std::vector<std::pair<unsigned, u32>> writes;
static unsigned alloc_calls, free_calls, map_calls, barriers, callbacks, warnings;
static unsigned fail_alloc, fail_map;
static int missing_resource;
static bool domain_present;
static dma_addr_t next_buffer;
static platform_device *to_platform_device(struct device *) { return &pdev; }
static iommu_domain *iommu_get_domain_for_dev(struct device *) {
    return domain_present ? &domain : nullptr;
}
static resource *platform_get_resource_byname(platform_device *, unsigned type, const char *name) {
    assert(type == IORESOURCE_MEM);
    const char *names[]{"aon", "fence", "qtimer"};
    for (int i = 0; i < 3; ++i)
        if (!std::strcmp(names[i], name)) return i == missing_resource ? nullptr : &resources[i];
    assert(false); return nullptr;
}
static u64 resource_size(resource *r) { return r->end-r->start+1; }
static u64 dma_get_mask(struct device *d) { return d->mask; }
static void *dma_alloc_attrs(struct device *, std::size_t size, dma_addr_t *addr,
                             unsigned gfp, unsigned attrs) {
    assert(gfp == GFP_KERNEL && attrs == DMA_ATTR_WRITE_COMBINE);
    if (++alloc_calls == fail_alloc) return nullptr;
    void *cpu = std::malloc(size); assert(cpu); std::memset(cpu, 0xa5, size);
    *addr = next_buffer; next_buffer += 0x1000000;
    allocations.push_back({cpu, *addr, size}); return cpu;
}
static void dma_free_attrs(struct device *, std::size_t size, void *cpu,
                           dma_addr_t addr, unsigned attrs) {
    assert(attrs == DMA_ATTR_WRITE_COMBINE);
    assert(live_maps.empty());
    auto it = std::find_if(allocations.begin(), allocations.end(),
        [=](const allocation &a) { return a.cpu == cpu && a.dma == addr && a.size == size; });
    assert(it != allocations.end()); allocations.erase(it); std::free(cpu); ++free_calls;
}
static dma_addr_t dma_map_resource(struct device *, phys_addr_t phys, std::size_t size,
                                   unsigned dir, unsigned attrs) {
    assert(size == SZ_4K && dir == DMA_BIDIRECTIONAL && attrs == 0 && map_calls < 3);
    assert(phys == resources[map_calls].start);
    const unsigned index = map_calls++;
    if (map_calls == fail_map) return DMA_MAPPING_ERROR;
    live_maps.emplace_back(mapped_addresses[index], size); return mapped_addresses[index];
}
static bool dma_mapping_error(struct device *, dma_addr_t addr) { return addr == DMA_MAPPING_ERROR; }
static void dma_unmap_resource(struct device *, dma_addr_t addr, std::size_t size,
                               unsigned dir, unsigned attrs) {
    assert(dir == DMA_BIDIRECTIONAL && attrs == 0);
    auto it = std::find(live_maps.begin(), live_maps.end(), std::pair{addr, size});
    assert(it != live_maps.end()); live_maps.erase(it); unmapped.push_back(addr);
}
static u32 cpu_to_le32(u32 value) { return value; }
static void dma_wmb() { ++barriers; }
static bool warn_on(bool value) { if (value) ++warnings; return value; }
#define WARN_ON(value) warn_on(value)
#define dev_err(...) ((void)0)
static void writel(u32 value, void *address) {
    auto offset = static_cast<u8 *>(address)-registers.data();
    assert(offset >= 0 && offset < static_cast<long>(registers.size()));
    writes.emplace_back(static_cast<unsigned>(offset), value);
}
static void strscpy(char *to, const char *from, std::size_t size) {
    std::strncpy(to, from, size); to[size-1] = 0;
}
CPP
{
sed '/^#include /d' "$iris/iris_fw_mmap.c"
# C++ needs an explicit cast for this unchanged C void-pointer assignment.
sed -n '/^static void iris_hfi_queue_set_header/,$p' "$iris/iris_hfi_queue.c" |
    sed 's/q_tbl_hdr = core->iface_q_table_vaddr;/q_tbl_hdr = (struct iris_hfi_queue_table_header *)core->iface_q_table_vaddr;/'
cat <<'CPP'
#define UC_REGION_ADDR FW_UC_REGION_ADDR
#define UC_REGION_SIZE FW_UC_REGION_SIZE
#define QTBL_ADDR FW_QTBL_ADDR
#define QTBL_INFO FW_QTBL_INFO
#define QTBL_ENABLE BIT(0)
#define SFR_ADDR FW_SFR_ADDR
CPP
awk '/^static int iris_vpu_setup_ucregion_memory_map\(/ { emit=1 } emit { print } emit && /^}/ { exit }' \
    "$iris/iris_vpu_common.c"
cat <<'CPP'
static void legacy_callback(iris_core *) { ++callbacks; }
static const struct vpu_ops ops{legacy_callback};
static platform_data platform{true, &ops};
static firmware_data firmware{1};
static void reset(iris_core &core) {
    assert(allocations.empty() && live_maps.empty());
    core = {}; core.dev = &device; core.reg_base = registers.data();
    core.iris_platform_data = &platform; core.iris_firmware_data = &firmware;
    platform.fw_mmap = true; firmware.core_arch = 1; device.mask = 0xdfffffff;
    resources = {{{0x1000000, 0x1000fff}, {0x2000000, 0x2000fff}, {0x3000000, 0x3000fff}}};
    mapped_addresses = {0xd1002000, 0xd1001000, 0xd1000000};
    unmapped.clear(); writes.clear();
    alloc_calls = free_calls = map_calls = barriers = callbacks = warnings = 0;
    fail_alloc = fail_map = 0; missing_resource = -1;
    domain_present = true; domain.type = IOMMU_DOMAIN_DMA; next_buffer = 0xc1000000;
}
static __le32 *payload(iris_core &core) {
    return reinterpret_cast<__le32 *>(static_cast<u8 *>(core.iface_q_table_vaddr) +
                                     iris_hfi_queue_size() + SFR_SIZE);
}
static void check_payload(iris_core &core) {
    for (unsigned i = 0; i < SZ_4K/sizeof(u32); ++i) {
        u32 expected = i == 0 ? 1 : 0;
        for (unsigned j = 0; j < 3; ++j) {
            const unsigned slots[]{11, 19, 21};
            if (i == slots[j]) expected = mapped_addresses[j];
            if (i == slots[j]+1) expected = SZ_4K;
        }
        assert(payload(core)[i] == expected);
    }
}
static void empty(const iris_core &core) {
    assert(allocations.empty() && live_maps.empty());
    assert(!core.iface_q_table_vaddr && !core.iface_q_table_daddr &&
           !core.sfr_vaddr && !core.sfr_daddr && !core.fw_mmap.shared_size);
}
int main() {
    iris_core core;
    reset(core); assert(iris_hfi_queues_init(&core) == 0);
    assert(alloc_calls == 1 && map_calls == 3 && allocations[0].size == 4*SZ_1M);
    assert(core.sfr_daddr == core.iface_q_table_daddr + iris_hfi_queue_size());
    assert(*static_cast<u32 *>(core.sfr_vaddr) == SFR_SIZE);
    assert(core.command_queue.qhdr && core.message_queue.qhdr && core.debug_queue.qhdr);
    check_payload(core);
    assert(iris_hfi_queues_init(&core) == -EBUSY && alloc_calls == 1);
    assert(iris_vpu_setup_ucregion_memory_map(&core) == -EINVAL && writes.empty());
    core.fw_owned = true;
    std::array<u32, SZ_4K/sizeof(u32)> original_payload;
    std::copy_n(payload(core), original_payload.size(), original_payload.begin());
    std::memset(payload(core), 0xcc, SZ_4K);
    assert(iris_vpu_setup_ucregion_memory_map(&core) == -EINVAL && writes.empty());
    assert(barriers == 1 && payload(core)[0] == 0xcccccccc);
    std::copy(original_payload.begin(), original_payload.end(), payload(core));
    assert(iris_vpu_setup_ucregion_memory_map(&core) == 0 && barriers == 2);
    check_payload(core);
    const std::vector<std::pair<unsigned, u32>> expected{
        {0xa0064, 0xc1000000}, {0xa0068, 4*SZ_1M}, {0xa0054, 0xc1000000},
        {0xa0050, 1}, {0xa0060, 0xc1000000+iris_hfi_queue_size()+SFR_SIZE},
        {0xa0024, 0xd1000000}, {0xa0028, 3*SZ_4K},
        {0xa005c, 0xc1000000+iris_hfi_queue_size()+1}};
    assert(writes == expected && callbacks == 0);
    iris_hfi_queues_deinit(&core); assert(free_calls == 0 && live_maps.size() == 3);
    iris_fw_mmap_deinit(&core); assert(warnings == 1 && free_calls == 0);
    core.fw_owned = false; iris_hfi_queues_deinit(&core); empty(core);
    assert((unmapped == std::vector<dma_addr_t>{0xd1000000, 0xd1001000, 0xd1002000}));
    assert(free_calls == 1 && !core.command_queue.qhdr);
    iris_hfi_queues_deinit(&core); assert(free_calls == 1);

    for (int absent = 0; absent < 3; ++absent) {
        reset(core); missing_resource = absent;
        assert(iris_hfi_queues_init(&core) == -EINVAL && alloc_calls == 0); empty(core);
    }
    for (int kind = 0; kind < 4; ++kind) {
        reset(core);
        if (kind == 0) domain_present = false; else domain.type = kind == 1 ? 0 : 3;
        assert(iris_hfi_queues_init(&core) == -ENODEV && alloc_calls == 0); empty(core);
    }
    for (int bad = 0; bad < 4; ++bad) {
        reset(core);
        if (bad == 0) --resources[1].end;
        if (bad == 1) ++resources[1].start, ++resources[1].end;
        if (bad == 2) resources[1] = resources[0];
        if (bad == 3) resources[1].end = resources[1].start-1;
        assert(iris_hfi_queues_init(&core) == -EINVAL && alloc_calls == 0); empty(core);
    }
    reset(core); fail_alloc = 1;
    assert(iris_hfi_queues_init(&core) == -ENOMEM && map_calls == 0); empty(core);
    for (unsigned fail = 1; fail <= 3; ++fail) {
        reset(core); fail_map = fail;
        assert(iris_hfi_queues_init(&core) == -EIO && free_calls == 1); empty(core);
        assert(unmapped.size() == fail-1);
        for (unsigned i = 0; i < fail-1; ++i) assert(unmapped[i] == mapped_addresses[fail-2-i]);
    }
    for (dma_addr_t bad : {dma_addr_t{0}, dma_addr_t{0xc1000001}, dma_addr_t{0x100000000},
                           dma_addr_t{0xe0000000}, dma_addr_t{0xdffff000},
                           dma_addr_t{0xfffffffffffff000}}) {
        reset(core); next_buffer = bad;
        assert(iris_hfi_queues_init(&core) == -ERANGE && free_calls == 1 && map_calls == 0);
        empty(core);
    }
    for (dma_addr_t bad : {dma_addr_t{0}, dma_addr_t{0xd1005000}, dma_addr_t{0xd1002001},
                           dma_addr_t{0x100000000}, dma_addr_t{0xe0000000}, dma_addr_t{0xc1000000}}) {
        reset(core); mapped_addresses[0] = bad;
        assert(iris_hfi_queues_init(&core) < 0 && free_calls == 1 && unmapped.size() == 3);
        empty(core);
    }
    for (int corrupt = 0; corrupt < 5; ++corrupt) {
        reset(core); assert(iris_hfi_queues_init(&core) == 0); core.fw_owned = true;
        const auto saved = core.fw_mmap; const auto sfr = core.sfr_daddr;
        if (corrupt == 0) core.fw_mmap.regions[0].daddr = core.fw_mmap.regions[1].daddr;
        if (corrupt == 1) core.fw_mmap.regions[0].size = 0;
        if (corrupt == 2) core.fw_mmap.shared_size -= SZ_4K;
        if (corrupt == 3) ++core.sfr_daddr;
        if (corrupt == 4) firmware.core_arch = SZ_4K;
        assert(iris_vpu_setup_ucregion_memory_map(&core) < 0 && writes.empty());
        core.fw_mmap = saved; core.sfr_daddr = sfr; core.fw_owned = false;
        iris_hfi_queues_deinit(&core); empty(core);
    }
    reset(core); domain.type = IOMMU_DOMAIN_DMA_FQ;
    assert(iris_hfi_queues_init(&core) == 0); iris_hfi_queues_deinit(&core); empty(core);
    reset(core); core.fw_owned = true;
    assert(iris_hfi_queues_init(&core) == -EBUSY && alloc_calls == 0);
    for (unsigned fail = 0; fail <= 2; ++fail) {
        reset(core); platform.fw_mmap = false; domain_present = false; fail_alloc = fail;
        if (fail) {
            assert(iris_hfi_queues_init(&core) == -ENOMEM);
            assert(free_calls == (fail == 2 ? 1U : 0U)); empty(core);
        } else {
            assert(iris_hfi_queues_init(&core) == 0 && alloc_calls == 2 && map_calls == 0);
            assert(iris_vpu_setup_ucregion_memory_map(&core) == 0 && callbacks == 1);
            assert(writes.size() == 5);
            iris_hfi_queues_deinit(&core); empty(core); assert(free_calls == 2);
        }
    }
}
CPP
} >> "$work/check.cpp"
# The unchanged upstream queue-header helper retains an unused core parameter.
"${CXX:-g++}" -std=c++20 -O2 -Wall -Wextra -Werror -Wno-unused-parameter \
    -ffile-prefix-map="$work"=. -I "$work/include" -I "$iris" "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Actual Iris mmap allocation, MMIO ownership, payload, boot refusal and legacy queue fixtures passed; no hardware access\n'

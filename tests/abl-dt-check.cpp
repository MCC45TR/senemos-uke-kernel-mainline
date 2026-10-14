// SPDX-License-Identifier: GPL-2.0-only
// Host-only contract for the exact C transform and kernel libfdt implementation.
#include <libfdt.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <cerrno>
#include <cstring>
#include <iostream>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>
extern "C" int uke_abl_transform(void *, size_t, const void *, size_t,
                                 void *, size_t, void *, size_t);
using Bytes = std::vector<unsigned char>;
static Bytes read_blob(const char *path) {
    const int fd = open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
    struct stat st {};
    if (fd < 0 || fstat(fd, &st) || !S_ISREG(st.st_mode) || st.st_size < 40 || st.st_size > 2*1024*1024)
        throw std::runtime_error("Invalid bounded regular input");
    Bytes bytes(st.st_size);
    size_t done = 0;
    while (done < bytes.size()) {
        const auto count = read(fd, bytes.data()+done, bytes.size()-done);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) throw std::runtime_error("Short input read");
        done += count;
    }
    close(fd);
    return bytes;
}
static void preserve_node(const Bytes &before, const Bytes &after, const std::string &path,
                          bool recursive) {
    const int a = fdt_path_offset(before.data(), path.c_str());
    const int b = fdt_path_offset(after.data(), path.c_str());
    if (a < 0 || b < 0) throw std::runtime_error("Preserved node missing");
    int offset;
    fdt_for_each_property_offset(offset, before.data(), a) {
        int length, other_length;
        const char *name = nullptr;
        const void *value = fdt_getprop_by_offset(before.data(), offset, &name, &length);
        const void *other = fdt_getprop(after.data(), b, name, &other_length);
        if (!std::strcmp(name, "function")) {
            static const std::map<std::string, std::string> corrected = {
                {"/soc/pinctrl@f000000/qupv3_se3_spi_pins/qupv3_se3_spi_clk_active/mux", "qup0_se3_l2"},
                {"/soc/pinctrl@f000000/fs19xx_irq_active_top_left/mux", "gpio"},
                {"/soc/pinctrl@f000000/fs19xx_irq_sleep_top_left/mux", "gpio"},
                {"/soc/pinctrl@f000000/fs19xx_irq_active_top_right/mux", "gpio"},
                {"/soc/pinctrl@f000000/fs19xx_irq_sleep_top_right/mux", "gpio"},
                {"/soc/pinctrl@f000000/fs19xx_irq_active_bottom_left/mux", "gpio"},
                {"/soc/pinctrl@f000000/fs19xx_irq_sleep_bottom_left/mux", "gpio"},
                {"/soc/pinctrl@f000000/fs19xx_irq_active_bottom_right/mux", "gpio"},
                {"/soc/pinctrl@f000000/fs19xx_irq_sleep_bottom_right/mux", "gpio"},
            };
            const auto expected = corrected.find(path);
            if (expected != corrected.end()) {
                if (!other || other_length != static_cast<int>(expected->second.size()+1) ||
                    std::memcmp(other, expected->second.c_str(), other_length))
                    throw std::runtime_error("OEM mux-name correction missing");
                continue;
            }
        }
        if (!value || !other || length != other_length || std::memcmp(value, other, length))
            throw std::runtime_error("Preserved DT property changed: " + path + "/" + name);
    }
    if (recursive) {
        int child;
        fdt_for_each_subnode(child, before.data(), a) {
            preserve_node(before, after, path + "/" + fdt_get_name(before.data(), child, nullptr), true);
        }
    }
}
static void check_adreno732(const Bytes &dt) {
    const auto node = [&](const char *path) {
        const int n = fdt_path_offset(dt.data(), path);
        if (n < 0) throw std::runtime_error("GPU resource node missing");
        return n;
    };
    const auto cells = [&](int n, const char *name, std::initializer_list<uint32_t> expected) {
        int length = 0;
        const auto *p = static_cast<const fdt32_t *>(fdt_getprop(dt.data(), n, name, &length));
        if (!p || length != static_cast<int>(expected.size() * sizeof(*p)))
            throw std::runtime_error("GPU resource length differs");
        for (const auto value : expected)
            if (fdt32_to_cpu(*p++) != value) throw std::runtime_error("GPU resource value differs");
    };
    const int gpu = node("/soc/qcom,kgsl-3d0@3d00000");
    const int gmu = node("/soc/qcom,gmu@3d69000");
    const int cc = node("/soc/clock-controller@3d90000");
    const int smmu = node("/soc/kgsl-smmu@3da0000");
    const uint32_t gccp = fdt_get_phandle(dt.data(), node("/soc/clock-controller@100000"));
    const uint32_t ccp = fdt_get_phandle(dt.data(), cc), sp = fdt_get_phandle(dt.data(), smmu);
    if (!ccp || !sp || fdt_node_check_compatible(dt.data(), gpu, "qcom,adreno-43030b00") ||
        fdt_node_check_compatible(dt.data(), gmu, "qcom,adreno-gmu-732"))
        throw std::runtime_error("Exact Adreno 732 identity missing");
    cells(cc, "#power-domain-cells", {1});
    cells(gpu, "reg", {0x3d00000, 0x40000, 0x3d9e000, 0x1000, 0x3d61000, 0x800});
    cells(gmu, "reg", {0x3d68000, 0x37000, 0x3d50000, 0x10000, 0xb280000, 0x10000});
    cells(gpu, "iommus", {sp, 0, 0});
    cells(gpu, "clocks", {gccp, 32, gccp, 33, ccp, 2});
    cells(gmu, "iommus", {sp, 5, 0});
    cells(gmu, "power-domains", {ccp, 0, ccp, 1});
    cells(smmu, "reg", {0x3da0000, 0x40000});
    cells(smmu, "power-domains", {ccp, 0});
    const int opp = node("/soc/qcom,kgsl-3d0@3d00000/opp-table/opp-255000000");
    cells(opp, "opp-hz", {0, 255000000});
    cells(opp, "opp-level", {56});
    cells(opp, "opp-peak-kBps", {2136718});
    if (fdt_next_subnode(dt.data(), opp) != -FDT_ERR_NOTFOUND)
        throw std::runtime_error("Unqualified GPU operating point present");
}
int main(int argc, char **argv) {
    try {
        if (argc != 5) throw std::runtime_error("Usage: abl-dt-check INPUT UFS USB NEW_OUTPUT");
        auto input = read_blob(argv[1]), saved = input;
        auto ufs = read_blob(argv[2]), usb = read_blob(argv[3]);
        Bytes output(2*1024*1024);
        const int result = uke_abl_transform(output.data(), output.size(), input.data(), input.size(),
                                            ufs.data(), ufs.size(), usb.data(), usb.size());
        if (input != saved) throw std::runtime_error("Original FDT modified");
        if (!result) { std::cout << "Foreign DT unchanged\n"; return 3; }
        if (result != 1) throw std::runtime_error("DT admission rejected: " + std::to_string(result));
        if (fdt_check_full(output.data(), output.size())) throw std::runtime_error("Invalid result FDT");
        check_adreno732(output);
        const int chosen = fdt_path_offset(output.data(), "/chosen");
        const char *stdout_path = static_cast<const char *>(fdt_getprop(output.data(), chosen, "stdout-path", nullptr));
        const int framebuffer = stdout_path ? fdt_path_offset(output.data(), stdout_path) : -1;
        int bl_length;
        const auto *bl = static_cast<const fdt32_t *>(fdt_getprop(output.data(), framebuffer, "backlight", &bl_length));
        const int primary = fdt_path_offset(output.data(), "/soc/qcom,qupv3_0_geni_se@ac0000/i2c@a80000/ktz8866@11");
        if (!bl || bl_length != 4 || fdt_node_offset_by_phandle(output.data(), fdt32_to_cpu(*bl)) != primary)
            throw std::runtime_error("Firmware framebuffer backlight link is not the Uke primary");
        const int usb_node = fdt_path_offset(output.data(), "/soc/ssusb@a600000");
        const char *psy = static_cast<const char *>(fdt_getprop(output.data(), usb_node, "usb-psy-name", nullptr));
        const int slim = fdt_path_offset(output.data(), "/soc/slim@6C40000");
        const char *slim_status = static_cast<const char *>(fdt_getprop(output.data(), slim, "status", nullptr));
        if (!psy || std::strcmp(psy, "qcom-battmgr-usb") || !slim_status || std::strcmp(slim_status, "disabled"))
            throw std::runtime_error("USB supply link or unqualified SLIM containment missing");
        const int battery = fdt_path_offset(output.data(), "/pmic-glink");
        if (battery < 0 || fdt_node_check_compatible(output.data(), battery, "xiaomi,uke-pmic-glink") ||
            fdt_first_subnode(output.data(), battery) != -FDT_ERR_NOTFOUND)
            throw std::runtime_error("Battery-only upstream GLINK endpoint missing or has legacy children");
        for (const char *path : {"/soc/qcom,pmic_glink", "/soc/qcom,pmic_glink_log"}) {
            const int legacy = fdt_path_offset(output.data(), path);
            const char *status = static_cast<const char *>(fdt_getprop(output.data(), legacy, "status", nullptr));
            if (!status || std::strcmp(status, "disabled"))
                throw std::runtime_error("Legacy GLINK containment changed");
        }
        int node;
        fdt_for_each_subnode(node, input.data(), 0) {
            const std::string name = fdt_get_name(input.data(), node, nullptr);
            if (name == "memory" || name.rfind("memory@", 0) == 0)
                preserve_node(input, output, "/" + name, true);
        }
        preserve_node(input, output, "/reserved-memory", true);
        for (node = fdt_next_node(input.data(), -1, nullptr); node >= 0;
             node = fdt_next_node(input.data(), node, nullptr)) {
            if (!fdt_getprop(input.data(), node, "gpio-controller", nullptr)) continue;
            char path[4096];
            if (fdt_get_path(input.data(), node, path, sizeof(path)))
                throw std::runtime_error("GPIO controller path is too long");
            preserve_node(input, output, path, true);
        }
        for (int i=0; i<fdt_num_mem_rsv(input.data()); ++i) {
            uint64_t aa, as, ba, bs;
            if (fdt_get_mem_rsv(input.data(), i, &aa, &as) || fdt_get_mem_rsv(output.data(), i, &ba, &bs) ||
                aa != ba || as != bs) throw std::runtime_error("FDT reserve map changed");
        }
        if (fdt_num_mem_rsv(input.data()) != fdt_num_mem_rsv(output.data()))
            throw std::runtime_error("FDT reserve count changed");
        const int fd = open(argv[4], O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
        if (fd < 0) throw std::runtime_error("Output must be new");
        output.resize(fdt_totalsize(output.data()));
        size_t done = 0;
        while (done < output.size()) {
            const auto count = write(fd, output.data()+done, output.size()-done);
            if (count < 0 && errno == EINTR) continue;
            if (count <= 0) throw std::runtime_error("Short output write");
            done += count;
        }
        if (fsync(fd) || close(fd)) throw std::runtime_error("Output flush failed");
        std::cout << "Uke DT admitted; input, RAM, reservations and GPIO-controller properties preserved; nine mux names corrected\n";
        return 0;
    } catch (const std::exception &error) { std::cerr << error.what() << '\n'; return 1; }
}

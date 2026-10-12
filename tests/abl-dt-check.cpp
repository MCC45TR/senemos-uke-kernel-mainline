// SPDX-License-Identifier: GPL-2.0-only
// Host-only contract for the exact C transform and kernel libfdt implementation.
#include <libfdt.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <cerrno>
#include <cstring>
#include <iostream>
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
        if (!value || !other || length != other_length || std::memcmp(value, other, length))
            throw std::runtime_error("Bootloader memory or reservation changed");
    }
    if (recursive) {
        int child;
        fdt_for_each_subnode(child, before.data(), a) {
            preserve_node(before, after, path + "/" + fdt_get_name(before.data(), child, nullptr), true);
        }
    }
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
        std::cout << "Uke DT admitted; original input, RAM, reserved nodes and reserve map preserved\n";
        return 0;
    } catch (const std::exception &error) { std::cerr << error.what() << '\n'; return 1; }
}

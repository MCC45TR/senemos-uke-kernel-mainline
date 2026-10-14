// SPDX-License-Identifier: GPL-2.0-only
// Host-only extraction of Uke OEM panel packets and bonded display timings.
#include <libfdt.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <cerrno>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

using Blob = std::vector<unsigned char>;
static Blob read_blob(const char *path) {
    const int fd = open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK);
    struct stat st {};
    if (fd < 0) throw std::runtime_error("Cannot open panel DT");
    if (fstat(fd, &st) || !S_ISREG(st.st_mode) || st.st_size < 40 || st.st_size > 2*1024*1024) {
        close(fd); throw std::runtime_error("Panel DT must be a bounded regular file");
    }
    Blob data(st.st_size);
    size_t off = 0;
    while (off < data.size()) {
        const auto n = read(fd, data.data()+off, data.size()-off);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) { close(fd); throw std::runtime_error("Truncated panel DT"); }
        off += n;
    }
    close(fd);
    if (fdt_check_full(data.data(), data.size())) throw std::runtime_error("Malformed panel DT");
    return data;
}
static uint32_t cell(const Blob &dt, int node, const char *name) {
    int size;
    const auto *v = static_cast<const fdt32_t *>(fdt_getprop(dt.data(), node, name, &size));
    if (!v || size != 4) throw std::runtime_error(std::string("Invalid panel cell: ")+name);
    return fdt32_to_cpu(*v);
}
static void require(const Blob &dt, int node, const char *name, uint32_t expected) {
    if (cell(dt, node, name) != expected) throw std::runtime_error(std::string("Unexpected panel value: ")+name);
}
static unsigned commands(std::ostream &out, const Blob &dt, int node,
                         const char *property, const std::string &name) {
    int size;
    const auto *data = static_cast<const unsigned char *>(fdt_getprop(dt.data(), node, property, &size));
    if (!data || size <= 0 || size > 65536) throw std::runtime_error("Missing bounded panel packet stream");
    out << "static const struct o82_command " << name << "[] = {\n";
    unsigned count = 0;
    for (size_t pos=0; pos < static_cast<size_t>(size); ++count) {
        if (size-pos < 7) throw std::runtime_error("Truncated DSI packet header");
        const auto *p = data+pos;
        const unsigned length = (p[5] << 8) | p[6];
        if (!length || length > 4096 || pos+7+length > static_cast<size_t>(size) ||
            (p[0] != 0x05 && p[0] != 0x15 && p[0] != 0x39) || p[1] > 1 || p[2] ||
            (p[3] != 0 && p[3] != 0x40) || p[4] > 200)
            throw std::runtime_error("Unsupported or truncated DSI packet");
        out << "\t{ " << unsigned(p[0]) << ", " << unsigned(p[1]) << ", 0, "
            << unsigned(p[3]) << ", " << unsigned(p[4]) << ", " << length << ", (const u8[]) { ";
        for (unsigned i=0; i<length; ++i) out << "0x" << std::hex << unsigned(p[7+i]) << std::dec << ", ";
        out << "} },\n";
        pos += 7+length;
    }
    out << "};\n";
    return count;
}
int main(int argc, char **argv) {
    try {
        if (argc != 2) throw std::runtime_error("Usage: o82-data UKE_OEM_DTB");
        const auto dt = read_blob(argv[1]);
        std::ostringstream out;
        out << "/* SPDX-License-Identifier: GPL-2.0-only */\n"
               "/* Generated from the pinned Uke OEM DT; packet types and delays retained. */\n";
        const char *suffixes[] = {"36_02_0a", "42_02_0b"};
        const unsigned groups[] = {120,144,90};
        for (const auto *variant : suffixes) {
            const std::string panel = "/soc/qcom,mdss_mdp@ae00000/qcom,mdss_dsi_o82_" +
                std::string(variant) + "_dualdsi_dsc_vid/qcom,mdss-dsi-display-timings";
            const std::string prefix = std::string("o82_")+variant;
            for (unsigned g=0; g<3; ++g) {
                const int node = fdt_path_offset(dt.data(), (panel+"/timing@"+std::to_string(groups[g])).c_str());
                if (node < 0) throw std::runtime_error("OEM O82 timing group missing");
                require(dt,node,"qcom,mdss-dsi-panel-framerate",groups[g]);
                require(dt,node,"qcom,mdss-dsi-panel-width",1600);
                require(dt,node,"qcom,mdss-dsi-panel-height",2136);
                require(dt,node,"qcom,mdss-dsi-h-front-porch",g==0 ? 113 : g==1 ? 18 : 304);
                require(dt,node,"qcom,mdss-dsi-h-pulse-width",16);
                require(dt,node,"qcom,mdss-dsi-h-back-porch",16);
                require(dt,node,"qcom,mdss-dsi-v-pulse-width",2);
                require(dt,node,"qcom,mdss-dsi-v-back-porch",146);
                require(dt,node,"qcom,mdss-dsi-v-front-porch",26);
                require(dt,node,"qcom,mdss-dsc-version",0x11);
                require(dt,node,"qcom,mdss-dsc-slice-width",800);
                require(dt,node,"qcom,mdss-dsc-slice-height",24);
                require(dt,node,"qcom,mdss-dsc-bit-per-component",10);
                require(dt,node,"qcom,mdss-dsc-bit-per-pixel",8);
                const std::string name=prefix+"_"+std::to_string(groups[g]);
                commands(out,dt,node,"qcom,mdss-dsi-on-command",name+"_on");
                if (commands(out,dt,node,"qcom,mdss-dsi-timing-switch-video-command",name+"_switch") != 4)
                    throw std::runtime_error("OEM timing switch must contain four packets");
                if (commands(out,dt,node,"qcom,mdss-dsi-off-command",name+"_off") != 3)
                    throw std::runtime_error("OEM off stream must contain three packets");
            }
            out << "static const struct o82_profile " << prefix << "_profiles[] = {\n";
            for (unsigned hz : groups) {
                const std::string name=prefix+"_"+std::to_string(hz);
                out << "\t{ " << name << "_on, ARRAY_SIZE(" << name << "_on), "
                    << name << "_switch, ARRAY_SIZE(" << name << "_switch), "
                    << name << "_off, ARRAY_SIZE(" << name << "_off) },\n";
            }
            out << "};\n";
        }
        out << "static const struct o82_timing o82_modes[] = {\n";
        for (unsigned hz : {30,48,50,60,90,120,144}) {
            const unsigned group = hz==144 ? 1 : hz==60 || hz==120 ? 0 : 2;
            const unsigned base = groups[group], hfp=group==0 ? 226 : group==1 ? 36 : 608;
            // OEM dsi_display_dfps_calc_front_porch retains the group's clock.
            const unsigned vfp=26+2310*(base-hz)/hz, ht=3200+hfp+64;
            const unsigned clock=ht*2310*base/1000;
            out << "\t{ .group = " << group << ", .mode = { .clock = " << clock
                << ", .hdisplay = 3200, .hsync_start = " << 3200+hfp
                << ", .hsync_end = " << 3200+hfp+32 << ", .htotal = " << ht
                << ", .vdisplay = 2136, .vsync_start = " << 2136+vfp
                << ", .vsync_end = " << 2138+vfp << ", .vtotal = " << 2284+vfp
                << ", .width_mm = 237, .height_mm = 158 } },\n";
        }
        out << "};\n";
        std::cout << out.str();
    } catch (const std::exception &e) { std::cerr << "o82-data: " << e.what() << '\n'; return 1; }
}

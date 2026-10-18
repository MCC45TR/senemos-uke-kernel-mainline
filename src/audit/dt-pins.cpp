// SPDX-License-Identifier: GPL-2.0-only
// Host-only structural audit; matching donor tables do not establish electrical validity.
#include <libfdt.h>
#include <algorithm>
#include <cctype>
#include <fstream>
#include <iostream>
#include <map>
#include <regex>
#include <set>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

static std::string text_file(const char *path) {
    std::ifstream in(path, std::ios::binary | std::ios::ate);
    if (!in) throw std::runtime_error("Input unavailable");
    if (in.tellg() < 40 || in.tellg() > 2097152)
        throw std::runtime_error("Input outside bounded size");
    in.seekg(0);
    return {std::istreambuf_iterator<char>(in), {}};
}

static std::string normalized(std::string value) {
    value.erase(std::remove_if(value.begin(), value.end(),
        [](unsigned char c) { return std::isspace(c); }), value.end());
    return value;
}

static std::map<unsigned, std::vector<std::string>> groups(const std::string &source) {
    const std::regex pattern(R"(\[\s*([0-9]+)\s*\]\s*=\s*PINGROUP\(([^)]+)\))");
    std::map<unsigned, std::vector<std::string>> result;
    for (std::sregex_iterator i(source.begin(), source.end(), pattern), end; i != end; ++i) {
        std::vector<std::string> fields;
        std::istringstream stream(normalized((*i)[2]));
        std::string field;
        while (std::getline(stream, field, ',')) fields.push_back(field);
        if (fields.size() != 12 && fields.size() != 14)
            throw std::runtime_error("Unexpected mux shape");
        const unsigned index = std::stoul((*i)[1]);
        if (index > 177 || std::stoul(fields[0]) != index)
            throw std::runtime_error("Unexpected TLMM group index");
        // The OEM's final two fields encode wake registers outside the mux table.
        fields.resize(12);
        if (!result.emplace(index, fields).second) throw std::runtime_error("Duplicate group");
    }
    if (result.size() != 178) throw std::runtime_error("Expected all 178 TLMM groups");
    return result;
}

int main(int argc, char **argv) {
    try {
        if (argc != 4) throw std::runtime_error("Usage: DT OEM_PINCTRL LINUX_PINCTRL");
        const auto bytes = text_file(argv[1]);
        const void *dt = bytes.data();
        if (fdt_check_full(dt, bytes.size())) throw std::runtime_error("Invalid bounded FDT");
        const auto oem_text = text_file(argv[2]), linux_text = text_file(argv[3]);
        const auto oem = groups(oem_text), linux = groups(linux_text);
        if (oem != linux) throw std::runtime_error("OEM/Linux pin mux differs");
        const std::regex wake_pattern(
            R"(static const struct msm_gpio_wakeirq_map cliffs_pdc_map\[\] = \{([\s\S]*?)\n\};)");
        std::smatch a, b;
        if (!std::regex_search(oem_text, a, wake_pattern) ||
            !std::regex_search(linux_text, b, wake_pattern))
            throw std::runtime_error("Wake map missing");
        if (normalized(a[1]) != normalized(b[1]))
            throw std::runtime_error("OEM/Linux wake map differs");
        const std::string wake_map = a[1];
        const unsigned wake_pairs = std::count(wake_map.begin(), wake_map.end(), '{');
        if (!wake_pairs) throw std::runtime_error("Wake map empty");
        const auto path = [&](int node) {
            char name[4096];
            if (fdt_get_path(dt, node, name, sizeof name))
                throw std::runtime_error("Path too long");
            return std::string(name);
        };
        const std::map<std::string, std::string> providers = {
            {"clocks", "#clock-cells"}, {"resets", "#reset-cells"},
            {"dmas", "#dma-cells"}, {"iommus", "#iommu-cells"},
            {"phys", "#phy-cells"}, {"interconnects", "#interconnect-cells"},
            {"power-domains", "#power-domain-cells"}
        };
        unsigned refs = 0, states = 0, muxes = 0, badmux = 0, badrefs = 0;
        unsigned edges = 0, badedges = 0, gpio_specs = 0, badgpio = 0;
        std::set<int> selected;
        std::map<int, bool> active_nodes;
        const std::regex pin_property("pinctrl-[0-9]+"), gpio_pin("gpio[0-9]+");
        int node;
        for (node = fdt_next_node(dt, -1, nullptr); node >= 0;
             node = fdt_next_node(dt, node, nullptr)) {
            const int parent = fdt_parent_offset(dt, node);
            int status_length;
            const auto status = static_cast<const char *>(fdt_getprop(dt, node, "status", &status_length));
            const bool active = (parent < 0 || active_nodes.at(parent)) && (!status ||
                std::string(status, status_length) == std::string("ok\0", 3) ||
                std::string(status, status_length) == std::string("okay\0", 5));
            active_nodes[node] = active;
            int property_offset;
            fdt_for_each_property_offset(property_offset, dt, node) {
                int len;
                const char *name;
                const auto data = static_cast<const fdt32_t *>(
                    fdt_getprop_by_offset(dt, property_offset, &name, &len));
                if (!data) throw std::runtime_error("Property unavailable");
                const std::string property(name);
                if (std::regex_match(property, pin_property)) {
                    if (len % 4) { ++badrefs; continue; }
                    for (int j = 0; j < len / 4; j++) {
                        ++refs;
                        const int state = fdt_node_offset_by_phandle(dt, fdt32_to_cpu(data[j]));
                        if (state < 0) {
                            ++badrefs;
                            std::cout << "BAD_PIN_REF\t" << path(node) << '\t' << property << '\n';
                        } else if (active && property == "pinctrl-0") {
                            selected.insert(state);
                        }
                    }
                }
                if (!active) continue;
                const auto kind = providers.find(property);
                if (kind != providers.end()) {
                    bool bad = len % 4;
                    int j = 0;
                    while (!bad && j < len / 4) {
                        const unsigned phandle = fdt32_to_cpu(data[j++]);
                        if (!phandle) continue;
                        const int provider = fdt_node_offset_by_phandle(dt, phandle);
                        int count_bytes;
                        const auto count = static_cast<const fdt32_t *>(
                            fdt_getprop(dt, provider, kind->second.c_str(), &count_bytes));
                        if (provider < 0 || !count || count_bytes != 4 ||
                            fdt32_to_cpu(*count) > 32 ||
                            j + fdt32_to_cpu(*count) > static_cast<unsigned>(len / 4)) {
                            bad = true;
                            break;
                        }
                        j += fdt32_to_cpu(*count);
                        ++edges;
                    }
                    if (bad) {
                        ++badedges;
                        std::cout << "BAD_PROVIDER\t" << path(node) << '\t' << property << '\n';
                    }
                }
                // OEM LPASS *-gpios properties reference pinctrl nodes, not GPIO specifiers.
                if (property == "gpios" ||
                    (property.find(',') == std::string::npos && property.ends_with("-gpios")) ||
                    property == "novatek,irq-gpio" || property == "novatek,lcd_id-gpio") {
                    bool bad = len <= 0 || len % 12;
                    for (int j = 0; !bad && j < len / 4; j += 3) {
                        const int provider = fdt_node_offset_by_phandle(dt, fdt32_to_cpu(data[j]));
                        int count_bytes;
                        const auto count = static_cast<const fdt32_t *>(
                            fdt_getprop(dt, provider, "#gpio-cells", &count_bytes));
                        if (!count || count_bytes != 4 || fdt32_to_cpu(*count) != 2 ||
                            !fdt_getprop(dt, provider, "gpio-controller", nullptr) ||
                            (path(provider) == "/soc/pinctrl@f000000" &&
                             fdt32_to_cpu(data[j + 1]) > 178)) {
                            bad = true;
                        } else {
                            ++gpio_specs;
                        }
                    }
                    if (bad) {
                        ++badgpio;
                        std::cout << "BAD_GPIO\t" << path(node) << '\t' << property << '\n';
                    }
                }
            }
        }
        for (node = fdt_next_node(dt, -1, nullptr); node >= 0;
             node = fdt_next_node(dt, node, nullptr)) {
            const int count = fdt_stringlist_count(dt, node, "pins");
            if (count < 0) continue;
            ++states;
            const auto function = static_cast<const char *>(fdt_getprop(dt, node, "function", nullptr));
            if (!function || !path(node).starts_with("/soc/pinctrl@f000000/")) continue;
            if (fdt_stringlist_count(dt, node, "function") != 1)
                throw std::runtime_error("Invalid mux function string");
            for (int j = 0; j < count; j++) {
                const char *pin = fdt_stringlist_get(dt, node, "pins", j, nullptr);
                if (!pin || !std::regex_match(pin, gpio_pin)) continue;
                ++muxes;
                const unsigned id = std::stoul(std::string(pin).substr(4));
                const bool bad = !linux.contains(id) || std::string(function) == "NA" ||
                    (std::string(function) != "gpio" &&
                    std::find(linux.at(id).begin() + 1, linux.at(id).end(), function) == linux.at(id).end());
                if (bad) {
                    ++badmux;
                    bool active = false;
                    for (int n = node; n >= 0; n = fdt_parent_offset(dt, n))
                        active = active || selected.contains(n);
                    std::cout << "BAD_MUX\t" << path(node) << '\t' << pin << '\t' << function
                              << '\t' << (active ? "selected" : "unselected") << '\n';
                }
            }
        }
        std::cout << "COUNTS\tgroups=178\twake_pairs=" << wake_pairs << "\tpinctrl_refs=" << refs
                  << "\tpin_property_nodes=" << states << "\tmux_pin_entries=" << muxes
                  << "\tbad_mux=" << badmux << "\tbad_pin_refs=" << badrefs
                  << "\tprovider_specs=" << edges << "\tbad_provider_properties=" << badedges
                  << "\tchecked_gpio_specs=" << gpio_specs << "\tbad_gpio=" << badgpio << '\n';
        return badmux || badrefs || badedges || badgpio ? 1 : 0;
    } catch (const std::exception &error) {
        std::cerr << error.what() << '\n';
        return 2;
    }
}

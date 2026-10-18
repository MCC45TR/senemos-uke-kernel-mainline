// SPDX-License-Identifier: MIT
#pragma once
#include "boot-mode.hpp"
#include <fstream>
#include <stdexcept>

namespace uke::offline {
inline std::string read(const std::string &path, std::size_t limit = 65536) {
    std::ifstream stream(path,std::ios::binary);
    if (!stream) return {};
    std::string result;
    char c;
    while (stream.get(c)) {
        if (result.size() == limit) throw std::runtime_error("input_size_limit");
        result += c;
    }
    return result;
}
inline BootMode boot_mode(const std::string &root="") {
    if (!compatible(read(root+"/sys/firmware/devicetree/base/compatible"))) return BootMode::normal;
    BootSignal signal;
    signal.command_line(read(root+"/proc/cmdline"));
    signal.command_line(read(root+"/sys/firmware/devicetree/base/chosen/bootargs"));
    signal.bootconfig(read(root+"/proc/bootconfig"));
    return signal.mode();
}
}

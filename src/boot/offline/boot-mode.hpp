// SPDX-License-Identifier: MIT
#pragma once
#include <cctype>
#include <string>
#include <string_view>

namespace uke::offline {
enum class BootMode { normal, charger, invalid };
inline bool space(char c) { return std::isspace(static_cast<unsigned char>(c)); }
inline std::string_view trim(std::string_view s) {
    while (!s.empty() && space(s.front())) s.remove_prefix(1);
    while (!s.empty() && space(s.back())) s.remove_suffix(1);
    return s;
}
struct BootSignal {
    std::string value;
    bool invalid = false;
    void add(std::string_view v) {
        if (v.empty() || v.size() > 32) { invalid = true; return; }
        for (char c : v) if (!(std::isalnum(static_cast<unsigned char>(c)) || c == '_' || c == '-')) invalid = true;
        if (!value.empty() && value != v) invalid = true;
        value = std::string(v);
    }
    void command_line(std::string_view s) {
        if (s.size() > 16384) { invalid = true; return; }
        constexpr std::string_view key = "androidboot.mode=";
        while (!s.empty()) {
            s = trim(s);
            if (s.empty()) break;
            const auto end = s.find_first_of(" \t\r\n\0", 0, 5);
            const auto token = s.substr(0, end);
            if (token == "--") break;
            if (token.substr(0, key.size()) == key) add(token.substr(key.size()));
            if (end == std::string_view::npos) break;
            s.remove_prefix(end + 1);
        }
    }
    void bootconfig(std::string_view s) {
        if (s.size() > 65536) { invalid = true; return; }
        while (!s.empty()) {
            const auto end = s.find('\n');
            auto line = trim(s.substr(0, end));
            const auto eq = line.find('=');
            if (eq != std::string_view::npos && trim(line.substr(0, eq)) == "androidboot.mode") {
                auto v = trim(line.substr(eq + 1));
                if (v.size() >= 2 && v.front() == '"' && v.back() == '"') { v.remove_prefix(1); v.remove_suffix(1); }
                add(v);
            }
            if (end == std::string_view::npos) break;
            s.remove_prefix(end + 1);
        }
    }
    BootMode mode() const { return invalid ? BootMode::invalid : value == "charger" ? BootMode::charger : BootMode::normal; }
};
inline bool compatible(std::string_view bytes) {
    bool board = false, soc = false;
    while (!bytes.empty()) {
        const auto end = bytes.find('\0');
        const auto value = bytes.substr(0, end);
        board |= value == "xiaomi,uke";
        soc |= value == "qcom,sm7675";
        if (end == std::string_view::npos) break;
        bytes.remove_prefix(end + 1);
    }
    return board && soc;
}
}

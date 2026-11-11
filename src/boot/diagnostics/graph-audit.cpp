// SPDX-License-Identifier: GPL-2.0-only
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <vector>
#include <libfdt.h>
extern "C" int uke_audit_camcc(void *, int *);
extern "C" int uke_audit_front(void *, int *);
int main(int argc, char **argv)
{
    try {
        if (argc != 2) throw std::runtime_error("Usage: uke-boot-graph-audit-unstable FDT; read-only, RAM-copy checks only");
        std::ifstream stream(argv[1], std::ios::binary);
        if (!stream) throw std::runtime_error("Cannot read FDT");
        std::vector<char> input;
        char byte;
        constexpr std::size_t capacity = 4 * 1024 * 1024;
        while (input.size() < capacity && stream.get(byte)) input.push_back(byte);
        if (stream.get(byte) || input.empty() || stream.bad()) throw std::runtime_error("FDT size/read refused");
        if (fdt_check_full(input.data(), input.size())) throw std::runtime_error("Invalid complete FDT");
        if (fdt_node_check_compatible(input.data(), 0, "xiaomi,uke") ||
            fdt_node_check_compatible(input.data(), 0, "qcom,sm7675")) throw std::runtime_error("Foreign board refused");
        std::vector<char> copy(capacity);
        if (fdt_open_into(input.data(), copy.data(), copy.size())) throw std::runtime_error("Cannot copy FDT");
        int line = 0;
        int result = uke_audit_camcc(copy.data(), &line);
        std::cout << "CAMCC result=" << result << " source_line=" << line << '\n';
        if (result) return 2;
        result = uke_audit_front(copy.data(), &line);
        std::cout << "FRONT_EEPROM result=" << result << " source_line=" << line << '\n';
        std::cout << "Scope: current adapted handoff, private RAM copy; no hardware or original failed-boot acceptance\n";
        return result ? 2 : 0;
    } catch (const std::exception &error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}

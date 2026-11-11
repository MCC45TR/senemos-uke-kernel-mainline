// SPDX-License-Identifier: MIT
// Root-side systemd generator. No UI, daemon, IPC or charging control.
#include "offline/target.hpp"
#include <iostream>

int main(int argc, char **argv) {
    if (argc != 4) return 2;
    if (geteuid() != 0) return 69;
    if (access("/etc/initrd-release", F_OK) == 0) return 0;
    try {
        // Generator arguments are normal, early, late; early precedes /etc.
        (void) uke::offline::generate_target("", argv[2]);
        return 0;
    } catch (const std::exception &e) {
        std::cerr << "Uke charger target was not generated: " << e.what() << '\n';
        return 1;
    }
}

// SPDX-License-Identifier: MIT
// PID-1 wrapper for a disposable generic ARM64 kernel test, never a host service.
#include <sys/mount.h>
#include <sys/reboot.h>
#define main kvm_probe_main
#include "probe.cpp"
#undef main

int main() {
    if (getpid() != 1) return 64;
    if (mount("devtmpfs", "/dev", "devtmpfs", MS_NOSUID, nullptr) < 0) return 1;
    const int console = open("/dev/console", O_RDWR);
    if (console < 0) return 1;
    for (int fd = 0; fd < 3; ++fd) if (dup2(console, fd) < 0) return 1;
    if (console > 2) close(console);
    const int status = kvm_probe_main(1, nullptr);
    std::printf("UKE_KVM_PROBE_INIT_EXIT=%d\n", status);
    std::fflush(stdout);
    if (reboot(RB_POWER_OFF) < 0) return 1;
    return status;
}

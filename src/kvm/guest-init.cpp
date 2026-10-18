// SPDX-License-Identifier: MIT
// RAM-only ARM64 Linux guest acceptance: SMP entry, migration and monotonic timer.
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <fcntl.h>
#include <sched.h>
#include <sys/mount.h>
#include <sys/reboot.h>
#include <time.h>
#include <unistd.h>

static int fail(const char *stage) {
    std::printf("UKE_KVM_LINUX_FAIL stage=%s errno=%d\n", stage, errno);
    std::fflush(stdout);
    reboot(RB_POWER_OFF);
    return 1;
}

int main(int argc, char **argv) {
    if (getpid() != 1) {
        std::fputs("Guest init must run as PID 1 in the disposable VM\n", stderr);
        return 64;
    }
    mount("devtmpfs", "/dev", "devtmpfs", MS_NOSUID, nullptr);
    const int console = open("/dev/console", O_RDWR);
    if (console >= 0) {
        for (int fd = 0; fd < 3; ++fd) if (dup2(console, fd) < 0) return 1;
        if (console > 2) close(console);
    }
    if (argc != 2 || (argv[1][0] != '1' && argv[1][0] != '2') || argv[1][1])
        return fail("arguments");
    const int expected = argv[1][0] - '0';
    if (mount("proc", "/proc", "proc", MS_NOSUID | MS_NODEV | MS_NOEXEC, nullptr) < 0 ||
        mount("sysfs", "/sys", "sysfs", MS_NOSUID | MS_NODEV | MS_NOEXEC, nullptr) < 0)
        return fail("virtual-filesystems");
    if (sysconf(_SC_NPROCESSORS_ONLN) != expected) return fail("online-cpus");
    timespec previous{};
    if (clock_gettime(CLOCK_MONOTONIC, &previous) < 0) return fail("clock");
    for (int round = 0; round < 8; ++round) {
        for (int cpu = 0; cpu < expected; ++cpu) {
            cpu_set_t cpus;
            CPU_ZERO(&cpus);
            CPU_SET(cpu, &cpus);
            if (sched_setaffinity(0, sizeof(cpus), &cpus) < 0 || sched_getcpu() != cpu)
                return fail("cpu-migration");
            const timespec delay{0, 100000000};
            const int timer_error = clock_nanosleep(CLOCK_MONOTONIC, 0, &delay, nullptr);
            if (timer_error != 0) {
                errno = timer_error;
                return fail("timer-wakeup");
            }
            timespec now{};
            if (clock_gettime(CLOCK_MONOTONIC, &now) < 0) return fail("clock-read");
            const long long elapsed = (now.tv_sec - previous.tv_sec) * 1000000000LL +
                                      now.tv_nsec - previous.tv_nsec;
            if (elapsed < 90000000 || elapsed > 10000000000LL) return fail("timer-interval");
            previous = now;
        }
    }
    std::printf("UKE_KVM_LINUX_PASS cpus=%d timer=pass migration=pass\n", expected);
    std::fflush(stdout);
    if (reboot(RB_POWER_OFF) < 0) return fail("poweroff");
    return 0;
}

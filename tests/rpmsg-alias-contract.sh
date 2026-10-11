#!/usr/bin/env bash
# Host-only fixture of the actual RPMSG sysfs and uevent alias functions.
set -Eeuo pipefail
kernel=${1:?Pass the prepared kernel source directory}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
{
    cat <<'CPP'
#include <cassert>
#include <cstdio>
#include <cstdarg>
#include <cstring>
#include <string>
#include <sys/types.h>
#define ENODEV 19
#define PAGE_SIZE 4096
#define RPMSG_DEVICE_MODALIAS_FMT "rpmsg:%s"
struct device_node { bool compatible; };
struct device { device_node *of_node; };
struct device_attribute {};
struct rpmsg_device : device { struct { const char *name; } id; };
struct kobj_uevent_env { char alias[128]; };
rpmsg_device *to_rpmsg_device(device *d) { return static_cast<rpmsg_device *>(d); }
const rpmsg_device *to_rpmsg_device(const device *d) { return static_cast<const rpmsg_device *>(d); }
bool of_property_present(const device_node *n, const char *p) {
    assert(std::strcmp(p, "compatible") == 0);
    return n && n->compatible;
}
int of_result, of_calls;
int of_device_modalias(device *, char *buf, size_t) {
    ++of_calls;
    if (of_result >= 0) std::strcpy(buf, "of:compatible");
    return of_result;
}
int of_device_uevent_modalias(const device *, kobj_uevent_env *env) {
    ++of_calls;
    if (of_result >= 0) std::strcpy(env->alias, "MODALIAS=of:compatible");
    return of_result;
}
int add_uevent_var(kobj_uevent_env *env, const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    std::vsnprintf(env->alias, sizeof(env->alias), fmt, args);
    va_end(args);
    return 0;
}
CPP
    awk '/^static ssize_t modalias_show\(|^static int rpmsg_uevent\(/ {emit=1}
         emit {print} emit && /^}/ {emit=0}' "$kernel/drivers/rpmsg/rpmsg_core.c"
    cat <<'CPP'
int main() {
    device_node node{false};
    rpmsg_device d{};
    d.id.name = "IPCRTR";
    for (auto *n : {static_cast<device_node *>(nullptr), &node}) {
        d.of_node = n;
        of_calls = 0;
        of_result = 13;
        char buf[128]{};
        kobj_uevent_env env{};
        assert(modalias_show(&d, nullptr, buf) == 13);
        assert(std::strcmp(buf, "rpmsg:IPCRTR\n") == 0);
        assert(rpmsg_uevent(&d, &env) == 0);
        assert(std::strcmp(env.alias, "MODALIAS=rpmsg:IPCRTR") == 0);
        assert(of_calls == 0);
    }
    d.of_node = &node;
    node.compatible = true;
    for (int result : {13, -12, -ENODEV}) {
        of_calls = 0;
        of_result = result;
        char buf[128]{};
        kobj_uevent_env env{};
        assert(modalias_show(&d, nullptr, buf) == (result == -ENODEV ? 13 : result));
        assert(rpmsg_uevent(&d, &env) == (result == -ENODEV ? 0 : result));
        assert(of_calls == 2);
        if (result == 13) assert(std::strcmp(buf, "of:compatible") == 0);
        if (result == -ENODEV) assert(std::strcmp(buf, "rpmsg:IPCRTR\n") == 0);
    }
}
CPP
} > "$work/check.cpp"
g++ -std=c++20 -O2 -Wall -Wextra -Werror -Wno-unused-parameter "$work/check.cpp" -o "$work/check"
"$work/check"
echo 'RPMSG aliases: no-node and compatible-less channel fallback; compatible aliases and errors preserved'

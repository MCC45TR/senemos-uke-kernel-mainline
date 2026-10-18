// SPDX-License-Identifier: GPL-2.0-only
// The exact kernel parser, without filesystem or bootloader operations.
#include <cassert>
#include <cstring>
#include <string>
#define UKE_INIT
#include "../src/boot/uke-root-selector.h"

static constexpr char base[] = "rdinit=/usr/lib/systemd/systemd root=PARTLABEL=linux rw console=tty0";
static void check(const std::string &args, int expected, const char *initial = base) {
    char buffer[2048];
    std::strcpy(buffer, initial);
    assert(uke_select_root(buffer, sizeof(buffer), args.c_str(), args.size() + 1) == expected);
    auto wanted = std::string(initial);
    if (expected == 1) wanted.replace(wanted.find("root=PARTLABEL=linux"), std::strlen("root=PARTLABEL=linux"), "root=PARTLABEL=userdata");
    assert(buffer == wanted);
}
int main() {
    check("", 0);
    check("root=/dev/invalid init=/unsafe androidboot.slot_suffix=_a", 0);
    check("senemos.root=linux", 0);
    check("senemos.root=userdata", 1);
    check("\tsenemos.root=userdata\nandroidboot.slot_suffix=_b root=/dev/invalid", 1);
    check("xsenemos.root=userdata senemos.root.extra=userdata", 0);
    for (const auto *args : {"senemos.root=", "senemos.root=system", "senemos.root=userdata/", "senemos.root=\"userdata\"",
                            "senemos.root=linux senemos.root=userdata", "senemos.root=userdata senemos.root=userdata"}) check(args, -1);
    check("senemos.root=userdata", -1, "root=PARTLABEL=linux root=PARTLABEL=linux");
    check("senemos.root=userdata", -1, "root=UUID=invalid");
    check("senemos.root=userdata", -1, "console=tty0");
    check("senemos.root=userdata", 1, "root=PARTLABEL=linux");
    char bounded[24] = "root=PARTLABEL=linux";
    const auto original = std::string(bounded);
    const char args[] = "senemos.root=userdata";
    assert(uke_select_root(bounded, sizeof(bounded) - 1, args, sizeof(args)) == -1);
    assert(bounded == original);
    assert(uke_select_root(bounded, sizeof(bounded), args, sizeof(args)) == 1);
    assert(!std::strcmp(bounded, "root=PARTLABEL=userdata"));
    char unterminated[32]; std::memset(unterminated, 'X', sizeof(unterminated));
    assert(uke_select_root(unterminated, sizeof(unterminated), args, sizeof(args)) == -1);
    char buffer[2048]; std::strcpy(buffer, base);
    const char embedded[] = "senemos.root=linux\0senemos.root=userdata";
    assert(uke_select_root(buffer, sizeof(buffer), embedded, sizeof(embedded)) == -1);
    assert(uke_select_root(buffer, sizeof(buffer), args, sizeof(args) - 1) == -1);
    assert(uke_select_root(buffer, sizeof(buffer), nullptr, 1) == -1);
    assert(uke_select_root(buffer, sizeof(buffer), nullptr, 0) == 0);
    assert(uke_select_root(buffer, sizeof(buffer), args, 8193) == -1);
    assert(!std::strcmp(buffer, base));
}

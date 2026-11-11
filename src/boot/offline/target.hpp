// SPDX-License-Identifier: MIT
#pragma once
#include "io.hpp"
#include <cerrno>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

namespace uke::offline {
inline constexpr const char *target_generator = "/usr/lib/systemd/system-generators/uke-offline-target-generator";
inline constexpr const char *target_unit = "/usr/lib/systemd/system/uke-offline-charge.target";
inline constexpr const char *handoff_marker = "/run/uke-offline-charge";
inline constexpr std::string_view handoff_contents = "format=2\nmode=charger\n";

inline bool trusted_regular(const std::string &path, bool executable = false, uid_t owner = 0) {
    struct stat st{};
    return lstat(path.c_str(), &st) == 0 && S_ISREG(st.st_mode) &&
        st.st_uid == owner && !(st.st_mode & 0022) && (!executable || (st.st_mode & 0111));
}
inline bool target_payload(const std::string &root, uid_t owner = 0) {
    return trusted_regular(root + "/usr/libexec/uke-offline-charge", true, owner) &&
        trusted_regular(root + target_unit, false, owner) &&
        trusted_regular(root + "/usr/lib/systemd/system/uke-offline-charge.service", false, owner) &&
        trusted_regular(root + target_generator, true, owner);
}
inline bool trusted_handoff(const std::string &root, uid_t owner = 0) {
    const int fd = open((root + handoff_marker).c_str(), O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
    if (fd < 0) return false;
    struct stat st{};
    char data[64];
    const bool regular = fstat(fd, &st) == 0 && S_ISREG(st.st_mode) &&
        st.st_uid == owner && !(st.st_mode & 0077) && st.st_size == static_cast<off_t>(handoff_contents.size());
    const auto count = regular ? ::read(fd, data, sizeof(data)) : -1;
    close(fd);
    return count == static_cast<ssize_t>(handoff_contents.size()) &&
        std::string_view(data, static_cast<std::size_t>(count)) == handoff_contents;
}

// The production generator always uses owner0 and real root. Test fixtures may
// provide a private root/owner without exposing a runtime override in the CLI.
inline bool generate_target(const std::string &root, const std::string &early, uid_t owner = 0) {
    if (boot_mode(root) != BootMode::charger || !target_payload(root, owner) || !trusted_handoff(root, owner))
        return false;

    const int fd = open(early.c_str(), O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) throw std::runtime_error("charger_generator_directory_unavailable");
    struct stat st{};
    if (fstat(fd, &st) != 0 || !S_ISDIR(st.st_mode) || st.st_uid != owner || (st.st_mode & 0022)) {
        close(fd);
        throw std::runtime_error("charger_generator_directory_untrusted");
    }
    if (symlinkat(target_unit, fd, "default.target") == 0) {
        close(fd);
        return true;
    }
    const int saved = errno;
    char link[256];
    const bool symlink = saved == EEXIST && fstatat(fd, "default.target", &st, AT_SYMLINK_NOFOLLOW) == 0 &&
        S_ISLNK(st.st_mode) && st.st_uid == owner;
    const auto bytes = symlink ? readlinkat(fd, "default.target", link, sizeof(link)) : -1;
    close(fd);
    if (bytes == static_cast<ssize_t>(std::string_view(target_unit).size()) &&
        std::string_view(link, static_cast<std::size_t>(bytes)) == target_unit)
        return true;
    throw std::runtime_error("charger_default_target_collision");
}
}

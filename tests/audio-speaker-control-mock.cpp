// SPDX-License-Identifier: GPL-2.0-only
// COPR-only ALSA metadata shim. Never linked into the installed helper.
#include <alsa/asoundlib.h>
#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <cstdint>
extern "C" {
int snd_ctl_open(snd_ctl_t **handle, const char *, int) {
    if (std::getenv("UKE_AUDIO_TEST_ABSENT")) return -ENOENT;
    *handle = reinterpret_cast<snd_ctl_t *>(uintptr_t(1)); return 0;
}
int snd_ctl_close(snd_ctl_t *) { return 0; }
int snd_ctl_elem_info(snd_ctl_t *, snd_ctl_elem_info_t *) { return 0; }
snd_ctl_elem_type_t snd_ctl_elem_info_get_type(const snd_ctl_elem_info_t *info) {
    return std::strcmp(snd_ctl_elem_info_get_name(info), "FS19xx Protection State") == 0 ?
        SND_CTL_ELEM_TYPE_ENUMERATED : SND_CTL_ELEM_TYPE_BYTES;
}
unsigned snd_ctl_elem_info_get_count(const snd_ctl_elem_info_t *info) {
    return std::strcmp(snd_ctl_elem_info_get_name(info), "FS19xx Protection State") == 0 ? 1 : 512;
}
int snd_ctl_elem_info_is_writable(const snd_ctl_elem_info_t *) { return 1; }
int snd_ctl_elem_read(snd_ctl_t *, snd_ctl_elem_value_t *value) {
    if (std::strcmp(snd_ctl_elem_value_get_name(value), "FS19xx Protection State") != 0) return -EPERM;
    const auto *state = std::getenv("UKE_AUDIO_TEST_STATE");
    snd_ctl_elem_value_set_enumerated(value, 0, state ? std::strtoul(state, nullptr, 10) : 0);
    return 0;
}
int snd_ctl_elem_write(snd_ctl_t *, snd_ctl_elem_value_t *) { std::abort(); }
}

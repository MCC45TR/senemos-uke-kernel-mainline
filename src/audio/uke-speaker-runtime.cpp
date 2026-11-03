// SPDX-License-Identifier: GPL-2.0-only
// Unit calibration flows from read-only persist to the kernel/DSP in memory.
#include <algorithm>
#include <array>
#include <cstring>
#include <fstream>
#include <string_view>
#include <iostream>
#include <memory>
#include <sys/mman.h>
#include <sys/prctl.h>
#include <sys/random.h>
#include <sys/resource.h>
#include <alsa/asoundlib.h>
#include <openssl/crypto.h>
#include "uke-fs19xx-acdb.hpp"
#include "uke-speaker-persist.hpp"

namespace {
using namespace uke::audio;
struct PrivateSession {
    CalibrationSnapshot calibration;
    std::array<uint8_t, UKE_FS19XX_FRAME_BYTES> frame{};
    ~PrivateSession() {
        erase_calibration(calibration);
        volatile uint8_t *p = frame.data();
        for (size_t i = 0; i < frame.size(); ++i) p[i] = 0;
    }
};
void require_runtime(bool ok) {
    if (!ok) throw std::runtime_error("speaker runtime operation rejected");
}
GenericParameters generic_parameters(const char *path) {
    std::ifstream file(path, std::ios::binary | std::ios::ate);
    require_acdb(file && file.tellg() == 2838166);
    std::vector<uint8_t> data(2838166);
    file.seekg(0);
    require_acdb(bool(file.read(reinterpret_cast<char *>(data.data()), data.size())));
    return parse_foursemi_acdb(data);
}
struct Control {
    snd_ctl_t *handle = nullptr;
    snd_ctl_elem_id_t *id = nullptr;
    bool locked = false;
    explicit Control(const char *card) {
        require_runtime(snd_ctl_elem_id_malloc(&id) == 0);
        if (snd_ctl_open(&handle, card, 0) < 0) {
            snd_ctl_elem_id_free(id); id = nullptr;
            throw std::runtime_error("protected speaker control unavailable");
        }
        snd_ctl_elem_id_set_interface(id, SND_CTL_ELEM_IFACE_MIXER);
        snd_ctl_elem_id_set_name(id, UKE_FS19XX_CONTROL);
    }
    Control(const Control &) = delete;
    ~Control() {
        if (locked) snd_ctl_elem_unlock(handle, id);
        if (handle) snd_ctl_close(handle);
        if (id) snd_ctl_elem_id_free(id);
    }
    bool available() const {
        snd_ctl_elem_info_t *info = nullptr;
        if (snd_ctl_elem_info_malloc(&info) < 0) return false;
        snd_ctl_elem_info_set_id(info, id);
        const auto status = snd_ctl_elem_info(handle, info);
        const bool found = status >= 0 && snd_ctl_elem_info_get_type(info) == SND_CTL_ELEM_TYPE_BYTES &&
            snd_ctl_elem_info_get_count(info) == UKE_FS19XX_FRAME_BYTES && snd_ctl_elem_info_is_writable(info);
        snd_ctl_elem_info_free(info);
        return found;
    }
    int status() const {
        snd_ctl_elem_id_t *state_id = nullptr;
        snd_ctl_elem_value_t *value = nullptr;
        require_runtime(snd_ctl_elem_id_malloc(&state_id) == 0);
        if (snd_ctl_elem_value_malloc(&value) < 0) {
            snd_ctl_elem_id_free(state_id);
            throw std::runtime_error("speaker status memory unavailable");
        }
        snd_ctl_elem_id_set_interface(state_id, SND_CTL_ELEM_IFACE_MIXER);
        snd_ctl_elem_id_set_name(state_id, UKE_FS19XX_STATUS);
        snd_ctl_elem_value_set_id(value, state_id);
        const int result = snd_ctl_elem_read(handle, value);
        const unsigned state = result >= 0 ? snd_ctl_elem_value_get_enumerated(value, 0) : 6;
        snd_ctl_elem_value_free(value);
        snd_ctl_elem_id_free(state_id);
        require_runtime(result >= 0 && state <= UKE_FS_FAULT);
        return int(state);
    }
    void lock() {
        snd_ctl_elem_info_t *info = nullptr;
        require_runtime(snd_ctl_elem_info_malloc(&info) == 0);
        snd_ctl_elem_info_set_id(info, id);
        int result = snd_ctl_elem_info(handle, info);
        bool valid = result >= 0 && snd_ctl_elem_info_get_type(info) == SND_CTL_ELEM_TYPE_BYTES &&
            snd_ctl_elem_info_get_count(info) == UKE_FS19XX_FRAME_BYTES &&
            snd_ctl_elem_info_is_writable(info);
        snd_ctl_elem_info_free(info);
        require_runtime(valid && snd_ctl_elem_lock(handle, id) >= 0);
        locked = true;
    }
    void write(std::span<const uint8_t> frame) {
        snd_ctl_elem_value_t *value = nullptr;
        require_runtime(snd_ctl_elem_value_malloc(&value) == 0);
        snd_ctl_elem_value_set_id(value, id);
        for (size_t i = 0; i < frame.size(); ++i)
            snd_ctl_elem_value_set_byte(value, i, frame[i]);
        int result = snd_ctl_elem_write(handle, value);
        // ALSA's temporary userspace value also contains per-unit data.
        snd_ctl_elem_value_clear(value);
        snd_ctl_elem_value_free(value);
        require_runtime(result >= 0);
    }
};
void send(Control &control, PrivateSession &session, uint32_t operation,
          uint32_t transaction, uint32_t slot = 0, uint32_t total = 0,
          uint32_t offset = 0, std::span<const uint8_t> payload = {}) {
    require_runtime(payload.size() <= UKE_FS19XX_DATA_BYTES);
    auto &frame = session.frame;
    std::fill(frame.begin(), frame.end(), 0);
    uint32_t words[] = {UKE_FS19XX_ABI, operation, transaction, slot,
                        total, offset, uint32_t(payload.size()), 0};
    for (size_t i = 0; i < std::size(words); ++i)
        uke_fs19xx_put_word(frame.data() + 4 * i, words[i]);
    std::copy(payload.begin(), payload.end(), frame.begin() + 32);
    control.write(frame);
}
void load(Control &control, PrivateSession &session, const GenericParameters &parameters) {
    uint32_t transaction = 0;
    require_runtime(getrandom(&transaction, sizeof(transaction), 0) == ssize_t(sizeof(transaction)) && transaction);
    control.lock();
    try {
        send(control, session, UKE_FS_BEGIN, transaction);
        for (size_t slot = 0; slot < parameters.size(); ++slot) {
            const auto &data = parameters[slot];
            for (size_t offset = 0; offset < data.size(); offset += UKE_FS19XX_DATA_BYTES)
                send(control, session, UKE_FS_PARAMETER, transaction, slot, data.size(), offset,
                    std::span(data).subspan(offset, std::min<size_t>(UKE_FS19XX_DATA_BYTES, data.size() - offset)));
        }
        // No file is created. CH ordinal is retained; labels are carried separately.
        std::fill(session.frame.begin(), session.frame.end(), 0);
        std::array<uint8_t, 112> payload{};
        for (size_t i = 0; i < session.calibration.channel.size(); ++i) {
            const auto &channel = session.calibration.channel[i];
            uke_fs19xx_put_word(payload.data() + 4 * i, uint32_t(channel.position));
            uke_fs19xx_put_word(payload.data() + 16 + 24 * i, uint32_t(channel.resistance_q12));
        }
        // mlockall protects this temporary too; erase it before propagating errors.
        try { send(control, session, UKE_FS_CALIBRATION, transaction, 0, 112, 0, payload); }
        catch (...) { OPENSSL_cleanse(payload.data(), payload.size()); throw; }
        OPENSSL_cleanse(payload.data(), payload.size());
        send(control, session, UKE_FS_COMMIT, transaction);
    } catch (...) {
        try { send(control, session, UKE_FS_CLEAR, transaction); } catch (...) {}
        throw;
    }
}
} // namespace

int main(int argc, char **argv) {
    const char *directory = "/mnt/vendor/persist/audio";
    const char *acdb = "/var/cache/uke-speaker-runtime/Forte_acdb_cal.acdb";
    const char *card = "hw:POCOPadX1";
    bool apply = false, status_only = false, has_control = false;
    try {
        for (int i = 1; i < argc; ++i) {
            std::string_view option(argv[i]);
            if (option == "--check") apply = false;
            else if (option == "--load") apply = true;
            else if (option == "--status") status_only = true;
            else if (option == "--has-control") has_control = true;
            else if (option == "--persist-directory" && i + 1 < argc) directory = argv[++i];
            else if (option == "--acdb" && i + 1 < argc) acdb = argv[++i];
            else if (option == "--card" && i + 1 < argc) card = argv[++i];
            else throw std::runtime_error("usage: uke-speaker-runtime [--check|--load|--status|--has-control] [--acdb PATH] [--persist-directory RO_PATH] [--card ALSA_ID]");
        }
        if (status_only || has_control) {
            require_runtime(!apply && !(status_only && has_control));
            Control control(card);
            if (has_control) return control.available() ? 0 : 1;
            static constexpr const char *names[] = {"empty", "staging", "ready", "prepared", "running", "fault"};
            const auto state = control.status();
            std::cout << "{\"schema_version\":1,\"state\":\"" << names[state]
                << "\",\"gain_ceiling\":223,\"physical_protection_qualified\":false}\n";
            return 0;
        }
        struct rlimit core{0, 0};
        require_runtime(setrlimit(RLIMIT_CORE, &core) == 0 && prctl(PR_SET_DUMPABLE, 0) == 0);
        auto parameters = generic_parameters(acdb);
        // Refuse to read unit data if the process cannot keep it out of swap.
        require_runtime(mlockall(MCL_CURRENT | MCL_FUTURE) == 0);
        PrivateSession session;
        session.calibration = read_persist_calibration(directory);
        if (apply) {
            require_runtime(geteuid() == 0);
            Control control(card);
            load(control, session, parameters);
        }
        std::cout << (apply ? "Speaker parameters staged; playback still requires the protected kernel graph.\n"
                           : "Read-only calibration consistency and generic DSP data checks passed.\n");
        return 0;
    } catch (const std::exception &error) {
        std::cerr << "uke-speaker-runtime: " << error.what() << '\n';
        return 1;
    }
}

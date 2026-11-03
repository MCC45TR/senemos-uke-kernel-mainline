// SPDX-License-Identifier: GPL-2.0-only
// All calibration values below are synthetic parser fixtures, never unit data.
#include <algorithm>
#include <cassert>
#include <iostream>
#include <numeric>
#include "uke-fs19xx-acdb.hpp"
#include "uke-speaker-persist.hpp"

using namespace uke::audio;
using Frame = std::array<uint8_t, UKE_FS19XX_FRAME_BYTES>;
static Frame frame(uint32_t op, uint32_t tx = 17, uint32_t slot = 0,
                   uint32_t total = 0, uint32_t offset = 0, std::span<const uint8_t> data = {}) {
    Frame result{};
    uint32_t words[] = {1, op, tx, slot, total, offset, uint32_t(data.size()), 0};
    for (size_t i = 0; i < std::size(words); ++i) uke_fs19xx_put_word(result.data() + 4 * i, words[i]);
    std::copy(data.begin(), data.end(), result.begin() + 32);
    return result;
}
static bool verify(void *, unsigned slot, const uint8_t *data, size_t bytes) {
    return digest({data, bytes}) == uke_fs19xx_parameters[slot].sha256;
}
static int provision(uke_fs19xx_state &state, const Frame &f, bool busy = false) {
    return uke_fs19xx_provision(&state, f.data(), f.size(), busy, verify, nullptr);
}
static CalibrationSnapshot calibration() {
    std::array<uint8_t, 16> binary{};
    for (size_t i = 0; i < 4; ++i) uke_fs19xx_put_word(binary.data() + 4 * i, (i + 1) * 4096);
    auto result = parse_calibration(binary,
        "CH[2] TL 12288 (3.000)\nCH[0] BR 4096 (1.000)\nCH[3] BL 16384 (4.000)\nCH[1] TR 8192 (2.000)\n");
    assert(result.channel[0].position == SpeakerPosition::bottom_right);
    assert(result.channel[2].position == SpeakerPosition::top_left);
    assert(result.channel[2].resistance_q12 == 12288);
    assert(amplifier_address(result.channel[2].position) == 0x34);
    return result;
}
static std::array<uint8_t, 112> calibration_payload() {
    auto source = calibration();
    std::array<uint8_t, 112> output{};
    for (size_t i = 0; i < 4; ++i) {
        uke_fs19xx_put_word(output.data() + 4 * i, uint32_t(source.channel[i].position));
        uke_fs19xx_put_word(output.data() + 16 + 24 * i, uint32_t(source.channel[i].resistance_q12));
    }
    erase_calibration(source);
    return output;
}
static void parser_tests() {
    (void)calibration();
    std::array<uint8_t, 16> binary{};
    for (size_t i = 0; i < 4; ++i) uke_fs19xx_put_word(binary.data() + 4 * i, (i + 1) * 4096);
    std::string valid = "CH[0] TL 4096 (1.000)\nCH[1] TR 8192 (2.000)\nCH[2] BL 12288 (3.000)\nCH[3] BR 16384 (4.000)\n";
    auto reject = [&](std::span<const uint8_t> bytes, const std::string &text) {
        bool rejected = false;
        try { (void)parse_calibration(bytes, text); } catch (const std::runtime_error &) { rejected = true; }
        assert(rejected);
    };
    reject(std::span(binary).first(15), valid);
    reject(binary, "");
    reject(binary, valid + "\n");
    for (auto replacement : {"CH[0] TL 4097 (1.000)", "CH[0] TL 4096 (1.200)",
                             "CH[0] TL -1 (1.000)", "CH[4] TL 4096 (1.000)",
                             "CH[0] XX 4096 (1.000)", "CH[0] TL 4096 (nan)",
                             "CH[0] TL 4096 (1e0)", "CH[0] TL 4096 (inf)",
                             "CH[0] TL 4096 (1.000) trailing", "CH[0] TR 4096 (1.000)"}) {
        auto bad = valid;
        bad.replace(0, bad.find('\n'), replacement);
        reject(binary, bad);
    }
    // Exhaust all label permutations; no device's CH order is hardcoded.
    std::array<std::string_view, 4> labels{"BL", "BR", "TL", "TR"};
    do {
        std::string text;
        for (size_t i = 0; i < 4; ++i)
            text += "CH[" + std::to_string(i) + "] " + std::string(labels[i]) + " " +
                std::to_string((i + 1) * 4096) + " (" + std::to_string(i + 1) + ".000)\n";
        (void)parse_calibration(binary, text);
    } while (std::next_permutation(labels.begin(), labels.end()));
}
static void readonly_policy_test() {
    // COPR temporary files contain synthetic fixtures, never tablet readings.
    char directory[] = "/tmp/uke-speaker-fixture-XXXXXX";
    assert(mkdtemp(directory));
    std::string root(directory);
    std::array<uint8_t, 16> bytes{};
    for (size_t i = 0; i < 4; ++i) uke_fs19xx_put_word(bytes.data() + 4 * i, (i + 1) * 4096);
    const std::string text = "CH[0] TL 4096 (1.000)\nCH[1] TR 8192 (2.000)\nCH[2] BL 12288 (3.000)\nCH[3] BR 16384 (4.000)\n";
    (void)parse_calibration(bytes, text); // both files would otherwise be valid
    for (const char *name : {"fsalgo_rdc.bin", "fsalgo_rdc.txt"}) {
        FILE *output = fopen((root + "/" + name).c_str(), "wb"); assert(output);
        if (std::string_view(name).ends_with(".bin"))
            assert(fwrite(bytes.data(), 1, bytes.size(), output) == bytes.size());
        else assert(fwrite(text.data(), 1, text.size(), output) == text.size());
        assert(fclose(output) == 0);
    }
    bool rejected = false;
    try { auto unit = read_persist_calibration(directory); erase_calibration(unit); }
    catch (const std::runtime_error &) { rejected = true; }
    assert(unlink((root + "/fsalgo_rdc.bin").c_str()) == 0);
    assert(unlink((root + "/fsalgo_rdc.txt").c_str()) == 0);
    assert(rmdir(directory) == 0);
    assert(rejected); // consistent data on a writable filesystem must not load
}
static void negative_protocol_tests() {
    uke_fs19xx_state state{};
    auto begin = frame(UKE_FS_BEGIN);
    assert(provision(state, begin) == 0);
    assert(provision(state, frame(UKE_FS_COMMIT)) == -EINVAL && state.status == UKE_FS_FAULT);
    assert(!state.calibrated && !state.transaction);
    assert(provision(state, begin) == 0);
    auto data = calibration_payload();
    auto good = frame(UKE_FS_CALIBRATION, 17, 0, 112, 0, data);
    assert(provision(state, good, true) == -EBUSY && state.status == UKE_FS_STAGING);
    assert(provision(state, good) == 0);
    assert(provision(state, good) == -EINVAL && state.status == UKE_FS_FAULT);
    for (size_t offset : {size_t(0), size_t(16), size_t(20)}) {
        assert(provision(state, begin) == 0);
        auto bad = data; uke_fs19xx_put_word(bad.data() + offset, 0);
        if (offset == 20) bad[offset] = 1; // reserved word must remain zero
        assert(provision(state, frame(UKE_FS_CALIBRATION, 17, 0, 112, 0, bad)) == -EINVAL);
        assert(!state.calibrated && state.status == UKE_FS_FAULT);
    }
    assert(provision(state, begin) == 0);
    auto bad = good; bad.back() = 1;
    assert(provision(state, bad) == -EINVAL);
    assert(provision(state, begin) == 0);
    assert(provision(state, frame(UKE_FS_CALIBRATION, 18, 0, 112, 0, data)) == -EINVAL);
    assert(provision(state, begin) == 0);
    assert(provision(state, frame(UKE_FS_PARAMETER, 17, 0, 5360, 480, std::span(data).first(4))) == -EINVAL);
    assert(provision(state, frame(UKE_FS_CLEAR)) == 0 && state.status == UKE_FS_EMPTY);
}
struct Sender { size_t calls = 0, fail = 0; bool disabled_rx = false, disabled_tx = false; };
static int send(void *context, uint32_t iid, uint32_t parameter, const uint8_t *data, size_t size) {
    auto &sender = *static_cast<Sender *>(context);
    ++sender.calls;
    if (sender.calls == sender.fail) return -ETIMEDOUT;
    if (size == 4 && uke_fs19xx_word(data) == 0) {
        if (iid == UKE_FS19XX_RX_IID && parameter == 0x11111611) sender.disabled_rx = true;
        if (iid == UKE_FS19XX_TX_IID && parameter == 0x11111601) sender.disabled_tx = true;
    }
    if (parameter == UKE_FS19XX_RE25_PARAM) {
        assert(iid == UKE_FS19XX_RX_IID && size == 96);
        for (size_t i = 0; i < 4; ++i) {
            assert(uke_fs19xx_word(data + 24 * i) == (i + 1) * 4096);
            for (size_t j = 4; j < 24; ++j) assert(data[24 * i + j] == 0);
        }
    }
    return 0;
}
static void real_acdb_tests(const char *path) {
    FILE *input = fopen(path, "rb"); assert(input);
    std::vector<uint8_t> bytes(2838166);
    assert(fread(bytes.data(), 1, bytes.size(), input) == bytes.size());
    assert(fgetc(input) == EOF); fclose(input);
    auto parameters = parse_foursemi_acdb(bytes);
    bytes.back() ^= 1;
    bool rejected = false;
    try { (void)parse_foursemi_acdb(bytes); } catch (const std::runtime_error &) { rejected = true; }
    assert(rejected);
    auto staged = [&]() {
        uke_fs19xx_state state{};
        assert(provision(state, frame(UKE_FS_BEGIN)) == 0);
        for (size_t slot = 0; slot < parameters.size(); ++slot) {
            const auto &p = parameters[slot];
            for (size_t offset = 0; offset < p.size(); offset += UKE_FS19XX_DATA_BYTES)
                assert(provision(state, frame(UKE_FS_PARAMETER, 17, slot, p.size(), offset,
                    std::span(p).subspan(offset, std::min<size_t>(480, p.size() - offset)))) == 0);
        }
        auto data = calibration_payload();
        assert(provision(state, frame(UKE_FS_CALIBRATION, 17, 0, 112, 0, data)) == 0);
        assert(provision(state, frame(UKE_FS_COMMIT)) == 0 && state.status == UKE_FS_READY);
        return state;
    };
    for (size_t fail = 0; fail <= 6; ++fail) {
        auto state = staged();
        Sender sender{0, fail};
        int result = uke_fs19xx_prepare(&state, send, &sender);
        if (!fail) assert(result == 0 && state.status == UKE_FS_PREPARED && sender.calls == 6);
        else assert(result == -ETIMEDOUT && state.status == UKE_FS_FAULT &&
                    sender.disabled_rx && sender.disabled_tx && !state.calibrated && !state.re25[0]);
        uke_fs19xx_erase(&state);
    }
    auto state = staged();
    state.status = UKE_FS_STAGING;
    state.tuning[0] ^= 1;
    assert(provision(state, frame(UKE_FS_COMMIT)) == -EINVAL && !state.calibrated);
}
int main(int argc, char **argv) {
    parser_tests(); readonly_policy_test(); negative_protocol_tests();
    if (argc == 2) real_acdb_tests(argv[1]);
    std::cout << "Speaker runtime fixtures passed (synthetic unit data only).\n";
}

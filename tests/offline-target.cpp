// SPDX-License-Identifier: MIT
// Actual generator contract with private files; no PID1 or hardware operation.
#include "../src/boot/offline/target.hpp"
#include <cassert>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <vector>

namespace fs = std::filesystem;
namespace api = uke::offline;
struct Fixture {
    fs::path root, early;
    uid_t owner = geteuid();
    Fixture() {
        std::string name = (fs::temp_directory_path() / "uke-offline-target-XXXXXX").string();
        std::vector<char> buffer(name.begin(), name.end()); buffer.push_back(0);
        const char *made = mkdtemp(buffer.data()); assert(made); root = made;
        early = root / "run/systemd/generator.early";
        for (const auto &directory : {"proc", "sys/firmware/devicetree/base/chosen", "run/systemd/generator.early",
                                      "usr/libexec", "usr/lib/systemd/system", "usr/lib/systemd/system-generators",
                                      "etc/systemd/system"}) fs::create_directories(root / directory);
        std::string compatible = "xiaomi,uke"; compatible.push_back(0);
        compatible += "qcom,sm7675"; compatible.push_back(0);
        write("sys/firmware/devicetree/base/compatible", compatible);
        write("proc/cmdline", "androidboot.mode=charger\n");
        write("usr/libexec/uke-offline-charge", "private fixture; never executed\n", 0755);
        write("usr/lib/systemd/system/uke-offline-charge.target", "[Unit]\nDescription=Private charger fixture\nDefaultDependencies=no\n");
        write("usr/lib/systemd/system/uke-offline-charge.service", "[Service]\nExecStart=/usr/libexec/uke-offline-charge\n");
        write("usr/lib/systemd/system-generators/uke-offline-target-generator", "private fixture\n", 0755);
        write("run/uke-offline-charge", std::string(api::handoff_contents), 0600);
        fs::create_symlink("/usr/lib/systemd/system/graphical.target", root / "etc/systemd/system/default.target");
    }
    ~Fixture() { fs::remove_all(root); }
    void write(const std::string &name, const std::string &content, mode_t mode = 0644) {
        std::ofstream file(root / name, std::ios::binary); file.write(content.data(), content.size()); file.close();
        assert(file); assert(chmod((root / name).c_str(), mode) == 0);
    }
    bool generate() { return api::generate_target(root.string(), early.string(), owner); }
    void untouched() const {
        assert(!fs::exists(early / "default.target") && !fs::is_symlink(early / "default.target"));
        assert(fs::read_symlink(root / "etc/systemd/system/default.target") == "/usr/lib/systemd/system/graphical.target");
    }
    void refuses() { assert(!generate()); untouched(); }
    void errors() { bool threw = false; try { (void) generate(); } catch (const std::exception &) { threw = true; } assert(threw); }
};

int main() {
    unsigned cases = 0;
    { Fixture f; assert(f.generate()); assert(fs::read_symlink(f.early / "default.target") == api::target_unit);
      assert(f.generate()); assert(fs::read_symlink(f.root / "etc/systemd/system/default.target") == "/usr/lib/systemd/system/graphical.target"); ++cases; }
    { Fixture f; f.write("proc/cmdline", "root=PARTLABEL=userdata\n"); f.refuses(); ++cases; }
    { Fixture f; f.write("proc/cmdline", "androidboot.mode=normal\n"); f.write("proc/bootconfig", "androidboot.mode = \"charger\"\n"); f.refuses(); ++cases; }
    { Fixture f; f.write("sys/firmware/devicetree/base/compatible", "other-board"); f.refuses(); ++cases; }
    { Fixture f; f.write("proc/cmdline", ""); f.write("proc/bootconfig", "androidboot.mode = \"charger\"\n"); assert(f.generate()); ++cases; }
    { Fixture f; fs::remove(f.root / "run/uke-offline-charge"); f.refuses(); ++cases; }
    { Fixture f; f.write("run/uke-offline-charge", "charger\n", 0600); f.refuses(); ++cases; }
    { Fixture f; f.write("run/uke-offline-charge", "format=2\nmode=charger\ntrailing\n", 0600); f.refuses(); ++cases; }
    { Fixture f; assert(chmod((f.root / "run/uke-offline-charge").c_str(), 0644) == 0); f.refuses(); ++cases; }
    { Fixture f; fs::remove(f.root / "run/uke-offline-charge"); fs::create_symlink("/dev/null", f.root / "run/uke-offline-charge"); f.refuses(); ++cases; }
    { Fixture f; fs::remove(f.root / "run/uke-offline-charge"); assert(mkfifo((f.root / "run/uke-offline-charge").c_str(), 0600) == 0); f.refuses(); ++cases; }
    { Fixture f; fs::remove(f.root / "usr/lib/systemd/system-generators/uke-offline-target-generator"); f.refuses(); ++cases; }
    { Fixture f; assert(chmod((f.root / "usr/libexec/uke-offline-charge").c_str(), 0775) == 0); f.refuses(); ++cases; }
    { Fixture f; assert(chmod((f.root / "usr/lib/systemd/system-generators/uke-offline-target-generator").c_str(), 0644) == 0); f.refuses(); ++cases; }
    { Fixture f; fs::remove(f.root / "usr/lib/systemd/system/uke-offline-charge.target"); fs::create_symlink("/dev/null", f.root / "usr/lib/systemd/system/uke-offline-charge.target"); f.refuses(); ++cases; }
    { Fixture f; assert(!api::generate_target(f.root.string(), f.early.string(), f.owner == 0 ? 1 : 0)); f.untouched(); ++cases; }
    { Fixture f; assert(chmod(f.early.c_str(), 0777) == 0); f.errors(); f.untouched(); ++cases; }
    { Fixture f; fs::rename(f.early, f.root / "early-real"); fs::create_symlink(f.root / "early-real", f.early); f.errors(); ++cases; }
    { Fixture f; f.write("run/systemd/generator.early/default.target", "keep\n"); f.errors(); assert(api::read((f.early / "default.target").string()) == "keep\n"); ++cases; }
    { Fixture f; fs::create_symlink("/usr/lib/systemd/system/graphical.target", f.early / "default.target"); f.errors(); assert(fs::read_symlink(f.early / "default.target") == "/usr/lib/systemd/system/graphical.target"); ++cases; }
    { Fixture f; fs::remove(f.early); f.errors(); ++cases; }
    { Fixture f; f.write("proc/cmdline", std::string(16385, 'x')); f.refuses(); ++cases; }
    assert(cases == 22);
    std::cout << "Actual offline default generator: " << cases << " filesystem/boot-contract cases, no PID1 or hardware operation.\n";
}

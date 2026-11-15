// SPDX-License-Identifier: MIT
// Preserve the stock systemd switch-root operation; select a charger target only
// from the explicit bootloader signal with its matched native root payload.
#include "offline/target.hpp"
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#include <iostream>

namespace {
bool payload(const std::string &root) {
    return uke::offline::target_payload(root+"/sysroot");
}
}
int main(int argc,char **argv) {
    const bool inspect=argc==3 && std::string(argv[1])=="--inspect";
    if(argc!=1 && !inspect) return 2;
    const std::string root=inspect?argv[2]:"";
    auto mode=uke::offline::BootMode::normal;
    bool ready=false;
    try { mode=uke::offline::boot_mode(root); ready=payload(root); }
    catch(const std::exception&) { mode=uke::offline::BootMode::invalid; }
    const bool charger=mode==uke::offline::BootMode::charger && ready;
    if(inspect) {
        std::cout<<"{\"charger_signal\":"<<(mode==uke::offline::BootMode::charger?"true":"false")
            <<",\"conflicting_signal\":"<<(mode==uke::offline::BootMode::invalid?"true":"false")
            <<",\"matched_payload\":"<<(ready?"true":"false")
            <<",\"charger_target_selected\":"<<(charger?"true":"false")<<",\"executed\":false}\n";
        return 0;
    }
    if(geteuid()!=0 || access("/etc/initrd-release",F_OK)!=0) return 69;
    if(charger) {
        const int fd=open("/run/uke-offline-charge",O_WRONLY|O_CREAT|O_EXCL|O_CLOEXEC|O_NOFOLLOW,0600);
        if(fd<0) { std::cerr<<"Charger boot marker unavailable\n"; return 69; }
        const auto marker=uke::offline::handoff_contents;
        const bool wrote=write(fd,marker.data(),marker.size())==static_cast<ssize_t>(marker.size());
        close(fd);
        if(!wrote) return 69;
        std::cout<<"Explicit charger boot: selecting the minimal native target\n"<<std::flush;
        // The matched root generator selects default.target after switch-root.
        // Retain the original PID1 handover rather than inventing init argv.
        execl("/usr/bin/systemctl","systemctl","--no-block","switch-root",static_cast<char*>(nullptr));
    } else {
        if(mode!=uke::offline::BootMode::normal)
            std::cerr<<"Charger signal is conflicting or its native root payload is unavailable; preserving normal switch-root\n";
        execl("/usr/bin/systemctl","systemctl","--no-block","switch-root",static_cast<char*>(nullptr));
    }
    std::cerr<<"Native switch-root request failed\n";
    return 69;
}

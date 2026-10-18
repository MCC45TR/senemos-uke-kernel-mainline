// SPDX-License-Identifier: MIT
// Preserve the stock systemd switch-root operation; select a charger target only
// from the explicit bootloader signal with its matched native root payload.
#include "offline/io.hpp"
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#include <iostream>

namespace {
bool trusted(const std::string &path,bool executable=false) {
    struct stat st{};
    return lstat(path.c_str(),&st)==0 && S_ISREG(st.st_mode) && st.st_uid==0 &&
        !(st.st_mode&0022) && (!executable || (st.st_mode&0111));
}
bool payload(const std::string &root) {
    return trusted(root+"/sysroot/usr/libexec/uke-offline-charge",true) &&
        trusted(root+"/sysroot/usr/lib/systemd/system/uke-offline-charge.target") &&
        trusted(root+"/sysroot/usr/lib/systemd/system/uke-offline-charge.service");
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
        const char marker[]="charger\n";
        const bool wrote=write(fd,marker,sizeof(marker)-1)==sizeof(marker)-1;
        close(fd);
        if(!wrote) return 69;
        std::cout<<"Explicit charger boot: selecting the minimal native target\n"<<std::flush;
        execl("/usr/bin/systemctl","systemctl","--no-block","switch-root","/sysroot","/usr/lib/systemd/systemd","--unit=uke-offline-charge.target",static_cast<char*>(nullptr));
    } else {
        if(mode!=uke::offline::BootMode::normal)
            std::cerr<<"Charger signal is conflicting or its native root payload is unavailable; preserving normal switch-root\n";
        execl("/usr/bin/systemctl","systemctl","--no-block","switch-root",static_cast<char*>(nullptr));
    }
    std::cerr<<"Native switch-root request failed\n";
    return 69;
}

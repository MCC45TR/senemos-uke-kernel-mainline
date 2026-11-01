// SPDX-License-Identifier: MIT
// Offline growth of an already admitted UKE_LINUX userdata filesystem only.
#include <algorithm>
#include <array>
#include <cerrno>
#include <cstdint>
#include <fcntl.h>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <linux/fs.h>
#include <sstream>
#include <stdexcept>
#include <string>
#include <sys/file.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include <sys/wait.h>
#include <unistd.h>
namespace fs=std::filesystem;
using Super=std::array<unsigned char,3072>;
static void need(bool ok,const char *message){if(!ok)throw std::runtime_error(message);}
static uint64_t number(const Super &sb,size_t offset,unsigned width) {
    uint64_t value=0;for(unsigned i=0;i<width;++i)value|=uint64_t(sb.at(offset+i))<<(8*i);return value;
}
static uint32_t checksum(const Super &sb,size_t length) {
    uint32_t crc=0xf2f52010;
    for(size_t i=0;i<length;++i){crc^=sb[i];for(unsigned bit=0;bit<8;++bit)crc=(crc>>1)^((crc&1)?0xedb88320:0);}
    return crc;
}
static Super read_super(int fd,uint64_t offset) {
    Super bytes{};size_t done=0;
    while(done<bytes.size()) {
        const auto count=pread(fd,bytes.data()+done,bytes.size()-done,offset+done);
        if(count<0 && errno==EINTR)continue;
        need(count>0,"Incomplete F2FS superblock");done+=size_t(count);
    }
    return bytes;
}
static uint64_t geometry(const Super &sb,uint64_t device_bytes) {
    need(number(sb,0,4)==0xf2f52010 && number(sb,16,4)==12 && number(sb,20,4)==9,"Unsupported F2FS geometry");
    need((number(sb,8,4)==9||number(sb,8,4)==12) && number(sb,8,4)+number(sb,12,4)==12,"Invalid F2FS sector geometry");
    need(device_bytes%4096==0 && device_bytes/4096>=512,"Invalid physical capacity");
    const auto blocks=number(sb,36,8);
    need(blocks>=512 && blocks<=device_bytes/4096,"F2FS exceeds its physical partition; shrinking refused");
    const std::string label="UKE_LINUX";
    for(size_t i=0;i<512;++i)need(number(sb,124+i*2,2)==(i<label.size()?unsigned(label[i]):0),"Not a provisioned UKE_LINUX filesystem");
    if(number(sb,2180,4)&0x800) {
        need(number(sb,32,4)==3068 && checksum(sb,3068)==number(sb,3068,4),"F2FS superblock checksum differs");
    }
    return blocks;
}
static Super inspect(int fd,uint64_t bytes) {
    auto first=read_super(fd,1024),second=read_super(fd,4096+1024);
    need(first==second,"F2FS superblock copies differ; explicit recovery required");
    (void)geometry(first,bytes);return first;
}
static void run(const char *tool,const std::string &device,bool check) {
    const auto child=fork();need(child>=0,"Cannot fork F2FS tool");
    if(!child) {
        const int input=open("/dev/null",O_RDONLY|O_CLOEXEC);
        if(input<0 || dup2(input,STDIN_FILENO)<0)_exit(126);
        clearenv();setenv("LC_ALL","C",1);
        if(check)execl(tool,tool,"--dry-run","-f",device.c_str(),static_cast<char*>(nullptr));
        else execl(tool,tool,device.c_str(),static_cast<char*>(nullptr));
        _exit(127);
    }
    int status=0;pid_t waited;
    do{waited=waitpid(child,&status,0);}while(waited<0 && errno==EINTR);
    need(waited==child && WIFEXITED(status) && WEXITSTATUS(status)==0,"F2FS check or resize failed; root remains unmounted");
}
static void expand(int fd,const std::string &device,uint64_t bytes) {
    const auto before=inspect(fd,bytes);const auto old_blocks=geometry(before,bytes);
    need(bytes/4096-old_blocks>=512,"No full F2FS segment available for growth");
    run("/usr/sbin/fsck.f2fs",device,true);
    need(inspect(fd,bytes)==before,"F2FS changed during its read-only check");
    run("/usr/sbin/resize.f2fs",device,false);
    const auto after=inspect(fd,bytes);
    need(std::equal(before.begin()+108,before.begin()+124,after.begin()+108),"Filesystem UUID changed during growth");
    need(geometry(after,bytes)>old_blocks && bytes/4096-geometry(after,bytes)<512,"F2FS growth did not reach physical capacity");
    run("/usr/sbin/fsck.f2fs",device,true);
    std::cout<<"UKE_F2FS_GROWN: filesystem now spans "<<geometry(after,bytes)*4096<<" bytes; GPT unchanged\n";
}
static std::string small(const fs::path &path) {
    std::ifstream input(path);need(bool(input),"Unavailable bounded system observation");
    std::string value((std::istreambuf_iterator<char>(input)),{});need(value.size()<=128,"Oversized system observation");
    if(!value.empty() && value.back()=='\n')value.pop_back();
    return value;
}
static bool enough_power(const fs::path &supplies) {
    bool external=false;int capacity=-1;
    try {
        for(const auto &entry:fs::directory_iterator(supplies)) {
            if(fs::exists(entry.path()/"online"))external|=small(entry.path()/"online")=="1";
            if(small(entry.path()/"type")!="Battery")continue;
            const auto text=small(entry.path()/"capacity");
            need(!text.empty() && text.size()<=3 && text.find_first_not_of("0123456789")==std::string::npos,"Invalid battery capacity");
            const auto value=std::stoi(text);need(value<=100 && capacity<0,"Ambiguous battery capacity");capacity=value;
        }
    }catch(const std::exception&){return false;}
    return capacity>=50 || (capacity>=30 && external);
}
#ifndef UKE_F2FS_GROW_TEST
int main(int argc,char **argv) {
    try {
        need(argc==2 && geteuid()==0,"Root and one admitted physical device required");
        const fs::path device=argv[1];
        need(device.is_absolute() && device.parent_path()=="/dev" && device==device.lexically_normal(),"Direct physical device path required");
        const int fd=open(device.c_str(),O_RDONLY|O_CLOEXEC|O_NOFOLLOW|O_NONBLOCK);struct stat st{};uint64_t bytes=0;int ro=1;
        need(fd>=0 && !fstat(fd,&st) && S_ISBLK(st.st_mode) && !flock(fd,LOCK_EX|LOCK_NB) &&
             !ioctl(fd,BLKGETSIZE64,&bytes) && !ioctl(fd,BLKROGET,&ro) && !ro,"Cannot admit writable physical device");
        const auto sys=fs::canonical(fs::path("/sys/dev/block")/(std::to_string(major(st.st_rdev))+":"+std::to_string(minor(st.st_rdev))));
        need(sys.string().starts_with("/sys/devices/") && sys.string().find("/1d84000.ufshc/")!=std::string::npos && fs::exists(sys/"partition"),"Measured Uke UFS partition required");
        std::ifstream event(sys/"uevent");std::string row;unsigned names=0;
        while(std::getline(event,row))if(row.starts_with("PARTNAME=")){need(row=="PARTNAME=userdata","Only userdata growth is admitted");++names;}
        need(names==1,"Unique userdata identity required");
        std::ifstream mounts("/proc/self/mountinfo");need(bool(mounts),"Mount inspection unavailable");
        while(std::getline(mounts,row)) {
            std::istringstream fields(row);std::string id,parent,number;need(bool(fields>>id>>parent>>number),"Malformed mount observation");
            need(number!=std::to_string(major(st.st_rdev))+":"+std::to_string(minor(st.st_rdev)),"Mounted F2FS growth refused");
        }
        const auto sb=inspect(fd,bytes);
        if(bytes/4096-geometry(sb,bytes)<512){std::cout<<"UKE_F2FS_CAPACITY_CURRENT\n";return 0;}
        if(!enough_power("/sys/class/power_supply")) {
            std::cout<<"UKE_F2FS_GROW_DEFERRED: power unknown or below 50% (30% with external power); existing filesystem retained\n";return 0;
        }
        expand(fd,device,bytes);need(!close(fd),"Cannot close resized root descriptor");return 0;
    }catch(const std::exception &error){std::cerr<<"UKE_F2FS_GROW_REJECTED: "<<error.what()<<'\n';return 1;}
}
#endif

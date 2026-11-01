// SPDX-License-Identifier: MIT
#define UKE_F2FS_GROW_TEST
#include "../src/boot/f2fs-grow.cpp"
#include <cassert>
#include <functional>
static void reject(const std::function<void()> &call){bool failed=false;try{call();}catch(const std::runtime_error&){failed=true;}assert(failed);}
static void put(Super &sb,size_t offset,uint64_t value,unsigned width){for(unsigned i=0;i<width;++i)sb.at(offset+i)=value>>(i*8);}
static void write(const fs::path &path,const std::string &text){fs::create_directories(path.parent_path());std::ofstream(path)<<text;}
int main(int argc,char **argv) {
    assert(argc==2);const fs::path path=argv[1];const int fd=open(path.c_str(),O_RDWR|O_CLOEXEC);struct stat st{};
    assert(fd>=0 && !fstat(fd,&st) && S_ISREG(st.st_mode));
    const auto original=inspect(fd,st.st_size);const auto blocks=geometry(original,st.st_size);
    assert(blocks==uint64_t(st.st_size)/4096);
    auto bad=original;bad[0]^=1;reject([&]{geometry(bad,st.st_size);});
    bad=original;put(bad,36,blocks+1,8);reject([&]{geometry(bad,st.st_size);});
    bad=original;put(bad,16,16,4);reject([&]{geometry(bad,st.st_size);});
    bad=original;bad[124]='x';reject([&]{geometry(bad,st.st_size);});
    bad=original;bad[3068]^=1;reject([&]{geometry(bad,st.st_size);});
    reject([&]{geometry(original,st.st_size-1);});
    char temporary[]="/tmp/uke-grow-power.XXXXXX";assert(mkdtemp(temporary));const fs::path supplies=temporary;
    assert(!enough_power(supplies));write(supplies/"battery/type","Battery\n");write(supplies/"battery/capacity","49\n");
    assert(!enough_power(supplies));write(supplies/"usb/type","USB\n");write(supplies/"usb/online","1\n");
    assert(enough_power(supplies));write(supplies/"battery/capacity","29\n");assert(!enough_power(supplies));
    write(supplies/"battery/capacity","50\n");write(supplies/"usb/online","0\n");assert(enough_power(supplies));
    for(const auto value:{"101\n","-1\n","50x\n",""}){write(supplies/"battery/capacity",value);assert(!enough_power(supplies));}
    write(supplies/"battery/capacity","60\n");write(supplies/"second/type","Battery\n");write(supplies/"second/capacity","70\n");assert(!enough_power(supplies));fs::remove_all(supplies);
    assert(!ftruncate(fd,st.st_size*2));expand(fd,path,st.st_size*2);
    const auto grown=inspect(fd,st.st_size*2);assert(geometry(grown,st.st_size*2)==blocks*2);
    assert(std::equal(original.begin()+108,original.begin()+124,grown.begin()+108));
    reject([&]{expand(fd,path,st.st_size*2);});close(fd);
    std::cout<<"Actual regular-file F2FS growth, UUID preservation, full read-only fsck, geometry/CRC/label/shrink refusal and low/unknown power fixtures passed; no tablet I/O\n";
}

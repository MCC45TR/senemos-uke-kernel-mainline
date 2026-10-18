// SPDX-License-Identifier: MIT
// Read-only lab sampling; Cliffs PINGROUP map and runtime DT must match.
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <fcntl.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

static uint32_t be32(const unsigned char *p) {
    return uint32_t(p[0])<<24 | uint32_t(p[1])<<16 | uint32_t(p[2])<<8 | p[3];
}
static uint64_t now() {
    timespec t{};
    if (clock_gettime(CLOCK_MONOTONIC,&t)) { perror("clock"); _exit(1); }
    return uint64_t(t.tv_sec)*1000000000+t.tv_nsec;
}
int main(int argc,char **argv) {
    if (argc==2 && !strcmp(argv[1],"--self-test")) {
        const unsigned char bytes[]={0x0f,0,0,0,1,0,0,0};
        return be32(bytes)!=0x0f000000 || be32(bytes+4)!=0x01000000;
    }
    if (argc!=2 || strcmp(argv[1],"--run")) return 2;
    static const char expected[]="qcom,cliffs-pinctrl";
    char compatible[sizeof(expected)+1]{};
    int type=open("/sys/devices/platform/soc/f000000.pinctrl/of_node/compatible",O_RDONLY|O_CLOEXEC);
    if(type<0) {perror("Cliffs compatible");return 1;}
    const auto type_size=read(type,compatible,sizeof(compatible));close(type);
    if(type_size!=sizeof(expected) || memcmp(compatible,expected,sizeof(expected)))return 2;
    unsigned char reg[9]{};
    int dt=open("/sys/devices/platform/soc/f000000.pinctrl/of_node/reg",O_RDONLY|O_CLOEXEC);
    if(dt<0) {perror("Cliffs DT");return 1;}
    const auto size=read(dt,reg,sizeof(reg));close(dt);
    if(size!=8 || be32(reg)!=0x0f000000 || be32(reg+4)!=0x01000000) return 2;
    // pinctrl-cliffs.c: REG_BASE=0x100000, REG_SIZE=0x1000, io_reg=ctl_reg+4.
    const off_t page=off_t(be32(reg))+0x100000+77*0x1000;
    int fd=open("/dev/mem",O_RDONLY|O_SYNC|O_CLOEXEC);
    if(fd<0) {perror("read-only TLMM");return 1;}
    void *map=mmap(nullptr,8192,PROT_READ,MAP_SHARED,fd,page);close(fd);
    if(map==MAP_FAILED) {perror("read-only TLMM mapping");return 1;}
    auto *words=static_cast<volatile const uint32_t *>(map);
    const uint32_t ctl77=words[0],ctl78=words[1024];
    fprintf(stderr,"ctl77=%08x ctl78=%08x\n",ctl77,ctl78);
    if((ctl77&(1U<<9)) || (ctl78&(1U<<9)) || ((ctl77>>2)&15)!=1 || ((ctl78>>2)&15)!=0) {
        munmap(map,8192);return 2;
    }
    struct Edge {uint64_t time;unsigned levels;};
    Edge edges[8192];unsigned count=0;
    const uint64_t start=now();uint64_t previous=start,max_gap=0;
    unsigned levels=(words[1]&1)|((words[1025]&1)<<1);
    do {
        const unsigned next=(words[1]&1)|((words[1025]&1)<<1);
        const uint64_t time=now();
        if(time-previous>max_gap)max_gap=time-previous;
        previous=time;
        if(next!=levels) {edges[count++]={time,next};levels=next;}
    } while(previous-start<2000000000ULL && count<8192);
    const bool unchanged=words[0]==ctl77 && words[1024]==ctl78;
    munmap(map,8192);
    fprintf(stderr,"duration_ns=%llu max_poll_gap_ns=%llu edges=%u controls_unchanged=%d\n",
        static_cast<unsigned long long>(previous-start),
        static_cast<unsigned long long>(max_gap),count,unchanged);
    puts("monotonic_ns,gpio77,gpio78");
    for(unsigned i=0;i<count;++i)printf("%llu,%u,%u\n",
        static_cast<unsigned long long>(edges[i].time),edges[i].levels&1,(edges[i].levels>>1)&1);
    return unchanged?0:1;
}

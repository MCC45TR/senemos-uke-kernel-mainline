// SPDX-License-Identifier: MIT
// Finite synthetic wheel input for the tablet's original desktop applications.
#include <linux/uinput.h>
#include <sys/ioctl.h>
#include <cassert>
#include <cerrno>
#include <cstdio>
#include <cstring>
#include <fcntl.h>
#include <fstream>
#include <iterator>
#include <stdexcept>
#include <string>
#include <time.h>
#include <unistd.h>

static int legacy_wheel(int delta,int &remaining) {
    remaining+=delta;int legacy=remaining/120;remaining-=legacy*120;return legacy;
}
static void check(int result,const char *operation) {
    if(result<0)throw std::runtime_error(std::string(operation)+": "+strerror(errno));
}
static void emit(int fd,unsigned type,unsigned code,int value) {
    input_event e{};e.type=type;e.code=code;e.value=value;
    if(write(fd,&e,sizeof(e))!=sizeof(e))throw std::runtime_error("uinput write");
}
static void sync(int fd) {emit(fd,EV_SYN,SYN_REPORT,0);}
int main(int argc,char **argv) {
    if(argc==2 && !strcmp(argv[1],"--self-test")) {
        int remaining=0,total=0;
        for(unsigned i=0;i<240;++i)total+=legacy_wheel(10,remaining);
        assert(total==20 && !remaining);
        for(unsigned i=0;i<240;++i)total+=legacy_wheel(-10,remaining);
        assert(!total && !remaining);return 0;
    }
    if(argc!=2 || strcmp(argv[1],"--run"))return 2;
    std::ifstream source("/sys/firmware/devicetree/base/compatible",std::ios::binary);
    const std::string compatible((std::istreambuf_iterator<char>(source)),{});
    if(compatible.find(std::string("xiaomi,uke\0",11))==std::string::npos)return 2;
    int fd=open("/dev/uinput",O_WRONLY|O_NONBLOCK|O_CLOEXEC);
    if(fd<0){perror("uinput");return 1;}
    int result=1;bool created=false;
    try {
        check(ioctl(fd,UI_SET_EVBIT,EV_KEY),"EV_KEY");
        check(ioctl(fd,UI_SET_KEYBIT,BTN_LEFT),"BTN_LEFT capability");
        check(ioctl(fd,UI_SET_EVBIT,EV_REL),"EV_REL");
        for(int code:{REL_X,REL_Y,REL_WHEEL,REL_WHEEL_HI_RES})
            check(ioctl(fd,UI_SET_RELBIT,code),"relative axis");
        uinput_setup setup{};setup.id.bustype=BUS_VIRTUAL;
        snprintf(setup.name,sizeof(setup.name),"Uke scrolling laboratory mouse");
        check(ioctl(fd,UI_DEV_SETUP,&setup),"UI_DEV_SETUP");
        check(ioctl(fd,UI_DEV_CREATE),"UI_DEV_CREATE");created=true;
        timespec settle{1,0};nanosleep(&settle,nullptr);
        emit(fd,EV_REL,REL_X,-10000);emit(fd,EV_REL,REL_Y,-10000);sync(fd);
        // Let the compositor clamp before processing the positioning motion.
        timespec position_delay{0,150000000};nanosleep(&position_delay,nullptr);
        // shortcut: position verified at KDE scale 2.5; recheck after layout changes.
        emit(fd,EV_REL,REL_X,300);emit(fd,EV_REL,REL_Y,200);sync(fd);
        nanosleep(&position_delay,nullptr);
        int remaining=0;
        timespec next{};check(clock_gettime(CLOCK_MONOTONIC,&next),"clock");
        for(unsigned i=0;i<480;++i) {
            const int delta=i<240?-10:10;
            emit(fd,EV_REL,REL_WHEEL_HI_RES,delta);
            const int legacy=legacy_wheel(delta,remaining);
            if(legacy)emit(fd,EV_REL,REL_WHEEL,legacy);
            sync(fd);
            next.tv_nsec+=16666667;
            if(next.tv_nsec>=1000000000){++next.tv_sec;next.tv_nsec-=1000000000;}
            int sleep_result;
            do {sleep_result=clock_nanosleep(CLOCK_MONOTONIC,TIMER_ABSTIME,&next,nullptr);}
            while(sleep_result==EINTR);
            if(sleep_result)throw std::runtime_error("input schedule");
        }
        assert(!remaining);result=0;
    } catch(const std::exception &e) {fprintf(stderr,"%s\n",e.what());}
    if(created)ioctl(fd,UI_DEV_DESTROY);
    close(fd);return result;
}

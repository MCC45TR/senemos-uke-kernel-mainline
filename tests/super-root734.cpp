// SPDX-License-Identifier: GPL-2.0-only
// Pure actual parser checks; no block device, mapping, key or resume action.
#include <cassert>
#include <cstring>
#include <iostream>
#include <string>
#include <vector>
#define UKE_INIT
#define COMMAND_LINE_SIZE 2048
#include "uke-super-root-selector.h"

static constexpr char initial[]="rdinit=/usr/lib/systemd/systemd root=PARTLABEL=linux rw rootfstype=ext4,f2fs,xfs,btrfs panic=0 console=tty0";
static unsigned checks;
static std::string invoke(const std::string& args,int expected,size_t capacity=2048,const char* base=initial)
{
    char line[2048];std::memset(line,'Z',sizeof(line));std::strcpy(line,base);
    assert(uke_select_root(line,capacity,args.c_str(),args.size()+1)==expected);
    if(expected<0)assert(!std::strcmp(line,base));
    checks++;return line;
}
int main()
{
    for(const auto* args:{"","senemos.root=linux","senemos.root=userdata",
        "senemos.root=userdata androidboot.slot_suffix=_a",
        "senemos.root=userdata msm.o82_vrr_test_min_hz=0",
        "senemos.root=userdata msm.o82_vrr_test_min_hz=30"}) {
        char base[2048],extended[2048];std::strcpy(base,initial);std::strcpy(extended,initial);
        const auto bytes=std::strlen(args)+1;
        const int expected=uke_select_base_root734(base,sizeof(base),args,bytes);
        assert(uke_select_root(extended,sizeof(extended),args,bytes)==expected);
        assert(!std::memcmp(base,extended,std::strlen(base)+1));checks++;
    }
    for(const char* suffix:{""," androidboot.slot_suffix=_a"," androidboot.slot_suffix=_b",
        " msm.o82_vrr_test_min_hz=0"," msm.o82_vrr_test_min_hz=30"}) {
        const auto result=invoke(std::string("senemos.root=userdata senemos.role=rescue")+suffix,1);
        assert(result.find("root=/dev/mapper/uke-rescue ")!=result.npos);
        assert(result.find(" ro ")!=result.npos&&result.find(" rw ")==result.npos);
        assert(result.find("rootfstype=ext4 ")!=result.npos);
        assert(result.ends_with(" senemos.role=rescue senemos.super=seed4-v1 noresume"));
    }
    const auto super=invoke("senemos.root=userdata senemos.super=seed4-v1 androidboot.slot_suffix=_b",1);
    assert(super.find("root=PARTLABEL=userdata ")!=super.npos);
    assert(super.find(" rw ")!=super.npos&&super.find(" ro ")==super.npos);
    assert(super.ends_with(" senemos.super=seed4-v1")&&super.find("noresume")==super.npos);
    const auto explicit_super=invoke("senemos.root=userdata senemos.role=rescue senemos.super=seed4-v1",1);
    assert(explicit_super.ends_with(" senemos.role=rescue senemos.super=seed4-v1 noresume"));
    for(const auto* args:{"senemos.role=rescue","senemos.root=linux senemos.role=rescue",
        "senemos.root=userdata senemos.role=","senemos.root=userdata senemos.role=normal",
        "senemos.root=userdata senemos.role=rescue/","senemos.root=userdata senemos.role=rescue senemos.role=rescue",
        "senemos.root=userdata senemos.role=rescue androidboot.slot_suffix=_c",
        "senemos.root=linux senemos.root=userdata senemos.role=rescue",
        "senemos.root=userdata senemos.role=rescue msm.o82_vrr_test_min_hz=31",
        "senemos.super=seed4-v1","senemos.root=linux senemos.super=seed4-v1",
        "senemos.root=userdata senemos.super=seed5-v1",
        "senemos.root=userdata senemos.super=seed4-v1 senemos.super=seed4-v1",
        "senemos.root=userdata senemos.role=rescue senemos.super=",
        "senemos.root=userdata senemos.role=rescue senemos.super=seed4-v1/"})invoke(args,-1);
    invoke("senemos.root=userdata senemos.role=rescue",-1,2048,
        "root=PARTLABEL=linux rw rootfstype=ext4,f2fs,xfs,btrfs panic=0 senemos.role=rescue");
    invoke("senemos.root=userdata senemos.super=seed4-v1",-1,2048,
        "root=PARTLABEL=linux rw rootfstype=ext4,f2fs,xfs,btrfs panic=0 senemos.super=seed4-v1");
    invoke("senemos.root=userdata senemos.role=rescue",-1,2048,
        "root=PARTLABEL=linux rw rw rootfstype=ext4,f2fs,xfs,btrfs panic=0");
    invoke("senemos.root=userdata senemos.role=rescue",-1,2048,
        "root=PARTLABEL=linux rootfstype=ext4,f2fs,xfs,btrfs panic=0");
    const std::string args="senemos.root=userdata senemos.role=rescue";
    const auto normal=invoke(args,1);
    bool exact_succeeded=false;
    for(size_t capacity=sizeof(initial);capacity<=normal.size()+1;capacity++) {
        char line[2048];std::strcpy(line,initial);
        const int result=uke_select_root(line,capacity,args.c_str(),args.size()+1);
        if(result<0)assert(!std::strcmp(line,initial));
        else{assert(std::string(line)==normal);exact_succeeded=true;}
        checks++;
    }
    assert(exact_succeeded);
    char line[2048];std::strcpy(line,initial);
    const char embedded[]="senemos.role=rescue\0senemos.root=userdata";
    assert(uke_select_root(line,sizeof(line),embedded,sizeof(embedded))==-1);
    assert(!std::strcmp(line,initial));checks++;
    std::cout<<"PASS: super root "<<checks<<" actual parser cases; normal equivalence, bounded readonly rescue and refusal without mutation; no hardware\n";
}

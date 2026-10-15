// SPDX-License-Identifier: GPL-2.0-only
// Regular-file host fixture; exercises the exact native candidate transform.
#include <libfdt.h>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <iterator>
#include <vector>
#define UKE_INIT
#include "../src/display/uke-abl-native.h"

using Bytes=std::vector<char>;
static Bytes blob(const char *path) {
    std::ifstream file(path,std::ios::binary);
    Bytes result{std::istreambuf_iterator<char>(file),{}};
    assert(result.size()>=40 && result.size()<=2*1024*1024);
    assert(fdt_check_full(result.data(),result.size())==0);
    return result;
}
int main(int argc,char **argv) {
    assert(argc==4);
    const auto original=blob(argv[1]), overlay=blob(argv[2]);
    constexpr auto selected="msm_drm.dsi_display0=qcom,mdss_dsi_o82_42_02_0b_dualdsi_dsc_vid:";
    const auto prepare=[&] {
        Bytes fdt(2*1024*1024);
        assert(fdt_open_into(original.data(),fdt.data(),fdt.size())==0);
        return fdt;
    };
    auto fdt=prepare(), staged=overlay;
    const int result=uke_abl_native(fdt.data(),staged.data(),staged.size(),selected);
    if(result) std::fprintf(stderr,"Native entry refused: %d\n",result);
    assert(result==0);
    int bytes=0;
    assert(!fdt_getprop(fdt.data(),fdt_path_offset(fdt.data(),"/chosen"),"stdout-path",&bytes));
    assert(fdt_path_offset(fdt.data(),"/soc/display-subsystem@ae00000/dsi@ae94000/panel@0")>=0);
    std::ofstream output(argv[3],std::ios::binary);
    output.write(fdt.data(),fdt_totalsize(fdt.data()));
    assert(output.good());
    for(unsigned fault=0;fault<7;fault++) {
        fdt=prepare(); staged=overlay;
        const char *selector=selected;
        if(fault==0) selector="msm_drm.dsi_display0=foreign-panel:";
        if(fault==1) assert(fdt_setprop_string(fdt.data(),0,"compatible","foreign,board")==0);
        if(fault==2) assert(fdt_setprop_string(fdt.data(),fdt_path_offset(fdt.data(),"/chosen"),"stdout-path","/soc/not-framebuffer")==0);
        if(fault==3) staged[0]=0;
        if(fault==4) assert(fdt_del_node(fdt.data(),fdt_path_offset(fdt.data(),"/__symbols__"))==0);
        if(fault==5) assert(fdt_del_node(fdt.data(),fdt_path_offset(fdt.data(),"/soc/display_gpio_regulator_vsp"))==0);
        if(fault==6) assert(fdt_del_node(fdt.data(),fdt_path_offset(fdt.data(),"/soc/display_gpio_regulator_vsn"))==0);
        const auto before=fdt;
        assert(uke_abl_native(fdt.data(),staged.data(),staged.size(),selector)<0);
        assert(fdt==before);
    }
}

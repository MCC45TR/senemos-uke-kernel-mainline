// SPDX-License-Identifier: GPL-2.0-only
// Keep every original Hall DT assertion, then exercise the optional input.
#define main legacy_hall_dt_main
#include "legacy-hall-dt.cpp"
#undef main
static unsigned cases;
static Blob physical_fixture() {
    auto b=fixture();auto f=b.data();
    int n=add(f,fdt_path_offset(f,"/soc"),"pinctrl@f000000");
    assert(!fdt_setprop_u32(f,n,"phandle",77));
    assert(!fdt_setprop(f,n,"gpio-controller",nullptr,0));
    assert(!fdt_setprop_u32(f,n,"#gpio-cells",2));
    n=fdt_path_offset(f,"/soc/xiaomi_hall/lid_hall");
    fdt32_t gpio[]={cpu_to_fdt32(77),cpu_to_fdt32(99),cpu_to_fdt32(1)};
    assert(!fdt_setprop(f,n,"hall_pin",gpio,sizeof(gpio)));
    return b;
}
static void check_physical(void *f) {
    check(f);
    int bytes,n=fdt_path_offset(f,"/hall-lid");
    auto gpio=static_cast<const fdt32_t *>(fdt_getprop(f,n,"state-gpios",&bytes));
    assert(gpio&&bytes==12&&fdt32_to_cpu(gpio[1])==99&&fdt32_to_cpu(gpio[2])==1);
    int controller=fdt_node_offset_by_phandle(f,fdt32_to_cpu(gpio[0]));
    assert(controller==fdt_path_offset(f,"/soc/pinctrl@f000000"));
    assert(!fdt_getprop(f,n,"pinctrl-0",nullptr));
    assert(!fdt_getprop(f,fdt_path_offset(f,"/hall-tablet-mode"),"state-gpios",nullptr));
    ++cases;
}
int main(int argc,char **argv) {
    assert(!legacy_hall_dt_main(0,nullptr));
    auto baseline=physical_fixture(),b=baseline;
    assert(!uke_hall_test(b.data()));check_physical(b.data());
    for(unsigned bad=0;bad<7;++bad) {
        b=baseline;auto f=b.data();
        int n=fdt_path_offset(f,"/soc/xiaomi_hall/lid_hall");
        fdt32_t gpio[]={cpu_to_fdt32(77),cpu_to_fdt32(99),cpu_to_fdt32(1)};
        if(bad==0)gpio[0]=cpu_to_fdt32(78);
        if(bad==1)gpio[1]=cpu_to_fdt32(100);
        if(bad==2)gpio[2]=0;
        assert(!fdt_setprop(f,n,"hall_pin",gpio,bad==3?8:sizeof(gpio)));
        n=fdt_path_offset(f,"/soc/pinctrl@f000000");
        if(bad==4)assert(!fdt_setprop_u32(f,n,"#gpio-cells",3));
        if(bad==5)assert(!fdt_delprop(f,n,"gpio-controller"));
        if(bad==6)assert(!fdt_delprop(f,n,"phandle"));
        assert(uke_hall_test(f)<0);++cases;
    }
    if(argc==2&&argv[1][0]) {
        std::ifstream input(argv[1],std::ios::binary);
        Blob raw{std::istreambuf_iterator<char>(input),{}};assert(!raw.empty());
        Blob expanded(raw.size()+65536);
        assert(!fdt_open_into(raw.data(),expanded.data(),expanded.size()));
        assert(!uke_hall_test(expanded.data()));check_physical(expanded.data());
    }
    std::printf("Actual Hall physical DT: %u wiring/refusal cases and every legacy fixture passed.\n",cases);
}

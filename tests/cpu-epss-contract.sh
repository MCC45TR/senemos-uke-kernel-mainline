#!/usr/bin/env bash
# Run the prepared CPU LUT parser; no MMIO, target device or donor code runs.
set -Eeuo pipefail
file=${1:?Pass prepared qcom-cpufreq-hw.c}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
cat > "$work/check.cpp" <<'CPP'
#include <cassert>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cerrno>
#include <initializer_list>
using u32=uint32_t;
#define LUT_SRC 0xc0000000U
#define LUT_L_VAL 0xffU
#define LUT_CORE_COUNT 0x70000U
#define LUT_VOLT 0xfffU
#define LUT_TURBO_IND 1
#define FIELD_GET(mask,data) (((data)&(mask))>>__builtin_ctz(mask))
#define CPUFREQ_ENTRY_INVALID 0xffffffffU
#define CPUFREQ_TABLE_END 0xfffffffeU
#define CPUFREQ_BOOST_FREQ 1U
#define dev_err(...) ((void)0)
#define dev_warn(...) ((void)0)
#define dev_dbg(...) ((void)0)
#define kzalloc_objs(sample,count) static_cast<decltype(&(sample))>(calloc(count,sizeof(sample)))
#define kfree free
#define IS_ERR(p) ((p)==nullptr)
struct device {};
struct dev_pm_opp {};
struct qcom_cpufreq_soc_data { u32 reg_freq_lut=0,reg_volt_lut=160,lut_row_size=4,lut_max_entries=40; };
struct qcom_cpufreq_data { unsigned char *base; };
struct cpufreq_frequency_table { u32 frequency,flags; };
struct cpufreq_policy { qcom_cpufreq_data *driver_data; bool fast_switch_possible=false; void *cpus=nullptr;
    cpufreq_frequency_table *freq_table=nullptr; };
qcom_cpufreq_soc_data data;
struct { const qcom_cpufreq_soc_data *soc_data=&data; } qcom_cpufreq;
bool target,icc_scaling_enabled;
unsigned long xo_rate=19200000,cpu_hw_rate=300000000;
unsigned int failed_frequency;
int opp_status=-ENODEV;
static bool of_machine_is_compatible(const char *name) { assert(!strcmp(name,"qcom,sm7675")); return target; }
static u32 readl_relaxed(const unsigned char *p) { u32 value; memcpy(&value,p,4); return value; }
static int dev_pm_opp_of_add_table(device *) { return opp_status; }
static dev_pm_opp *dev_pm_opp_find_freq_ceil(device *,unsigned long *) { return nullptr; }
static void dev_pm_opp_put(dev_pm_opp *) {}
static void dev_pm_opp_disable(device *,unsigned long) {}
static void dev_pm_opp_set_sharing_cpus(device *,void *) {}
static int qcom_cpufreq_update_opp(device *,u32 freq,u32 volt) {
    assert(freq>0 && volt==800000); return freq==failed_frequency ? -EIO : 0;
}
CPP
sed -n '/^static int qcom_cpufreq_hw_read_lut(/,/^static void qcom_get_related_cpus(/p' "$file" | sed '$d' >> "$work/check.cpp"
cat >> "$work/check.cpp" <<'CPP'
static cpufreq_frequency_table *run(std::initializer_list<unsigned int> cores) {
    unsigned char memory[320]{};
    unsigned int i=0,previous=0;
    for (unsigned int count : cores) {
        u32 row=(1U<<30)|(count<<16)|(25U<<i);
        if(i==cores.size()-1) row=previous;
        memcpy(memory+4*i,&row,4); previous=row;
        u32 volt=800; memcpy(memory+160+4*i,&volt,4); ++i;
    }
    qcom_cpufreq_data driver{memory}; cpufreq_policy policy{&driver}; device cpu;
    const int ret=qcom_cpufreq_hw_read_lut(&cpu,&policy);
    assert(ret==0 && policy.fast_switch_possible && !icc_scaling_enabled);
    return policy.freq_table;
}
int main() {
    for(unsigned int count : {1,3,4}) {
        target=true; auto *table=run({count,count,count,count});
        for(unsigned int i=0;i<3;i++) assert(table[i].frequency==(480000U<<i) && !table[i].flags);
        assert(table[3].frequency==CPUFREQ_TABLE_END); free(table);
    }
    target=true; auto *table=run({4,4,1,1});
    assert(table[0].frequency==480000 && !table[0].flags);
    assert(table[1].frequency==960000 && !table[1].flags);
    assert(table[2].frequency==1920000 && table[2].flags==CPUFREQ_BOOST_FREQ); free(table);
    target=false; table=run({4,4,1,1});
    assert(table[0].frequency==480000 && table[1].frequency==960000);
    assert(table[2].frequency==1920000 && table[2].flags==CPUFREQ_BOOST_FREQ); free(table);
    target=false; table=run({1,1,1,1});
    assert(table[0].frequency==CPUFREQ_ENTRY_INVALID && table[1].frequency==CPUFREQ_ENTRY_INVALID);
    assert(table[2].frequency==1920000 && table[2].flags==CPUFREQ_BOOST_FREQ); free(table);
    target=true; failed_frequency=960000; table=run({1,1,1,1});
    assert(table[0].frequency==480000 && table[1].frequency==CPUFREQ_ENTRY_INVALID && table[2].frequency==1920000); free(table);
}
CPP
"${CXX:-g++}" -std=c++20 -O2 -Wall -Wextra -Werror -Wno-unused-but-set-variable -fsanitize=undefined -fsanitize-undefined-trap-on-error "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Real EPSS LUT parser: 3/4/1-core domains, reduced-core boost, OPP refusal and unchanged legacy behavior passed\n'

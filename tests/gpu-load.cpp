// SPDX-License-Identifier: MIT
#include <atomic>
#include <cassert>
#include <cerrno>
#include <cstdarg>
#include <cstdio>
#include <cstring>
#include <limits>
#include <sys/types.h>
using u64 = unsigned long long;
struct msm_gpu { std::atomic<u64> engine_ns{}; };
struct device { device* parent{}; msm_gpu* gpu{}; };
struct device_attribute {};
static msm_gpu* dev_to_gpu(device* dev) { return dev->gpu; }
static u64 atomic64_read(std::atomic<u64>* counter) { return counter->load(); }
static ssize_t sysfs_emit(char* output, const char* format, ...) {
    va_list args; va_start(args,format);
    int length=std::vsnprintf(output,128,format,args); va_end(args); return length;
}
#include "reader.inc"
int main() {
    msm_gpu gpu; device parent{nullptr,&gpu}, dev{&parent,nullptr}; char output[128]{};
    auto read=[&] { return gpu_engine_ns_show(&dev,nullptr,output); };
    assert(read()==2&&std::strcmp(output,"0\n")==0);
    gpu.engine_ns=123456789;
    assert(read()==10&&std::strcmp(output,"123456789\n")==0);
    assert(read()==10&&gpu.engine_ns==123456789);
    gpu.engine_ns=std::numeric_limits<u64>::max();
    assert(read()==21&&std::strcmp(output,"18446744073709551615\n")==0);
    parent.gpu=nullptr; assert(read()==-ENODEV);
    std::puts("GPU counter reader: idle, full-width, repeated read, missing device and no hardware sampling passed");
}

#!/usr/bin/env bash
# Actual decoder/encoder initialization; host-only allocation/control providers.
set -Eeuo pipefail
iris=${1:?Pass the prepared Iris directory}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
cat > "$work/check.cpp" <<'CPP'
#include <cassert>
#include <cerrno>
#include <cstring>
#include <ctime>
#include <set>
#include <type_traits>
#include <linux/videodev2.h>
using u32=unsigned;
enum { BUF_INPUT, BUF_OUTPUT, INST_FW_CAP_MAX=4, MAXIMUM_FPS=480, DEFAULT_FPS=30 };
#define DEFAULT_WIDTH 320
#define DEFAULT_HEIGHT 240
#define ALIGN(x,a) (((x)+(a)-1)&~((a)-1))
struct platform_inst_fw_cap { u32 value; };
struct iris_core { platform_inst_fw_cap inst_fw_caps_dec[4], inst_fw_caps_enc[4]; };
struct iris_inst {
    iris_core *core;
    v4l2_format *fmt_src, *fmt_dst;
    u32 fw_min_count, codec, frame_rate, operating_rate;
    u32 enc_raw_width, enc_raw_height, enc_scale_width, enc_scale_height;
    struct { u32 min_count, size; } buffers[2];
    v4l2_rect crop;
    platform_inst_fw_cap fw_caps[4];
};
static unsigned allocations, fail_at, controls;
static int control_error;
static std::set<void *> live;
template<class T> static T *allocate() {
    if (++allocations==fail_at) return nullptr;
    auto *p=new T{}; assert(live.insert(p).second); return p;
}
#define kzalloc_obj(P) allocate<std::remove_reference_t<decltype(P)>>()
template<class T> [[maybe_unused]] static void kfree(T *p) {
    if (p) { assert(live.erase(p)==1); delete p; }
}
static u32 iris_get_buffer_size(iris_inst *, int) { return 4096; }
static u32 iris_vpu_buf_count(iris_inst *, int) { return 4; }
static int iris_ctrls_init(iris_inst *) { ++controls; return control_error; }
CPP
for role in vdec venc; do
    awk -v role="$role" '$0 ~ "^int iris_" role "_inst_init\\(" {emit=1} emit {print} emit && /^}/ {exit}' \
        "$iris/iris_$role.c" >> "$work/check.cpp"
done
cat >> "$work/check.cpp" <<'CPP'
int main() {
    iris_core core{};
    using init_fn=int (*)(iris_inst *);
    for (init_fn init : {iris_vdec_inst_init,iris_venc_inst_init}) {
        for (unsigned fault : {1U,2U,0U}) {
            for (int error : {0,-EIO}) {
                iris_inst inst{}; inst.core=&core;
                allocations=controls=0; fail_at=fault; control_error=error;
                int ret=init(&inst);
                if (fault) {
                    assert(ret==-ENOMEM && !controls && live.size()==1);
                } else {
                    assert(ret==error && controls==1 && live.size()==2);
                    assert(inst.fmt_src->type==V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE);
                    assert(inst.fmt_dst->type==V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE);
                }
                // The caller owns both fields on success and failure.
                kfree(inst.fmt_dst); kfree(inst.fmt_src); assert(live.empty());
            }
        }
    }
}
CPP
"${CXX:-g++}" -std=c++20 -O2 -Wall -Wextra -Werror "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Actual Iris format initialization: both allocations, control failure and caller-owned cleanup passed\n'

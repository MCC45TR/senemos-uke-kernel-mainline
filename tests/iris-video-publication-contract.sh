#!/usr/bin/env bash
# Actual registration/open/release functions; host-only V4L2 and kref model.
set -Eeuo pipefail
iris=${1:?Pass the prepared Iris directory}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
cat > "$work/check.cpp" <<'CPP'
#include <cassert>
#include <cerrno>
#include <cstddef>
#include <cstring>
using u32 = unsigned;
struct kref { unsigned count; };
static void kref_init(kref *r) { r->count=1; }
static void kref_get(kref *r) { assert(r->count); ++r->count; }
static void kref_put(kref *r, void (*release)(kref *)) {
    assert(r->count); if (!--r->count) release(r);
}
#define container_of(p,t,m) reinterpret_cast<t *>(reinterpret_cast<char *>(p)-offsetof(t,m))
#define READ_ONCE(x) (x)
#define WRITE_ONCE(x,v) ((x)=(v))
#define smp_load_acquire(p) __atomic_load_n(p,__ATOMIC_ACQUIRE)
#define smp_store_release(p,x) __atomic_store_n(p,x,__ATOMIC_RELEASE)
#define dev_err(...) ((void)0)
struct device {};
struct v4l2_device { bool registered; };
struct video_device {
    void (*release)(video_device *);
    void *fops, *ioctl_ops, *data;
    v4l2_device *v4l2_dev;
    unsigned vfl_dir, device_caps, refs;
    char name[64];
};
struct file { video_device *video; };
enum domain_type { DECODER=1, ENCODER=2 };
enum { VFL_DIR_M2M, VFL_TYPE_VIDEO, V4L2_CAP_VIDEO_M2M_MPLANE=1, V4L2_CAP_STREAMING=2,
       IRIS_INST_DEINIT=0, BUF_BIN=0, BUF_ARP, BUF_COMV, BUF_NON_COMV, BUF_LINE,
       BUF_DPB, BUF_PERSIST, BUF_SCRATCH_1, BUF_SCRATCH_2, BUF_VPSS, BUF_PARTIAL };
struct iris_inst;
struct iris_hfi_sys_ops { iris_inst *(*sys_get_instance)(); };
struct iris_core {
    kref ref;
    bool video_ready, removing;
    device *dev;
    int lock, lifecycle_lock;
    v4l2_device v4l2_dev;
    video_device *vdev_dec, *vdev_enc;
    void *iris_v4l2_file_ops, *iris_v4l2_ioctl_ops_dec, *iris_v4l2_ioctl_ops_enc;
    const iris_hfi_sys_ops *hfi_sys_ops;
};
struct m2m_dev {};
struct m2m_ctx {};
struct iris_inst {
    iris_core *core;
    u32 domain, session_id, state;
    int lock, ctx_q_lock, completion, flush_completion;
    struct { int list; } buffers[11];
    struct { struct m2m_ctx *m2m_ctx; } fh;
    struct m2m_dev *m2m_dev;
    struct m2m_ctx *m2m_ctx;
};
static unsigned alloc_calls, register_calls, video_frees, core_frees, destroyed;
static unsigned pm_calls, v4l2_registers, v4l2_unregisters, unregisters, open_checks;
static unsigned fail_alloc, fail_register;
static bool fail_parent, hold_decoder, driver_live;
static int deinit_error;
static iris_core *expected;
static video_device *delayed;
static device dev;
int iris_open(file *);
static void mutex_destroy(int *) { ++destroyed; }
static void mutex_init(int *m) { *m=0; }
static void kfree(iris_core *c) { assert(!driver_live); ++core_frees; delete c; }
[[maybe_unused]] static void kfree(iris_inst *i) { delete i; }
static video_device *video_device_alloc() {
    if (++alloc_calls==fail_alloc) return nullptr;
    auto *v=new video_device{}; v->refs=1; return v;
}
static void video_device_release(video_device *v) { ++video_frees; delete v; }
static void video_set_drvdata(video_device *v, void *p) { v->data=p; }
static iris_core *video_get_drvdata(video_device *v) { return static_cast<iris_core *>(v->data); }
static iris_core *video_drvdata(file *f) { return video_get_drvdata(f->video); }
static video_device *video_devdata(file *f) { return f->video; }
static void video_put(video_device *v) { assert(v->refs); if (!--v->refs) v->release(v); }
static void check_denied(video_device *v) {
    file f{v}; unsigned previous=pm_calls;
    assert(video_get_drvdata(v)==expected);
    assert(iris_open(&f)==-ENODEV && pm_calls==previous); ++open_checks;
}
static int video_register_device(video_device *v, int, int) {
    ++register_calls;
    if (register_calls==fail_register) return -EIO;
    check_denied(v);
    if (hold_decoder && register_calls==1) { ++v->refs; delayed=v; }
    return 0;
}
static void video_unregister_device(video_device *v) {
    if (!v) return;
    check_denied(v); ++unregisters; video_put(v);
}
static int v4l2_device_register(device *, v4l2_device *v) {
    ++v4l2_registers;
    if (fail_parent) return -EIO;
    v->registered=true; return 0;
}
static void v4l2_device_unregister(v4l2_device *v) {
    assert(v->registered); v->registered=false; ++v4l2_unregisters;
}
static void iris_core_stop_recovery(iris_core *c) { assert(!c->video_ready); c->removing=true; }
static int iris_core_deinit(iris_core *c) { assert(!c->video_ready); return deinit_error; }
static int pm_runtime_resume_and_get(device *d) { assert(d==&dev); ++pm_calls; return -EAGAIN; }
static int iris_core_init(iris_core *) { assert(false); return -EIO; }
static void pm_runtime_put_sync(device *) { assert(false); }
static u32 hash32_ptr(iris_inst *) { return 1; }
static void INIT_LIST_HEAD(int *) {}
static void init_completion(int *) {}
static void iris_v4l2_fh_init(iris_inst *, file *) {}
static void iris_v4l2_fh_deinit(iris_inst *, file *) {}
static int iris_m2m_ops, iris_m2m_queue_init;
static m2m_dev *v4l2_m2m_init(int *) { return nullptr; }
static m2m_ctx *v4l2_m2m_ctx_init(m2m_dev *, iris_inst *, int) { return nullptr; }
template<class T> static bool IS_ERR_OR_NULL(T *p) { return !p; }
static void v4l2_m2m_ctx_release(m2m_ctx *) {}
static void v4l2_m2m_release(m2m_dev *) {}
static int iris_vdec_inst_init(iris_inst *) { return 0; }
static int iris_venc_inst_init(iris_inst *) { return 0; }
static void iris_add_session(iris_inst *) {}
static void strscpy(char *dst, const char *src, size_t n) { assert(std::strlen(src)<n); std::strcpy(dst,src); }
CPP
for name in iris_core_release iris_core_put iris_video_device_release iris_register_video_device \
    iris_register_video_devices iris_unregister_video_devices; do
    awk -v name="$name" '$0 ~ "^(static )?(void|int) " name "\\(" {emit=1} emit {print} emit && /^}/ {exit}' \
        "$iris/iris_probe.c" | sed 's/struct iris_core \*core = data;/struct iris_core *core = (struct iris_core *)data;/' >> "$work/check.cpp"
done
awk '/^int iris_open\(/ {emit=1} emit {print} emit && /^}/ {exit}' "$iris/iris_vidc.c" >> "$work/check.cpp"
cat >> "$work/check.cpp" <<'CPP'
static iris_core *reset() {
    alloc_calls=register_calls=video_frees=core_frees=destroyed=pm_calls=0;
    v4l2_registers=v4l2_unregisters=unregisters=open_checks=0;
    fail_alloc=fail_register=0; fail_parent=hold_decoder=false; driver_live=true; deinit_error=0; delayed=nullptr;
    expected=new iris_core{}; expected->dev=&dev; kref_init(&expected->ref); return expected;
}
static void drop_driver(iris_core *c) { driver_live=false; iris_core_put(c); }
static void final_check(unsigned videos) { assert(core_frees==1 && destroyed==2 && video_frees==videos); }
int main() {
    auto *c=reset(); c->removing=true;
    assert(iris_register_video_devices(c)==-ENODEV && !v4l2_registers);
    drop_driver(c); final_check(0);
    c=reset(); fail_parent=true;
    assert(iris_register_video_devices(c)==-EIO && !alloc_calls && !c->video_ready);
    drop_driver(c); final_check(0);
    for (unsigned fault=1; fault<=2; ++fault) {
        c=reset(); fail_alloc=fault;
        assert(iris_register_video_devices(c)==-ENOMEM && !c->video_ready);
        assert(!c->vdev_dec && !c->vdev_enc && !pm_calls && v4l2_unregisters==1);
        drop_driver(c); final_check(fault-1);
        c=reset(); fail_register=fault;
        assert(iris_register_video_devices(c)==-EIO && !c->video_ready);
        assert(!c->vdev_dec && !c->vdev_enc && !pm_calls && v4l2_unregisters==1);
        drop_driver(c); final_check(fault);
    }
    c=reset();
    assert(iris_register_video_device(c,static_cast<domain_type>(3))==-EINVAL);
    assert(c->ref.count==1 && !register_calls); drop_driver(c); final_check(1);
    c=reset(); hold_decoder=true; fail_register=2;
    assert(iris_register_video_devices(c)==-EIO && delayed && !c->video_ready);
    drop_driver(c); assert(!core_frees && video_frees==1 && !destroyed);
    check_denied(delayed); video_put(delayed); final_check(2);
    for (int error : {0,-EIO}) {
        c=reset(); hold_decoder=true;
        assert(iris_register_video_devices(c)==0 && c->video_ready && open_checks==2);
        file f{c->vdev_dec}; assert(iris_open(&f)==-EAGAIN && pm_calls==1);
        deinit_error=error; iris_unregister_video_devices(c);
        assert(!c->video_ready && !c->vdev_dec && !c->vdev_enc && unregisters==2);
        drop_driver(c); assert(!core_frees && !destroyed);
        check_denied(delayed); video_put(delayed); final_check(2);
    }
    file no_core{new video_device{}};
    assert(iris_open(&no_core)==-ENODEV); delete no_core.video;
}
CPP
"${CXX:-g++}" -std=c++20 -O2 -Wall -Wextra -Werror -Wno-unused-parameter \
    -Wno-unused-function -include initializer_list "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Actual Iris video publication: paired readiness, registration faults and delayed core release passed\n'

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
#include <vector>
#include <algorithm>
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
struct iris_inst;
struct file { video_device *video; iris_inst *instance=nullptr; };
enum domain_type { DECODER=1, ENCODER=2 };
enum { VFL_DIR_M2M, VFL_TYPE_VIDEO, V4L2_CAP_VIDEO_M2M_MPLANE=1, V4L2_CAP_STREAMING=2,
       IRIS_INST_DEINIT=0, BUF_BIN=0, BUF_ARP, BUF_COMV, BUF_NON_COMV, BUF_LINE,
       BUF_DPB, BUF_PERSIST, BUF_SCRATCH_1, BUF_SCRATCH_2, BUF_VPSS, BUF_PARTIAL };
struct iris_inst;
struct instance_link { iris_inst *owner; };
struct platform_data { unsigned max_session_count; };
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
    const platform_data *iris_platform_data;
    std::vector<iris_inst *> instances;
    int state;
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
    instance_link list;
    int ctrl_handler;
    int *fmt_src, *fmt_dst;
};
static unsigned alloc_calls, register_calls, video_frees, core_frees, destroyed;
static unsigned pm_calls, v4l2_registers, v4l2_unregisters, unregisters, open_checks;
static unsigned fail_alloc, fail_register;
static bool fail_parent, hold_decoder, driver_live;
static int deinit_error;
static iris_core *expected;
static video_device *delayed;
static device dev;
static const platform_data platform{2};
enum { IRIS_CORE_INIT=1 };
static int pm_error, init_error;
static unsigned next_session_id, inst_live, inst_frees, formats_live, ctrls_live, fh_live, m2m_live, ctx_live;
static unsigned fault_instance;
static bool fault_m2m, fault_ctx;
static int admission_race;
int iris_open(file *);
static void mutex_destroy(int *m) { assert(!*m); ++destroyed; }
static void mutex_init(int *m) { *m=0; }
static void mutex_lock(int *m) { assert(!*m); *m=1; }
static void mutex_unlock(int *m) { assert(*m==1); *m=0; }
static void kfree(iris_core *c) { assert(!driver_live); ++core_frees; delete c; }
[[maybe_unused]] static void kfree(iris_inst *i) { assert(inst_live); --inst_live; ++inst_frees; delete i; }
static void kfree(int *p) { if (p) { assert(formats_live); --formats_live; delete p; } }
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
static int pm_runtime_resume_and_get(device *d) { assert(d==&dev); ++pm_calls; return pm_error; }
static int iris_core_init(iris_core *) { return 0; }
static void pm_runtime_put_sync(device *) {}
static u32 hash32_ptr(iris_inst *) { return next_session_id++; }
static void INIT_LIST_HEAD(int *) {}
static void init_completion(int *) {}
static void iris_v4l2_fh_init(iris_inst *i, file *f) { ++fh_live; f->instance=i; }
static void iris_v4l2_fh_deinit(iris_inst *i, file *f) { assert(fh_live && f->instance==i); --fh_live; f->instance=nullptr; }
static iris_inst *iris_get_inst(file *f) { return f->instance; }
static int iris_m2m_ops, iris_m2m_queue_init;
static m2m_dev *v4l2_m2m_init(int *) { if (fault_m2m) return nullptr; ++m2m_live; return new m2m_dev; }
static m2m_ctx *v4l2_m2m_ctx_init(m2m_dev *, iris_inst *, int) { if (fault_ctx) return nullptr; ++ctx_live; return new m2m_ctx; }
template<class T> static bool IS_ERR_OR_NULL(T *p) { return !p; }
static void v4l2_m2m_ctx_release(m2m_ctx *p) { assert(ctx_live); --ctx_live; delete p; }
static void v4l2_m2m_release(m2m_dev *p) { assert(m2m_live); --m2m_live; delete p; }
static int init_formats(iris_inst *i) {
    i->fmt_src=new int{}; i->fmt_dst=new int{}; formats_live+=2;
    i->ctrl_handler=1; ++ctrls_live;
    if (admission_race==1) i->core->removing=true;
    if (admission_race==2) i->core->video_ready=false;
    if (admission_race==3) i->core->state=0;
    return init_error;
}
static int iris_vdec_inst_init(iris_inst *i) { return init_formats(i); }
static int iris_venc_inst_init(iris_inst *i) { return init_formats(i); }
static int v4l2_ctrl_handler_free(int *p) { if (*p) { assert(ctrls_live); --ctrls_live; *p=0; } return 0; }
static iris_inst *create_inst() {
    if (fault_instance) return nullptr;
    auto *i=new iris_inst{}; ++inst_live; i->list.owner=i; return i;
}
static const iris_hfi_sys_ops hfi{create_inst};
#define list_for_each_entry(p,h,m) for (size_t idx=0; idx<(h)->size() && ((p)=(*(h))[idx],true); ++idx)
#define list_for_each_entry_safe(p,n,h,m) for (size_t idx=0; idx<(h)->size() && ((p)=(*(h))[idx],(n)=nullptr,(void)(n),true); ++idx)
static void list_add_tail(instance_link *l, std::vector<iris_inst *> *v) { assert(l->owner->core->lock==1); v->push_back(l->owner); }
static void list_del_init(instance_link *l) {
    auto &v=l->owner->core->instances; assert(l->owner->core->lock==1);
    auto p=std::find(v.begin(),v.end(),l->owner); assert(p!=v.end()); v.erase(p);
}
enum { V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE=1, V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE=2 };
static void iris_session_close(iris_inst *i) { assert(i->state==IRIS_INST_DEINIT); }
static void iris_inst_change_state(iris_inst *i, u32 state) { i->state=state; }
static void iris_destroy_all_internal_buffers(iris_inst *, unsigned) {}
static void iris_check_num_queued_internal_buffers(iris_inst *, unsigned) {}
static void strscpy(char *dst, const char *src, size_t n) { assert(std::strlen(src)<n); std::strcpy(dst,src); }
CPP
for name in iris_core_release iris_core_put iris_video_device_release iris_register_video_device \
    iris_register_video_devices iris_unregister_video_devices; do
    awk -v name="$name" '$0 ~ "^(static )?(void|int) " name "\\(" {emit=1} emit {print} emit && /^}/ {exit}' \
        "$iris/iris_probe.c" | sed 's/struct iris_core \*core = data;/struct iris_core *core = (struct iris_core *)data;/' >> "$work/check.cpp"
done
for name in iris_add_session iris_remove_session iris_open iris_close; do
    awk -v name="$name" '$0 ~ "^(static )?(void|int) " name "\\(" {emit=1} emit {print} emit && /^}/ {exit}' \
        "$iris/iris_vidc.c" >> "$work/check.cpp"
done
cat >> "$work/check.cpp" <<'CPP'
static iris_core *reset() {
    alloc_calls=register_calls=video_frees=core_frees=destroyed=pm_calls=0;
    v4l2_registers=v4l2_unregisters=unregisters=open_checks=0;
    fail_alloc=fail_register=0; fail_parent=hold_decoder=false; driver_live=true; deinit_error=0; delayed=nullptr;
    pm_error=-EAGAIN; init_error=0; next_session_id=1; fault_instance=0; fault_m2m=fault_ctx=false; admission_race=0;
    inst_live=inst_frees=formats_live=ctrls_live=fh_live=m2m_live=ctx_live=0;
    expected=new iris_core{}; expected->dev=&dev; kref_init(&expected->ref);
    expected->iris_platform_data=&platform; expected->state=IRIS_CORE_INIT; expected->hfi_sys_ops=&hfi; return expected;
}
static void drop_driver(iris_core *c) { driver_live=false; iris_core_put(c); }
static void final_check(unsigned videos) {
    assert(core_frees==1 && destroyed==2+2*inst_frees && video_frees==videos);
    assert(!inst_live && !formats_live && !ctrls_live && !fh_live && !m2m_live && !ctx_live);
}
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
    for (unsigned domain=0; domain<2; ++domain) {
        for (unsigned fault=0; fault<9; ++fault) {
            c=reset(); assert(iris_register_video_devices(c)==0); pm_error=0;
            file f{domain ? c->vdev_enc : c->vdev_dec};
            int wanted=0;
            if (fault==1) { fault_instance=1; wanted=-ENOMEM; }
            if (fault==2) { fault_m2m=true; wanted=-EINVAL; }
            if (fault==3) { fault_ctx=true; wanted=-EINVAL; }
            if (fault==4) { init_error=-EREMOTEIO; wanted=-EREMOTEIO; }
            if (fault>=5 && fault<=7) { admission_race=fault-4; wanted=fault==7 ? -EIO : -ENODEV; }
            if (fault==8) { next_session_id=0; wanted=-EINVAL; }
            assert(iris_open(&f)==wanted);
            if (!fault) { assert(c->instances.size()==1 && f.instance); assert(iris_close(&f)==0); }
            assert(c->instances.empty()); iris_unregister_video_devices(c); drop_driver(c); final_check(2);
        }
    }
    c=reset(); assert(iris_register_video_devices(c)==0); pm_error=0;
    file f{c->vdev_dec}; assert(iris_open(&f)==0); auto *first=f.instance;
    file duplicate{c->vdev_dec};
    next_session_id=first->session_id; assert(iris_open(&duplicate)==-EEXIST && c->instances.size()==1);
    file second{c->vdev_enc}, third{c->vdev_dec};
    assert(iris_open(&second)==0 && c->instances.size()==2);
    assert(iris_open(&third)==-EBUSY && c->instances.size()==2);
    assert(iris_close(&f)==0 && iris_close(&second)==0 && c->instances.empty());
    platform_data zero{0}; c->iris_platform_data=&zero;
    assert(iris_open(&f)==-EBUSY && c->instances.empty());
    iris_unregister_video_devices(c); drop_driver(c); final_check(2);
}
CPP
"${CXX:-g++}" -std=c++20 -O2 -Wall -Wextra -Werror -Wno-unused-parameter \
    -Wno-unused-function -include initializer_list "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Actual Iris video/open: paired readiness, core lifetime, admission faults and complete CPU unwind passed\n'

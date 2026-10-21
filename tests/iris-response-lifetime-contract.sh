#!/usr/bin/env bash
# Actual lookup, response guards and close; threaded host-only provider model.
set -Eeuo pipefail
iris=${1:?Pass the prepared Iris directory}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
cat > "$work/check.cpp" <<'CPP'
#include <algorithm>
#include <atomic>
#include <cassert>
#include <cerrno>
#include <chrono>
#include <future>
#include <mutex>
#include <thread>
#include <vector>
using u32=unsigned;
struct mutex { std::mutex native; };
struct iris_core;
struct iris_inst;
struct link { iris_inst *owner; };
struct iris_core { mutex lock, response_lock; std::vector<iris_inst *> instances; void *dev; };
struct m2m_ctx { bool streaming[2]{true,true}; };
struct m2m_dev {};
struct iris_inst {
    iris_core *core;
    mutex lock,ctx_q_lock;
    u32 session_id,state;
    struct link list;
    int ctrl_handler;
    struct m2m_ctx *m2m_ctx;
    struct m2m_dev *m2m_dev;
    int *fmt_src,*fmt_dst;
};
struct file { iris_inst *inst; };
struct iris_hfi_header { u32 session_id; };
enum { IRIS_INST_DEINIT=0, V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE=0,
       V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE=1 };
static thread_local std::vector<mutex *> held;
static thread_local bool closer,late;
static iris_core *active_core;
static unsigned generation;
static int stream_error[2], forwarded_error;
static std::atomic<unsigned> readers,alive,responses,destroyed,stops;
static std::atomic<bool> detached,close_ack,final_phase,announced;
static std::promise<void> lookup_ready,allow_late,guard_ready;
static std::future<void> lookup_event,allow_event,guard_event;
static std::thread late_thread;
static bool is_held(mutex *m) { return std::find(held.begin(),held.end(),m)!=held.end(); }
static void wait(std::future<void> &f) {
    assert(f.wait_for(std::chrono::seconds(3))==std::future_status::ready); f.get();
}
static void mutex_lock(mutex *m) {
    assert(!is_held(m));
    if (closer && m==&active_core->response_lock && final_phase && !announced.exchange(true))
        guard_ready.set_value();
    m->native.lock(); held.push_back(m);
}
static void mutex_unlock(mutex *m) {
    auto p=std::find(held.begin(),held.end(),m); assert(p!=held.end()); held.erase(p); m->native.unlock();
}
static void mutex_destroy(mutex *m) {
    assert(!is_held(m) && m->native.try_lock()); m->native.unlock(); ++destroyed;
}
#define lockdep_assert_held(p) assert(is_held(p))
#define lockdep_assert_not_held(p) assert(!is_held(p))
#define list_for_each_entry(p,h,m) for (size_t idx=0; idx<(h)->size() && ((p)=(*(h))[idx],true); ++idx)
#define list_for_each_entry_safe(p,n,h,m) for (size_t idx=0; idx<(h)->size() && ((p)=(*(h))[idx],(n)=nullptr,(void)(n),true); ++idx)
static void list_del_init(struct link *l) {
    assert(is_held(&l->owner->core->lock));
    auto &v=l->owner->core->instances;
    auto p=std::find(v.begin(),v.end(),l->owner); assert(p!=v.end()); v.erase(p); detached=true;
}
#define dev_err(...) ((void)0)
struct iris_inst *iris_get_instance(iris_core *,u32);
static int process(iris_core *c, u32 id) {
    auto *i=iris_get_instance(c,id);
    if (!i) return -EINVAL;
    ++readers;
    if (late) { lookup_ready.set_value(); wait(allow_event); }
    mutex_lock(&i->lock);
    assert(alive==6 && i->ctrl_handler && i->fmt_src && i->fmt_dst && i->m2m_ctx);
    ++responses;
    mutex_unlock(&i->lock); --readers;
    return forwarded_error;
}
static void iris_hfi_gen1_handle_response_locked(iris_core *c,void *p) {
    process(c,static_cast<iris_hfi_header *>(p)->session_id);
}
static int iris_hfi_gen2_handle_session_response_locked(iris_core *c,iris_hfi_header *h) {
    return process(c,h->session_id);
}
static void iris_hfi_gen1_handle_response(iris_core *,void *);
static int iris_hfi_gen2_handle_session_response(iris_core *,iris_hfi_header *);
static int dispatch(iris_core *c,u32 id) {
    iris_hfi_header h{id};
    if (generation==1) { iris_hfi_gen1_handle_response(c,&h); return 0; }
    return iris_hfi_gen2_handle_session_response(c,&h);
}
static iris_inst *iris_get_inst(file *f) { return f->inst; }
static int v4l2_m2m_streamoff(file *f,m2m_ctx *ctx,unsigned type) {
    assert(!is_held(&f->inst->core->response_lock) && !is_held(&f->inst->lock));
    assert(stops++==type && alive==6);
    if (stream_error[type]) return stream_error[type];
    dispatch(f->inst->core,f->inst->session_id); ctx->streaming[type]=false; return 0;
}
static void iris_session_close(iris_inst *i) {
    assert(is_held(&i->lock) && !is_held(&i->core->response_lock) && stops==2 && alive==6);
    mutex_unlock(&i->lock); dispatch(i->core,i->session_id); mutex_lock(&i->lock); close_ack=true;
    late_thread=std::thread([i] { late=true; dispatch(i->core,i->session_id); assert(held.empty()); });
    wait(lookup_event); final_phase=true;
}
static void iris_inst_change_state(iris_inst *i,u32 state) { assert(is_held(&i->lock)); i->state=state; }
static void before_free() {
    assert(detached && !readers && close_ack && stops==2 && !is_held(&active_core->response_lock));
    assert(alive); --alive;
}
static int v4l2_ctrl_handler_free(int *p) { before_free(); assert(*p); *p=0; return 0; }
static void v4l2_m2m_ctx_release(m2m_ctx *p) {
    assert(detached && !readers && !is_held(&active_core->response_lock));
    // A refused streamoff may leave cancellation to the framework's release.
    for (bool pending:p->streaming) if (pending) dispatch(active_core,42);
    before_free(); delete p;
}
static void v4l2_m2m_release(m2m_dev *p) { before_free(); delete p; }
static void iris_v4l2_fh_deinit(iris_inst *i,file *f) { assert(is_held(&i->lock)); f->inst=nullptr; }
static void iris_destroy_all_internal_buffers(iris_inst *i,unsigned) { assert(is_held(&i->lock)); }
static void iris_check_num_queued_internal_buffers(iris_inst *i,unsigned) { assert(is_held(&i->lock)); }
static void kfree(int *p) { before_free(); delete p; }
static void kfree(iris_inst *i) { before_free(); delete i; }
CPP
{
    awk '/^struct iris_inst \*iris_get_instance\(/ {emit=1} emit {print} emit && /^}/ {exit}' \
        "$iris/iris_utils.c"
    for name in iris_remove_session iris_close; do
        awk -v name="$name" '$0 ~ "^(static )?(void|int) " name "\\(" {emit=1} emit {print} emit && /^}/ {exit}' \
            "$iris/iris_vidc.c"
    done
    awk '/^static void iris_hfi_gen1_handle_response\(/ {emit=1} emit {print} emit && /^}/ {exit}' \
        "$iris/iris_hfi_gen1_response.c"
    awk '/^static int iris_hfi_gen2_handle_session_response\(/ {emit=1} emit {print} emit && /^}/ {exit}' \
        "$iris/iris_hfi_gen2_response.c"
} >> "$work/check.cpp"
cat >> "$work/check.cpp" <<'CPP'
int main() {
    for (unsigned gen : {1U,2U}) for (unsigned errors=0; errors<4; ++errors) {
        iris_core core{}; active_core=&core; generation=gen;
        readers=responses=destroyed=stops=0; alive=6;
        detached=close_ack=final_phase=announced=false;
        stream_error[0]=(errors&1) ? -EIO : 0; stream_error[1]=(errors&2) ? -EREMOTEIO : 0;
        lookup_ready=std::promise<void>{}; allow_late=std::promise<void>{}; guard_ready=std::promise<void>{};
        lookup_event=lookup_ready.get_future(); allow_event=allow_late.get_future(); guard_event=guard_ready.get_future();
        auto *i=new iris_inst{}; i->core=&core; i->session_id=42; i->list.owner=i; i->ctrl_handler=1;
        i->m2m_ctx=new m2m_ctx; i->m2m_dev=new m2m_dev; i->fmt_src=new int{}; i->fmt_dst=new int{};
        core.instances.push_back(i); file f{i};
        forwarded_error=-EREMOTEIO;
        assert(dispatch(&core,42)==(gen==1 ? 0 : -EREMOTEIO)); forwarded_error=0;
        int result=0;
        std::thread close_thread([&] { closer=true; result=iris_close(&f); assert(held.empty()); });
        wait(guard_event); assert(!detached && alive==6 && readers==1);
        allow_late.set_value(); close_thread.join(); late_thread.join();
        assert(result==(stream_error[0] ? stream_error[0] : stream_error[1]));
        assert(detached && !alive && !readers && destroyed==2 && core.instances.empty() && !f.inst);
        auto previous=responses.load(); dispatch(&core,42); assert(responses==previous && held.empty());
    }
}
CPP
"${CXX:-g++}" -std=c++20 -O2 -pthread -Wall -Wextra -Werror -Wno-unused-function \
    "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Actual Iris response lifetime: both guards, live ACKs, delayed lookup, close ordering and API errors passed\n'

#!/usr/bin/env bash
# Actual result/port/latch functions; host-only completion and HFI providers.
set -Eeuo pipefail
iris=${1:?Pass the prepared Iris directory}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
cat > "$work/check.cpp" <<'CPP'
#include <cassert>
#include <cerrno>
#include <functional>
#include <initializer_list>
#include <type_traits>
#include <utility>
using u32=unsigned;
enum { DECODER=1, ENCODER=2, IRIS_INST_DEINIT=0, IRIS_INST_INIT=1, IRIS_INST_ERROR=2,
       HFI_PORT_NONE=0, HFI_PORT_RAW=1, HFI_PORT_BITSTREAM=2, HFI_FW_FLAGS_SUCCESS=1,
       HFI_CMD_CLOSE=1, HFI_CMD_STOP=2, HFI_CMD_BUFFER=3, HFI_CMD_SETTINGS_CHANGE=4, HFI_CMD_DRAIN=5,
       V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE=9, V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE=10,
       HW_RESPONSE_TIMEOUT_VALUE=100, HFI_HOST_FLAGS_RESPONSE_REQUIRED=1,
       HFI_HOST_FLAGS_INTR_REQUIRED=2, HFI_HOST_FLAGS_NON_DISCARDABLE=4, HFI_PAYLOAD_NONE=0 };
enum iris_buffer_type { BUF_INPUT, BUF_OUTPUT };
struct completion { bool initialized; unsigned done; };
struct iris_core {};
struct iris_inst;
struct iris_hfi_session_ops { int (*session_close)(iris_inst *); int (*session_stop)(iris_inst *,u32); };
struct m2m_ctx {};
struct iris_inst {
    const iris_hfi_session_ops *hfi_session_ops;
    iris_core *core;
    u32 domain,state,session_id;
    int lock,streamoff_error;
    struct completion completion,flush_completion;
    struct m2m_ctx *m2m_ctx;
};
struct file { iris_inst *inst; };
struct iris_hfi_packet { u32 type,port,flags; };
struct iris_hfi_header { unsigned size; u32 type,port,flags; };
struct iris_inst_hfi_gen2 {
    iris_inst inst;
    iris_hfi_header *packet;
    struct completion input_stop,output_stop;
};
#define to_iris_inst_hfi_gen2(p) reinterpret_cast<iris_inst_hfi_gen2 *>(p)
static bool allocation_failure;
template<class T> static T *allocate() { return allocation_failure ? nullptr : new T{}; }
#define kzalloc_obj(P) allocate<std::remove_reference_t<decltype(P)>>()
static iris_inst *active;
static iris_core provider;
static iris_hfi_header packet;
static std::function<void()> response;
static std::function<void(iris_inst *,completion *)> before_response;
static int pause_error,transition_error,send_stop_error,send_close_error,api_error;
static bool no_response,close_success;
static u32 observed_plane;
static unsigned pauses,flushes,kills,waits,close_sends,stop_sends,writes;
static void mutex_lock(int *p) { assert(!*p); *p=1; }
static void mutex_unlock(int *p) { assert(*p==1); *p=0; }
#define lockdep_assert_held(p) assert(*(p)==1)
static unsigned msecs_to_jiffies(unsigned x) { return x; }
static void init_completion(completion *p) { assert(!p->initialized); p->initialized=true; p->done=0; }
static void reinit_completion(completion *p) { assert(active->lock==1 && p->initialized); p->done=0; }
static void complete(completion *p) { assert(active->lock==1 && p->initialized); ++p->done; }
static int iris_inst_change_state(iris_inst *i,u32 state) { i->state=state; return 0; }
static int wait_for_completion_timeout(completion *p,unsigned timeout) {
    assert(active->lock==0 && timeout==HW_RESPONSE_TIMEOUT_VALUE); ++waits;
    auto deliver=std::move(response); response={};
    auto before=std::move(before_response); before_response={};
    if (before) { mutex_lock(&active->lock); before(active,p); mutex_unlock(&active->lock); }
    if (deliver) { mutex_lock(&active->lock); deliver(); mutex_unlock(&active->lock); }
    assert(p->initialized);
    if (!p->done) return 0;
    --p->done; return 2;
}
static int iris_inst_sub_state_change_pause(iris_inst *,u32 plane) { ++pauses; observed_plane=plane; return pause_error; }
static int iris_inst_state_change_streamoff(iris_inst *,u32) { return transition_error; }
static void iris_flush_deferred_buffers(iris_inst *i,iris_buffer_type) { assert(i->lock==1); ++flushes; }
static void iris_kill_session(iris_inst *i) { assert(i->lock==1 && i->streamoff_error); ++kills; i->state=IRIS_INST_ERROR; }
static int iris_hfi_gen2_handle_session_buffer(iris_inst *,iris_hfi_packet *) { return 0; }
static int iris_hfi_gen2_handle_src_change(iris_inst *,iris_hfi_packet *) { return 0; }
static int iris_hfi_gen2_handle_session_drain(iris_inst *,iris_hfi_packet *) { return 0; }
static int iris_wait_for_session_response(iris_inst *,struct completion *);
static u32 iris_hfi_gen2_get_port(iris_inst *,u32);
static int iris_hfi_gen2_session_stop(iris_inst *,u32);
static int iris_hfi_gen2_handle_session_command(iris_inst *,iris_hfi_packet *);
static int send_close(iris_inst *i) {
    ++close_sends;
    if (send_close_error) return send_close_error;
    if (!no_response) response=[i] {
        iris_hfi_packet pkt{HFI_CMD_CLOSE,0,close_success ? u32(HFI_FW_FLAGS_SUCCESS) : 0U};
        iris_hfi_gen2_handle_session_command(i,&pkt);
    };
    return 0;
}
static int send_stop(iris_inst *i,u32 plane) {
    ++stop_sends;
    return iris_hfi_gen2_session_stop(i,plane);
}
static void iris_hfi_gen2_packet_session_command(iris_inst *i,u32 type,u32 flags,u32 port,
                                                u32 session_id,u32 payload_type,void *payload,u32 size) {
    assert(i==active && i->lock==1 && type==HFI_CMD_STOP && session_id==i->session_id);
    assert(payload_type==HFI_PAYLOAD_NONE && !payload && !size);
    *to_iris_inst_hfi_gen2(i)->packet={sizeof(iris_hfi_header),type,port,flags};
}
static int iris_hfi_queue_cmd_write(iris_core *core,iris_hfi_header *hdr,unsigned size) {
    assert(core==&provider && size==sizeof(*hdr) && hdr->flags==7); ++writes;
    if (send_stop_error) return send_stop_error;
    if (!no_response) response=[i=active,copy=*hdr] {
        iris_hfi_packet pkt{copy.type,copy.port,0};
        iris_hfi_gen2_handle_session_command(i,&pkt);
    };
    return 0;
}
static const iris_hfi_session_ops iris_hfi_gen2_session_ops{send_close,send_stop};
static int iris_session_streamoff(iris_inst *,u32);
static int v4l2_m2m_streamoff(file *f,m2m_ctx *,u32 plane) {
    if (api_error) return api_error;
    mutex_lock(&f->inst->lock); iris_session_streamoff(f->inst,plane); mutex_unlock(&f->inst->lock);
    return 0; // VB2 discards its void stop_streaming callback's driver result.
}
CPP
{
    awk '/^static u32 iris_hfi_gen2_get_port\(/ {emit=1} emit {print} emit && /^}/ {exit}' "$iris/iris_hfi_gen2_command.c"
    for name in iris_hfi_gen2_session_stop iris_hfi_gen2_get_instance; do
        awk -v name="$name" '$0 ~ "^static (int |struct iris_inst \\*)" name "\\(" {emit=1} emit {print} emit && /^}/ {exit}' "$iris/iris_hfi_gen2_command.c"
    done
    for name in iris_hfi_gen2_handle_session_close iris_hfi_gen2_handle_session_stop iris_hfi_gen2_handle_session_command; do
        awk -v name="$name" '$0 ~ "^static (void|int) " name "\\(" {emit=1} emit {print} emit && /^}/ {exit}' "$iris/iris_hfi_gen2_response.c"
    done
    awk '/^int iris_wait_for_session_response\(/ {emit=1} emit {print} emit && /^}/ {exit}' "$iris/iris_utils.c"
    awk '/^int iris_session_streamoff\(/ {emit=1} emit {print} emit && /^}/ {exit}' "$iris/iris_common.c"
    for name in iris_session_close iris_stop_queue; do
        awk -v name="$name" '$0 ~ "^static int " name "\\(" {emit=1} emit {print} emit && /^}/ {exit}' "$iris/iris_vidc.c"
    done
} | sed -E 's/^int (iris_wait_for_session_response|iris_session_streamoff)/static int \1/' >> "$work/check.cpp"
cat >> "$work/check.cpp" <<'CPP'
static void reset(iris_inst &i,u32 domain=DECODER) {
    auto *ext=to_iris_inst_hfi_gen2(&i); *ext={};
    init_completion(&ext->input_stop); init_completion(&ext->output_stop);
    init_completion(&i.completion); init_completion(&i.flush_completion);
    active=&i; i.domain=domain; i.state=IRIS_INST_INIT; i.hfi_session_ops=&iris_hfi_gen2_session_ops; i.lock=1;
    i.core=&provider; i.session_id=9; packet={}; ext->packet=&packet;
    pause_error=transition_error=send_stop_error=send_close_error=api_error=0;
    no_response=false; close_success=true; response={}; before_response={};
    pauses=flushes=kills=waits=close_sends=stop_sends=writes=0; observed_plane=0;
}
int main() {
    allocation_failure=true; assert(!iris_hfi_gen2_get_instance());
    allocation_failure=false;
    auto *allocated=iris_hfi_gen2_get_instance(); assert(allocated);
    auto *allocation=to_iris_inst_hfi_gen2(allocated);
    assert(allocation->input_stop.initialized && allocation->output_stop.initialized);
    assert(!allocation->input_stop.done && !allocation->output_stop.done);
    assert(allocated->hfi_session_ops==&iris_hfi_gen2_session_ops); delete allocation;
    iris_inst_hfi_gen2 ext{}; iris_inst &i=ext.inst;
    for (u32 domain:{DECODER,ENCODER}) for (u32 plane:{V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE,V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE}) {
        reset(i,domain);
        assert(iris_session_streamoff(&i,plane)==0 && observed_plane==plane);
        assert(pauses==1 && flushes==1 && !kills && !i.streamoff_error && i.lock==1);
    }
    for (u32 domain:std::initializer_list<u32>{0U,3U,DECODER,ENCODER}) for (u32 port:std::initializer_list<u32>{HFI_PORT_NONE,3U,HFI_PORT_RAW,HFI_PORT_BITSTREAM}) {
        reset(i,domain); iris_hfi_packet p{HFI_CMD_STOP,port,0};
        bool valid=(domain==DECODER || domain==ENCODER) && (port==HFI_PORT_RAW || port==HFI_PORT_BITSTREAM);
        assert(iris_hfi_gen2_handle_session_command(&i,&p)==(valid ? 0 : -EINVAL));
        assert(!i.completion.done && pauses==unsigned(valid) && i.state==(valid ? IRIS_INST_INIT : IRIS_INST_ERROR));
        assert(ext.input_stop.done+ext.output_stop.done==unsigned(valid));
    }
    for (bool flush:{false,true}) {
        reset(i); auto *done=flush ? &i.flush_completion : &i.completion;
        done->done=1; assert(iris_wait_for_session_response(&i,done)==0 && i.lock==1);
        done->done=1; i.state=IRIS_INST_ERROR; assert(iris_wait_for_session_response(&i,done)==-EIO && i.lock==1);
        reset(i); assert(iris_wait_for_session_response(&i,done)==-ETIMEDOUT && i.state==IRIS_INST_ERROR && i.lock==1);
    }
    for (unsigned fault=0;fault<6;++fault) {
        reset(i);
        int expected=0;
        if (fault==1) { send_close_error=-ENOSPC; expected=-ENOSPC; }
        if (fault==2) { close_success=false; expected=-EIO; }
        if (fault==3) { no_response=true; expected=-ETIMEDOUT; }
        if (fault==4) { i.state=IRIS_INST_ERROR; expected=-EIO; }
        if (fault==5) { i.state=IRIS_INST_DEINIT; }
        assert(iris_session_close(&i)==expected && i.lock==1);
        assert(close_sends==unsigned(fault!=5));
        assert(waits==unsigned(fault!=1 && fault!=5));
    }
    for (unsigned fault=1;fault<5;++fault) {
        reset(i);
        int expected=-EIO;
        if (fault==1) { send_stop_error=-ENOSPC; expected=-ENOSPC; }
        if (fault==2) pause_error=-EINVAL;
        if (fault==3) { no_response=true; expected=-ETIMEDOUT; }
        if (fault==4) { transition_error=-EREMOTEIO; expected=-EREMOTEIO; }
        assert(iris_session_streamoff(&i,V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE)==expected);
        assert(i.streamoff_error==expected && kills==1 && flushes==1 && i.lock==1);
        send_stop_error=-EPIPE;
        assert(iris_session_streamoff(&i,V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE)==-EPIPE && i.streamoff_error==expected);
    }
    reset(i); assert(iris_session_streamoff(&i,0)==-EINVAL && !i.streamoff_error && !kills && !flushes);
    reset(i); send_stop_error=-ENOSPC; file f{&i}; mutex_unlock(&i.lock);
    assert(iris_stop_queue(&f,&i,V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE)==-ENOSPC && i.lock==0);
    api_error=-EBUSY;
    assert(iris_stop_queue(&f,&i,V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE)==-EBUSY && i.lock==0);
    for (u32 domain:{DECODER,ENCODER}) {
        for (u32 plane:{V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE,V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE}) {
            u32 other=plane==V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE ?
                      V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE : V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE;
            for (bool missing:{false,true}) {
                reset(i,domain); no_response=missing;
                before_response=[plane,other](iris_inst *inst,completion *done) {
                    auto *g=to_iris_inst_hfi_gen2(inst);
                    auto *expected=plane==V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE ? &g->input_stop : &g->output_stop;
                    assert(done==expected && !done->done);
                    iris_hfi_packet close{HFI_CMD_CLOSE,HFI_PORT_NONE,HFI_FW_FLAGS_SUCCESS};
                    assert(!iris_hfi_gen2_handle_session_command(inst,&close));
                    assert(!done->done && inst->completion.done==1);
                    iris_hfi_packet stop{HFI_CMD_STOP,iris_hfi_gen2_get_port(inst,other),0};
                    assert(!iris_hfi_gen2_handle_session_command(inst,&stop) && !done->done);
                };
                assert(iris_hfi_gen2_session_stop(&i,plane)==(missing ? -ETIMEDOUT : 0));
                assert(i.completion.done==1 && waits==1 && i.lock==1);
            }
            reset(i,domain);
            auto *other_done=other==V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE ? &ext.input_stop : &ext.output_stop;
            i.completion.done=other_done->done=1;
            assert(!iris_hfi_gen2_session_stop(&i,plane));
            assert(i.completion.done==1 && other_done->done==1);
        }
        for (bool missing:{false,true}) {
            reset(i,domain); no_response=missing;
            before_response=[](iris_inst *inst,completion *done) {
                assert(done==&inst->completion && !done->done);
                for (u32 plane:{V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE,V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE}) {
                    iris_hfi_packet stop{HFI_CMD_STOP,iris_hfi_gen2_get_port(inst,plane),0};
                    assert(!iris_hfi_gen2_handle_session_command(inst,&stop) && !done->done);
                }
            };
            assert(iris_session_close(&i)==(missing ? -ETIMEDOUT : 0));
            assert(ext.input_stop.done==1 && ext.output_stop.done==1 && waits==1 && i.lock==1);
        }
    }
    reset(i);
    assert(iris_hfi_gen2_session_stop(&i,0)==-EINVAL && !writes && !waits);
    ext.packet=nullptr;
    assert(iris_hfi_gen2_session_stop(&i,V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE)==-EINVAL && !writes && !waits);
}
CPP
"${CXX:-g++}" -std=c++20 -O2 -Wall -Wextra -Werror "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Actual Iris results: command/port receipt isolation, allocation, errors, timeout and VB2 latch passed\n'

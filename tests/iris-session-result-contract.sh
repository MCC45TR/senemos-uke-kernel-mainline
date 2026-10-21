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
#include <utility>
using u32=unsigned;
enum { DECODER=1, ENCODER=2, IRIS_INST_DEINIT=0, IRIS_INST_INIT=1, IRIS_INST_ERROR=2,
       HFI_PORT_NONE=0, HFI_PORT_RAW=1, HFI_PORT_BITSTREAM=2, HFI_FW_FLAGS_SUCCESS=1,
       HFI_CMD_CLOSE=1, HFI_CMD_STOP=2, HFI_CMD_BUFFER=3, HFI_CMD_SETTINGS_CHANGE=4, HFI_CMD_DRAIN=5,
       V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE=9, V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE=10,
       HW_RESPONSE_TIMEOUT_VALUE=100 };
enum iris_buffer_type { BUF_INPUT, BUF_OUTPUT };
struct completion { bool done; };
struct iris_inst;
struct iris_hfi_session_ops { int (*session_close)(iris_inst *); int (*session_stop)(iris_inst *,u32); };
struct m2m_ctx {};
struct iris_inst {
    const iris_hfi_session_ops *hfi_session_ops;
    u32 domain,state;
    int lock,streamoff_error;
    struct completion completion,flush_completion;
    struct m2m_ctx *m2m_ctx;
};
struct file { iris_inst *inst; };
struct iris_hfi_packet { u32 type,port,flags; };
static iris_inst *active;
static std::function<void()> response;
static int pause_error,transition_error,send_stop_error,send_close_error,api_error;
static bool no_response,close_success;
static u32 observed_plane;
static unsigned pauses,flushes,kills,waits,close_sends,stop_sends;
static void mutex_lock(int *p) { assert(!*p); *p=1; }
static void mutex_unlock(int *p) { assert(*p==1); *p=0; }
#define lockdep_assert_held(p) assert(*(p)==1)
static unsigned msecs_to_jiffies(unsigned x) { return x; }
static void reinit_completion(completion *p) { assert(active->lock==1); p->done=false; }
static void complete(completion *p) { assert(active->lock==1); p->done=true; }
static int iris_inst_change_state(iris_inst *i,u32 state) { i->state=state; return 0; }
static int wait_for_completion_timeout(completion *p,unsigned timeout) {
    assert(active->lock==0 && timeout==HW_RESPONSE_TIMEOUT_VALUE); ++waits;
    auto deliver=std::move(response); response={};
    if (deliver) { mutex_lock(&active->lock); deliver(); mutex_unlock(&active->lock); }
    return p->done ? 2 : 0;
}
static int iris_inst_sub_state_change_pause(iris_inst *,u32 plane) { ++pauses; observed_plane=plane; return pause_error; }
static int iris_inst_state_change_streamoff(iris_inst *,u32) { return transition_error; }
static void iris_flush_deferred_buffers(iris_inst *i,iris_buffer_type) { assert(i->lock==1); ++flushes; }
static void iris_kill_session(iris_inst *i) { assert(i->lock==1 && i->streamoff_error); ++kills; i->state=IRIS_INST_ERROR; }
static int iris_hfi_gen2_handle_session_buffer(iris_inst *,iris_hfi_packet *) { return 0; }
static int iris_hfi_gen2_handle_src_change(iris_inst *,iris_hfi_packet *) { return 0; }
static int iris_hfi_gen2_handle_session_drain(iris_inst *,iris_hfi_packet *) { return 0; }
static int iris_wait_for_session_response(iris_inst *,bool);
static u32 iris_hfi_gen2_get_port(iris_inst *,u32);
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
    if (send_stop_error) return send_stop_error;
    reinit_completion(&i->completion);
    if (!no_response) response=[i,plane] {
        iris_hfi_packet pkt{HFI_CMD_STOP,iris_hfi_gen2_get_port(i,plane),0};
        iris_hfi_gen2_handle_session_command(i,&pkt);
    };
    return iris_wait_for_session_response(i,false);
}
static const iris_hfi_session_ops hfi{send_close,send_stop};
static int iris_session_streamoff(iris_inst *,u32);
static int v4l2_m2m_streamoff(file *f,m2m_ctx *,u32 plane) {
    if (api_error) return api_error;
    mutex_lock(&f->inst->lock); iris_session_streamoff(f->inst,plane); mutex_unlock(&f->inst->lock);
    return 0; // VB2 discards its void stop_streaming callback's driver result.
}
CPP
{
    awk '/^static u32 iris_hfi_gen2_get_port\(/ {emit=1} emit {print} emit && /^}/ {exit}' "$iris/iris_hfi_gen2_command.c"
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
    i={}; active=&i; i.domain=domain; i.state=IRIS_INST_INIT; i.hfi_session_ops=&hfi; i.lock=1;
    pause_error=transition_error=send_stop_error=send_close_error=api_error=0;
    no_response=false; close_success=true; response={};
    pauses=flushes=kills=waits=close_sends=stop_sends=0; observed_plane=0;
}
int main() {
    iris_inst i;
    for (u32 domain:{DECODER,ENCODER}) for (u32 plane:{V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE,V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE}) {
        reset(i,domain);
        assert(iris_session_streamoff(&i,plane)==0 && observed_plane==plane);
        assert(pauses==1 && flushes==1 && !kills && !i.streamoff_error && i.lock==1);
    }
    for (u32 domain:std::initializer_list<u32>{0U,3U,DECODER,ENCODER}) for (u32 port:std::initializer_list<u32>{HFI_PORT_NONE,3U,HFI_PORT_RAW,HFI_PORT_BITSTREAM}) {
        reset(i,domain); iris_hfi_packet p{HFI_CMD_STOP,port,0};
        bool valid=(domain==DECODER || domain==ENCODER) && (port==HFI_PORT_RAW || port==HFI_PORT_BITSTREAM);
        assert(iris_hfi_gen2_handle_session_command(&i,&p)==(valid ? 0 : -EINVAL));
        assert(i.completion.done && pauses==unsigned(valid) && i.state==(valid ? IRIS_INST_INIT : IRIS_INST_ERROR));
    }
    for (bool flush:{false,true}) {
        reset(i); auto *done=flush ? &i.flush_completion : &i.completion;
        done->done=true; assert(iris_wait_for_session_response(&i,flush)==0 && i.lock==1);
        i.state=IRIS_INST_ERROR; assert(iris_wait_for_session_response(&i,flush)==-EIO && i.lock==1);
        reset(i); assert(iris_wait_for_session_response(&i,flush)==-ETIMEDOUT && i.state==IRIS_INST_ERROR && i.lock==1);
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
}
CPP
"${CXX:-g++}" -std=c++20 -O2 -Wall -Wextra -Werror "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Actual Iris results: inverse stop ports, failed ACKs, close errors, timeout and VB2 error latch passed\n'

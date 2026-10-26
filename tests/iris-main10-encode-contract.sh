#!/usr/bin/env bash
# Exercise actual P010 admission, allocations and HFI writers without device I/O.
set -Eeuo pipefail
iris=${1:?Pass the prepared Iris directory}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cat > "$work/check.cpp" <<'CPP'
#include <algorithm>
#include <cassert>
#include <cerrno>
#include <cstdint>
#include <cstring>
#include <linux/videodev2.h>
using u32=uint32_t; using u64=uint64_t; using s64=int64_t;
#define ALIGN(n,a) (((n)+(a)-1)&~((a)-1))
#define ARRAY_SIZE(a) (sizeof(a)/sizeof((a)[0]))
#define BIT(n) (1ULL<<(n))
#define PIXELS_4K 4096
#define Y_STRIDE_ALIGN 128
#define UV_STRIDE_ALIGN 128
#define Y_STRIDE_ALIGN_P010 256
#define UV_STRIDE_ALIGN_P010 256
#define Y_SCANLINE_ALIGN 32
#define UV_SCANLINE_ALIGN 16
#define HFI_CODEC_ENCODE_AVC 1
#define HFI_CODEC_ENCODE_HEVC 2
#define NUM_MBS_PER_FRAME(h,w) ((((h)+15)/16)*(((w)+15)/16))
enum {DECODER,ENCODER};
struct iris_inst; struct v4l2_ctrl;
CPP
extract() {
    FUNCTION_PATTERN="$1" awk '$0 ~ ENVIRON["FUNCTION_PATTERN"] {emit=1} emit {print} emit && /^}/ {exit}' "$2" >> "$work/check.cpp"
}
for tag in 'struct platform_inst_caps' 'enum platform_inst_fw_cap_type' 'enum platform_inst_fw_cap_flags' 'struct platform_inst_fw_cap'; do
    awk -v tag="$tag" '$0==tag " {" {emit=1} emit {print} emit && /^};/ {exit}' "$iris/iris_platform_common.h" >> "$work/check.cpp"
done
for tag in 'enum iris_fmt_type_out' 'enum iris_fmt_type_cap'; do
    awk -v tag="$tag" '$0==tag " {" {emit=1} emit {print} emit && /^};/ {exit}' "$iris/iris_instance.h" >> "$work/check.cpp"
done
awk '/^enum iris_buffer_type {/ {emit=1} emit {print} emit && /^};/ {exit}' "$iris/iris_buffer.h" >> "$work/check.cpp"
for tag in 'enum hfi_packet_port_type' 'enum hfi_packet_payload_info' 'enum hfi_packet_host_flags'; do
    awk -v tag="$tag" '$0==tag " {" {emit=1} emit {print} emit && /^};/ {exit}' "$iris/iris_hfi_common.h" >> "$work/check.cpp"
done
awk '/^enum hfi_color_format {/ {emit=1} emit {print} emit && /^};/ {exit}' "$iris/iris_hfi_gen2_defines.h" >> "$work/check.cpp"
awk '$1=="#define" && $2 ~ /^HFI_PROP_/ {print}' "$iris/iris_hfi_gen2_defines.h" >> "$work/check.cpp"
cat >> "$work/check.cpp" <<'CPP'
struct iris_platform_data {u32 num_vpp_pipe;};
static const iris_platform_data sm7675_data{2}, legacy_data{4};
struct iris_core {const struct iris_platform_data *iris_platform_data;};
struct vb2_queue {bool busy{};};
struct context {vb2_queue src{},dst{};};
struct buffers {u32 min_count{},size{};};
struct iris_inst {
    iris_core *core; u32 codec; int domain; v4l2_format *fmt_src,*fmt_dst;
    platform_inst_fw_cap fw_caps[INST_FW_CAP_MAX]{};
    struct buffers buffers[64]{};
    u32 enc_raw_width{},enc_raw_height{},enc_scale_width{},enc_scale_height{};
    v4l2_rect crop{}; context *m2m_ctx;
};
static vb2_queue *v4l2_m2m_get_vq(context *ctx,u32 type) {
    return type==V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE ? &ctx->src : &ctx->dst;
}
static bool vb2_is_busy(vb2_queue *q) {return q->busy;}
static int iris_vpu_buf_count(iris_inst *,iris_buffer_type) {return 4;}
static const platform_inst_caps *iris_get_inst_caps(iris_inst *,u32) {
    static const platform_inst_caps caps=[] {
        platform_inst_caps c{};c.min_frame_width=96;c.min_frame_height=96;
        c.max_frame_width=4096;c.max_frame_height=4096;c.max_mbpf=34560;return c;
    }();return &caps;
}
static u32 iris_dec_bitstream_buffer_size(iris_inst *) {assert(false);return 0;}
static u32 iris_yuv_buffer_size_qc08c(iris_inst *) {assert(false);return 0;}
static u32 iris_yuv_buffer_size_qc10c(iris_inst *) {assert(false);return 0;}
CPP
extract '^bool iris_fmt_is_10bit\(' "$iris/iris_utils.c"
for fn in iris_yuv_buffer_size_nv12 iris_enc_bitstream_buffer_size; do
    extract "^static u32 $fn\\(" "$iris/iris_buffer.c"
done
extract '^u32 iris_yuv_buffer_size_p010\(' "$iris/iris_buffer.c"
extract '^int iris_get_buffer_size\(' "$iris/iris_buffer.c"
for name in iris_venc_formats_cap iris_venc_formats_out; do
    awk -v name="$name" '$0=="static const u32 " name "[] = {" {emit=1} emit {print} emit && /^};/ {exit}' "$iris/iris_venc.c" >> "$work/check.cpp"
done
extract '^static bool iris_venc_p010_supported\(' "$iris/iris_venc.c"
extract '^static bool check_format\(' "$iris/iris_venc.c"
extract '^static u32 find_format_by_index\(' "$iris/iris_venc.c"
extract '^int iris_venc_try_fmt\(' "$iris/iris_venc.c"
extract '^static int iris_venc_s_fmt_output\(' "$iris/iris_venc.c"
extract '^static int iris_venc_s_fmt_input\(' "$iris/iris_venc.c"
extract '^int iris_venc_s_fmt\(' "$iris/iris_venc.c"
extract '^static int iris_venc_validate_bit_depth\(' "$iris/iris_venc.c"
cat >> "$work/check.cpp" <<'CPP'
static u32 property_calls, sent_color, sent_stride[2], sent_resolution;
static int property_error;
static u32 iris_hfi_gen2_get_port(iris_inst *,u32 plane) {
    assert(plane==V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE); return HFI_PORT_RAW;
}
static int iris_hfi_gen2_session_set_property(iris_inst *,u32 prop,u32 flags,u32 port,u32 type,void *data,u32 bytes) {
    assert(flags==HFI_HOST_FLAGS_NONE && port==HFI_PORT_RAW); ++property_calls;
    if(prop==HFI_PROP_COLOR_FORMAT) {
        assert(type==HFI_PAYLOAD_U32_ENUM && bytes==4);sent_color=*static_cast<u32 *>(data);
    } else if(prop==HFI_PROP_RAW_RESOLUTION) {
        assert(type==HFI_PAYLOAD_32_PACKED && bytes==4);sent_resolution=*static_cast<u32 *>(data);
    } else {
        assert(prop==HFI_PROP_LINEAR_STRIDE_SCANLINE && type==HFI_PAYLOAD_64_PACKED && bytes==8);
        memcpy(sent_stride,data,8);
    }
    return property_error;
}
CPP
extract '^static int iris_hfi_gen2_set_colorformat\(' "$iris/iris_hfi_gen2_command.c"
extract '^static int iris_hfi_gen2_set_linear_stride_scanline\(' "$iris/iris_hfi_gen2_command.c"
extract '^static int iris_hfi_gen2_set_raw_resolution\(' "$iris/iris_hfi_gen2_command.c"
awk '/^static const u32 sm8550_venc_input_config_params\[\] = {/ {emit=1} emit {print} emit && /^};/ {exit}' "$iris/iris_hfi_gen2.c" >> "$work/check.cpp"
cat >> "$work/check.cpp" <<'CPP'
static bool selected_ten;
static unsigned size_calls;
static u32 select_size(bool ten) {selected_ten=ten;++size_calls;return 1234;}
static u32 iris_vpu_enc_get_bitstream_width(iris_inst *i) {return i->fmt_dst->fmt.pix_mp.width;}
static u32 iris_vpu_enc_get_bitstream_height(iris_inst *i) {return i->fmt_dst->fmt.pix_mp.height;}
static u32 hfi_buffer_get_recon_count(iris_inst *) {return 2;}
static bool is_scaling_enabled(iris_inst *) {return true;}
static u32 hfi_buffer_line_enc(u32,u32,bool t,u32,u32,u32) {return select_size(t);}
static u32 hfi_buffer_line_enc_vpu33(u32,u32,bool t,u32,u32,u32) {return select_size(t);}
static u32 hfi_buffer_scratch1_enc(u32,u32,u32,u32,bool t,u32,bool) {return select_size(t);}
static u32 hfi_buffer_scratch2_enc(u32,u32,u32,bool t) {return select_size(t);}
static u32 hfi_buffer_vpss_enc(u32,u32,bool,u32,bool t) {return select_size(t);}
static u32 hfi_vpu4x_buffer_line_enc(u32,u32,bool t,u32,u32,u32) {return select_size(t);}
CPP
for fn in iris_vpu_enc_line_size iris_vpu33_enc_line_size iris_vpu_enc_scratch1_size iris_vpu_enc_scratch2_size iris_vpu_enc_vpss_size iris_vpu4x_enc_line_size; do
    extract "^static u32 $fn\\(" "$iris/iris_vpu_buffer.c"
done
cat >> "$work/check.cpp" <<'CPP'
int main() {
    iris_core core{&sm7675_data};v4l2_format src{},dst{};context ctx{};
    iris_inst inst{&core,V4L2_PIX_FMT_HEVC,ENCODER,&src,&dst,{}, {},0,0,0,0,{},&ctx};
    constexpr u32 output=V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE;
    constexpr u32 capture=V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE;
    assert(find_format_by_index(&inst,2,output)==V4L2_PIX_FMT_P010);
    assert(check_format(&inst,V4L2_PIX_FMT_P010,output));
    inst.codec=V4L2_PIX_FMT_H264;
    assert(!check_format(&inst,V4L2_PIX_FMT_P010,output) && !find_format_by_index(&inst,2,output));
    inst.codec=V4L2_PIX_FMT_HEVC;core.iris_platform_data=&legacy_data;
    assert(!check_format(&inst,V4L2_PIX_FMT_P010,output));core.iris_platform_data=&sm7675_data;
    src.fmt.pix_mp.pixelformat=V4L2_PIX_FMT_NV12;src.fmt.pix_mp.width=320;src.fmt.pix_mp.height=240;
    dst.fmt.pix_mp.pixelformat=V4L2_PIX_FMT_HEVC;dst.fmt.pix_mp.width=320;dst.fmt.pix_mp.height=240;
    inst.crop.width=320;inst.crop.height=240;
    inst.fw_caps[PROFILE_HEVC].value=V4L2_MPEG_VIDEO_HEVC_PROFILE_MAIN_10;
    assert(iris_venc_validate_bit_depth(&inst)==-EINVAL);
    v4l2_format request=src;request.type=output;request.fmt.pix_mp.pixelformat=V4L2_PIX_FMT_P010;
    auto trial=request;
    assert(iris_venc_try_fmt(&inst,&trial)==0);
    assert(trial.fmt.pix_mp.width==384 && trial.fmt.pix_mp.height==256);
    assert(trial.fmt.pix_mp.plane_fmt[0].bytesperline==768 && trial.fmt.pix_mp.plane_fmt[0].sizeimage==294912);
    trial=request;trial.fmt.pix_mp.field=V4L2_FIELD_INTERLACED;
    assert(iris_venc_try_fmt(&inst,&trial)==0 && trial.fmt.pix_mp.field==V4L2_FIELD_NONE);
    for(u32 invalid_width : {0u,1u,97u,4098u,UINT32_MAX}) {
        auto bad=request;bad.fmt.pix_mp.width=invalid_width;
        assert(iris_venc_try_fmt(&inst,&bad)==-EINVAL);
        assert(iris_venc_s_fmt(&inst,&bad)==-EINVAL);
        assert(src.fmt.pix_mp.pixelformat==V4L2_PIX_FMT_NV12);
    }
    auto excessive=request;excessive.fmt.pix_mp.width=4096;excessive.fmt.pix_mp.height=4096;
    assert(iris_venc_try_fmt(&inst,&excessive)==-EINVAL);
    ctx.dst.busy=true;assert(iris_venc_s_fmt(&inst,&request)==-EBUSY);ctx.dst.busy=false;
    assert(iris_venc_s_fmt(&inst,&request)==0);
    assert(src.fmt.pix_mp.width==384 && src.fmt.pix_mp.height==256);
    assert(inst.enc_raw_width==320 && inst.enc_raw_height==240);
    assert(src.fmt.pix_mp.plane_fmt[0].bytesperline==768 && src.fmt.pix_mp.plane_fmt[0].sizeimage==294912);
    assert(inst.buffers[BUF_INPUT].size==294912 && inst.buffers[BUF_OUTPUT].size==368640);
    assert(dst.fmt.pix_mp.plane_fmt[0].sizeimage==368640);
    auto fallback=request;fallback.fmt.pix_mp.pixelformat=0;fallback.fmt.pix_mp.width=UINT32_MAX;
    assert(iris_venc_s_fmt(&inst,&fallback)==0 && fallback.fmt.pix_mp.pixelformat==V4L2_PIX_FMT_P010);
    assert(inst.enc_raw_width==320 && inst.enc_raw_height==240);
    assert(iris_venc_validate_bit_depth(&inst)==0);
    inst.fw_caps[PROFILE_HEVC].value=V4L2_MPEG_VIDEO_HEVC_PROFILE_MAIN;
    assert(iris_venc_validate_bit_depth(&inst)==-EINVAL);
    inst.fw_caps[PROFILE_HEVC].value=V4L2_MPEG_VIDEO_HEVC_PROFILE_MAIN_10;
    inst.codec=V4L2_PIX_FMT_H264;assert(iris_venc_validate_bit_depth(&inst)==-EINVAL);inst.codec=V4L2_PIX_FMT_HEVC;
    assert(iris_hfi_gen2_set_colorformat(&inst,output)==0 && sent_color==HFI_COLOR_FMT_P010);
    assert(iris_hfi_gen2_set_linear_stride_scanline(&inst,output)==0);
    assert(iris_hfi_gen2_set_raw_resolution(&inst,output)==0 && sent_resolution==((320u<<16)|240));
    // HFI uses pixels for stride; the V4L2 byte pitch is twice this for P010.
    assert(sent_stride[0]==((384u<<16)|256) && sent_stride[1]==((384u<<16)|128));
    property_error=-EIO;assert(iris_hfi_gen2_set_colorformat(&inst,output)==-EIO);property_error=0;
    auto calls=property_calls;src.fmt.pix_mp.pixelformat=0;
    assert(iris_hfi_gen2_set_colorformat(&inst,output)==-EINVAL && property_calls==calls);
    for(auto format : {V4L2_PIX_FMT_NV12,V4L2_PIX_FMT_P010}) {
        src.fmt.pix_mp.pixelformat=format;
        const bool ten=format==V4L2_PIX_FMT_P010;
        for(auto calc : {iris_vpu_enc_line_size,iris_vpu33_enc_line_size,iris_vpu_enc_scratch1_size,iris_vpu_enc_scratch2_size,iris_vpu_enc_vpss_size,iris_vpu4x_enc_line_size}) {
            size_calls=0;assert(calc(&inst)==1234 && size_calls==1 && selected_ten==ten);
        }
    }
    for(u32 prop:sm8550_venc_input_config_params)assert(prop!=HFI_PROP_LUMA_CHROMA_BIT_DEPTH);
    src.fmt.pix_mp.pixelformat=V4L2_PIX_FMT_NV12;
    inst.fw_caps[PROFILE_HEVC].value=V4L2_MPEG_VIDEO_HEVC_PROFILE_MAIN;
    assert(iris_get_buffer_size(&inst,BUF_INPUT)==147456 && iris_venc_validate_bit_depth(&inst)==0);
    core.iris_platform_data=&legacy_data;
    inst.fw_caps[PROFILE_HEVC].value=V4L2_MPEG_VIDEO_HEVC_PROFILE_MAIN_10;
    assert(iris_venc_validate_bit_depth(&inst)==0);
    core.iris_platform_data=&sm7675_data;src.fmt.pix_mp.pixelformat=V4L2_PIX_FMT_P010;
    src.fmt.pix_mp.width=4096;src.fmt.pix_mp.height=2176;
    assert(iris_get_buffer_size(&inst,BUF_INPUT)==26738688);
    inst.domain=DECODER;dst=src;
    assert(iris_get_buffer_size(&inst,BUF_OUTPUT)==26738688);
    assert(iris_hfi_gen2_set_colorformat(&inst,output)==0 && sent_color==HFI_COLOR_FMT_P010);
    (void)capture;
}
CPP
${CXX:-c++} -std=c++17 -O2 -Wall -Wextra -Werror -Wno-unused-function "$work/check.cpp" -o "$work/check"
"$work/check"
printf '%s\n' 'Actual Main10 encoder: scoped formats, profile pairing, busy queues, 16-bit allocations, capture resizing, pixel-unit HFI stride/color/error paths and internal 10-bit size selection passed; host only'

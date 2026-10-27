#!/usr/bin/env bash
# Production PCON admission and AUX transaction, with advertised caps and injected faults.
set -Eeuo pipefail
ulimit -c 0
kernel=${1:?Pass prepared Linux source}
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$root/build"
work=$(mktemp -d "$root/build/pcon-fixture.XXXXXX")
trap 'rm -r -- "$work"' EXIT
extract() {
    awk -v name="$2" '$0 ~ "^((static )?(inline )?(bool|int) )?" name "\\(" {
        if($0 ~ "^" name)print previous;emit=1;found=1}
        emit{print} emit&&/^}/{exit} {previous=$0} END{if(!found)exit 1}' "$1"
}
{
cat <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
typedef uint8_t u8;typedef uint32_t u32;typedef uint64_t u64;
#define BIT(n) (1U<<(n))
#define __packed __attribute__((packed))
#define max(a,b) ((a)>(b)?(a):(b))
#define min(a,b) ((a)<(b)?(a):(b))
#define DRM_EDID_YCBCR420_DC_30 1
#define DRM_CONNECTOR_COLOR_FORMAT_YCBCR422 2
struct drm_display_info {bool is_hdmi;unsigned max_tmds_clock,color_formats;struct {unsigned y420_dc_modes;} hdmi;};
struct drm_display_mode {unsigned clock;bool is420;};
enum drm_colorspace {DRM_MODE_COLORIMETRY_DEFAULT,DRM_MODE_COLORIMETRY_BT2020_RGB,FOREIGN_COLOR};
struct drm_dp_aux {u8 registers[2];unsigned reads,writes;int fail_read,fail_write;bool mismatch;};
static bool drm_mode_is_420(const struct drm_display_info *info,const struct drm_display_mode *mode) {(void)info;return mode->is420;}
C
sed '/^#include /d' "$kernel/include/drm/display/drm_dp.h"
awk '/^struct msm_dp_pcon_config/ {emit=1} emit{print} emit&&/^};/{exit}' "$kernel/drivers/gpu/drm/msm/dp/dp_utils.h"
extract "$kernel/include/drm/display/drm_dp_helper.h" drm_dp_is_branch
for name in drm_dp_downstream_420_passthrough drm_dp_downstream_444_to_420_conversion drm_dp_downstream_rgb_to_ycbcr_conversion; do
    extract "$kernel/drivers/gpu/drm/display/drm_dp_helper.c" "$name"
done
cat <<'C'
static int drm_dp_dpcd_read_data(struct drm_dp_aux *aux,u32 reg,void *data,unsigned size) {
 assert(reg==DP_PROTOCOL_CONVERTER_CONTROL_1&&size==2);
 if(++aux->reads==(unsigned)aux->fail_read)return -EIO;
 memcpy(data,aux->registers,2);if(aux->mismatch&&aux->reads==2)((u8*)data)[0]^=1;return 0;
}
static int drm_dp_dpcd_write_byte(struct drm_dp_aux *aux,u32 reg,u8 value) {
 assert(reg>=DP_PROTOCOL_CONVERTER_CONTROL_1&&reg<=DP_PROTOCOL_CONVERTER_CONTROL_2);
 if(++aux->writes==(unsigned)aux->fail_write)return -EREMOTEIO;
 aux->registers[reg-DP_PROTOCOL_CONVERTER_CONTROL_1]=value;return 0;
}
C
for name in msm_dp_utils_tmds_fits msm_dp_utils_select_pcon msm_dp_utils_configure_pcon; do
    extract "$kernel/drivers/gpu/drm/msm/dp/dp_utils.c" "$name"
done
cat <<'C'
int main(void) {
 u8 dpcd[15]={0},ports[16]={0};
 struct drm_display_info info={.is_hdmi=true,.max_tmds_clock=320000,.color_formats=BIT(DRM_CONNECTOR_COLOR_FORMAT_YCBCR422)};
 struct drm_display_mode mode={.clock=299890};struct msm_dp_pcon_config out;
 dpcd[DP_DPCD_REV]=0x14;
 dpcd[DP_DOWNSTREAMPORT_PRESENT]=DP_DWN_STRM_PORT_PRESENT|DP_DETAILED_CAP_INFO_AVAILABLE;
 ports[0]=DP_DS_PORT_TYPE_HDMI;
 ports[3]=DP_DS_HDMI_BT709_RGB_YCBCR_CONV|DP_DS_HDMI_BT2020_RGB_YCBCR_CONV|
  DP_DS_HDMI_YCBCR444_TO_422_CONV|DP_DS_HDMI_YCBCR444_TO_420_CONV|DP_DS_HDMI_YCBCR420_PASS_THROUGH;
 /* The same monitor budget that admits 8-bit RGB refuses 10-bit RGB at 75 Hz. */
 assert(msm_dp_utils_tmds_fits(mode.clock,24,info.max_tmds_clock,false));
 assert(!msm_dp_utils_tmds_fits(mode.clock,30,info.max_tmds_clock,false));
 assert(!msm_dp_utils_select_pcon(&info,dpcd,ports,&mode,30,false,DRM_MODE_COLORIMETRY_DEFAULT,&out));
 assert(out.configure&&out.format==DP_PIXELFORMAT_YUV422&&!out.control1&&
  out.control2==(DP_CONVERSION_BT709_RGB_YCBCR_ENABLE|DP_CONVERSION_TO_YCBCR422_ENABLE));
 assert(!msm_dp_utils_select_pcon(&info,dpcd,ports,&mode,30,false,DRM_MODE_COLORIMETRY_BT2020_RGB,&out));
 assert(out.control2==(DP_CONVERSION_BT2020_RGB_YCBCR_ENABLE|DP_CONVERSION_TO_YCBCR422_ENABLE));
 for(unsigned missing=0;missing<5;missing++) {
  u8 caps[15],port[16];memcpy(caps,dpcd,15);memcpy(port,ports,16);struct drm_display_info sink=info;
  if(missing==0)caps[DP_DOWNSTREAMPORT_PRESENT]&=~DP_DETAILED_CAP_INFO_AVAILABLE;
  if(missing==1)caps[DP_DPCD_REV]=0x12;
  if(missing==2)port[3]&=~DP_DS_HDMI_BT709_RGB_YCBCR_CONV;
  if(missing==3)port[3]&=~DP_DS_HDMI_YCBCR444_TO_422_CONV;
  if(missing==4)sink.color_formats=0;
  assert(msm_dp_utils_select_pcon(&sink,caps,port,&mode,30,false,DRM_MODE_COLORIMETRY_DEFAULT,&out)<0);
 }
 assert(msm_dp_utils_select_pcon(&info,dpcd,ports,&mode,30,false,FOREIGN_COLOR,&out)<0);
 ports[1]=80;
 assert(msm_dp_utils_select_pcon(&info,dpcd,ports,&mode,30,false,DRM_MODE_COLORIMETRY_DEFAULT,&out)==-ENOSPC);
 ports[1]=128;
 info.color_formats=0;mode.is420=true;
 assert(msm_dp_utils_select_pcon(&info,dpcd,ports,&mode,30,false,DRM_MODE_COLORIMETRY_DEFAULT,&out)<0);
 info.hdmi.y420_dc_modes=DRM_EDID_YCBCR420_DC_30;
 assert(!msm_dp_utils_select_pcon(&info,dpcd,ports,&mode,30,false,DRM_MODE_COLORIMETRY_DEFAULT,&out));
 assert(out.format==DP_PIXELFORMAT_YUV420&&out.control1==DP_CONVERSION_TO_YCBCR420_ENABLE);
 assert(!msm_dp_utils_select_pcon(&info,dpcd,ports,&mode,30,true,DRM_MODE_COLORIMETRY_DEFAULT,&out));
 assert(out.format==DP_PIXELFORMAT_YUV420&&!out.control1&&!out.control2);
 ports[3]&=~DP_DS_HDMI_YCBCR420_PASS_THROUGH;
 assert(msm_dp_utils_select_pcon(&info,dpcd,ports,&mode,30,true,DRM_MODE_COLORIMETRY_DEFAULT,&out)==-EOPNOTSUPP);
 mode.clock=241500;
 assert(!msm_dp_utils_select_pcon(&info,dpcd,ports,&mode,30,false,DRM_MODE_COLORIMETRY_DEFAULT,&out));
 assert(out.format==DP_PIXELFORMAT_RGB&&!out.control1&&!out.control2);
 struct drm_dp_aux aux={.registers={0xfd,0xff}};
 assert(!msm_dp_utils_configure_pcon(&aux,&out)&&aux.reads==2&&aux.writes==2);
 assert(aux.registers[0]==0xfc&&aux.registers[1]==0x8e);
 out.control1=1;out.control2=DP_CONVERSION_BT2020_RGB_YCBCR_ENABLE;
 for(unsigned fault=0;fault<5;fault++) {
  aux=(struct drm_dp_aux){.registers={0xfe,0x8e}};
  if(fault<2)aux.fail_read=fault+1;
  if(fault>=2&&fault<4)aux.fail_write=fault-1;
  if(fault==4)aux.mismatch=true;
  assert(msm_dp_utils_configure_pcon(&aux,&out)<0);
  assert(aux.registers[0]==0xfe&&aux.registers[1]==0x8e);
 }
 aux=(struct drm_dp_aux){0};out.configure=false;
 assert(!msm_dp_utils_configure_pcon(&aux,&out)&&!aux.reads&&!aux.writes);
 puts("Production RGB/YCbCr422/420 admission, 10-bit TMDS, missing-cap refusal, AUX preservation/readback/rollback: PASS; host only.");
}
C
} > "$work/test.c"
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -Wno-sign-compare -fsanitize=undefined -fsanitize-undefined-trap-on-error "$work/test.c" -o "$work/test"
"$work/test"

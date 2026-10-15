#!/usr/bin/env bash
# Execute the real bonded manager and host read/write path with bounded fake DMA.
set -Eeuo pipefail
kernel=${1:?Pass prepared kernel source}
objects=${2:?Pass object tree with generated DSI register headers}
base=$kernel/drivers/gpu/drm/msm/dsi
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
extract() {
    awk -v signature="$1" '
        $0 == signature { emit=1; found=1 }
        emit { print }
        emit && /^}/ { exit }
        END { if (!found) exit 1 }
    ' "$2"
}
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <errno.h>
#include <string.h>
#include <video/mipi_display.h>
#define FD_NO_DEPRECATED_PACK
#include "dsi.xml.h"
typedef uint8_t u8; typedef uint32_t u32;
#define DBG(...) ((void)0)
#define pr_err(...) ((void)0)
#define pr_warn(...) ((void)0)
#define wmb() ((void)0)
#define DSI_0 0
#define MIPI_DSI_MODE_VIDEO 1
#define MSM_DSI_VER_MAJOR_6G 6
#define MSM_DSI_6G_VER_MINOR_V1_1 1
struct mipi_dsi_msg {u8 channel,type; size_t tx_len; const void *tx_buf; void *rx_buf; size_t rx_len;};
struct mipi_dsi_host {int id;};
struct msm_dsi_host;
struct test_ops {int (*dma_base_get)(struct msm_dsi_host *,uint64_t *);};
struct msm_dsi_cfg_handler {int major,minor; struct test_ops *ops;};
struct drm_display_mode {int hdisplay;};
struct msm_dsi_host {struct mipi_dsi_host base; const struct msm_dsi_cfg_handler *cfg_hnd;
    int id,format,dma_comp; unsigned long mode_flags; struct drm_display_mode *mode; u8 rx_buf[16];};
struct msm_dsi {struct mipi_dsi_host *host;};
static struct msm_dsi_host hosts[2];
static struct msm_dsi devices[2];
static bool sync_needed;
#define IS_SYNC_NEEDED() sync_needed
static struct msm_dsi *dsi_mgr_get_dsi(int id) {assert(id==0 || id==1); return &devices[id];}
static struct msm_dsi_host *to_msm_dsi_host(struct mipi_dsi_host *host) {
    return (struct msm_dsi_host *)host;
}
static int committed[8],commit_count,wait_count,fail_wait,base_error,add_count,fail_add,rx_count;
static int prepared[2],restored[2],fail_prepare,packets[8];
static int dma_base_get(struct msm_dsi_host *host,uint64_t *address) {
    *address=0x1000+host->id*0x100; return base_error;
}
static void msm_dsi_host_cmd_xfer_commit(struct mipi_dsi_host *host,u32 address,u32 len) {
    assert(address==(u32)(0x1000+host->id*0x100) || (sync_needed && host->id==0));
    assert(len==4 && commit_count<8); committed[commit_count++]=host->id;
}
static void reinit_completion(int *completion) {(void)completion;}
static void dsi_wait4video_eng_busy(struct msm_dsi_host *host) {(void)host;}
static int wait_for_completion_timeout(int *completion,int timeout) {
    (void)completion; assert(timeout==200); return ++wait_count==fail_wait ? 0:1;
}
static int msecs_to_jiffies(int ms) {return ms;}
static int mipi_dsi_pixel_format_to_bpp(int format) {(void)format; return 30;}
static int dsi_cmd_dma_add(struct msm_dsi_host *host,const struct mipi_dsi_msg *msg) {
    (void)host; assert(add_count<8); packets[add_count++]=msg->type;
    return add_count==fail_add ? -EIO:4;
}
static int dsi_cmd_dma_rx(struct msm_dsi_host *host,u8 *buf,int bytes,int size) {
    (void)host; assert(bytes==4 && size==1); ++rx_count;
    buf[0]=MIPI_DSI_RX_DCS_SHORT_READ_RESPONSE_1BYTE; buf[1]=0xab; return 4;
}
static int dsi_short_read2_resp(u8 *buf,const struct mipi_dsi_msg *msg) {(void)buf;(void)msg;return 0;}
static int dsi_long_read_resp(u8 *buf,const struct mipi_dsi_msg *msg) {(void)buf;(void)msg;return 0;}
static void dsi_write(struct msm_dsi_host *host,u32 address,u32 value) {
    (void)host; assert(address==REG_DSI_RDBK_DATA_CTRL); assert(value==0 || value==DSI_RDBK_DATA_CTRL_CLR);
}
static int msm_dsi_host_xfer_prepare(struct mipi_dsi_host *host,const struct mipi_dsi_msg *msg) {
    (void)msg; ++prepared[host->id]; return host->id==fail_prepare ? -EIO:0;
}
static void msm_dsi_host_xfer_restore(struct mipi_dsi_host *host,const struct mipi_dsi_msg *msg) {
    (void)msg; ++restored[host->id];
}
C
{
    extract 'bool msm_dsi_manager_cmd_xfer_trigger(int id, u32 dma_base, u32 len,' "$base/dsi_manager.c"
    extract 'static int dsi_cmd_dma_tx(struct msm_dsi_host *msm_host, int len, bool is_read)' "$base/dsi_host.c"
    extract 'static int dsi_cmds2buf_tx(struct msm_dsi_host *msm_host,' "$base/dsi_host.c"
    extract 'static int dsi_short_read1_resp(u8 *buf, const struct mipi_dsi_msg *msg)' "$base/dsi_host.c"
    extract 'int msm_dsi_host_cmd_tx(struct mipi_dsi_host *host,' "$base/dsi_host.c"
    extract 'int msm_dsi_host_cmd_rx(struct mipi_dsi_host *host,' "$base/dsi_host.c"
    extract 'int msm_dsi_manager_cmd_xfer(int id, const struct mipi_dsi_msg *msg)' "$base/dsi_manager.c"
    cat <<'C'
static void reset(void) {
    commit_count=wait_count=base_error=add_count=rx_count=0;
    fail_wait=fail_add=fail_prepare=-1;
    memset(prepared,0,sizeof(prepared)); memset(restored,0,sizeof(restored));
}
int main(void) {
    struct test_ops ops={dma_base_get};
    struct msm_dsi_cfg_handler cfg={6,1,&ops};
    struct drm_display_mode mode={3200};
    u8 reg=0xda,value=0;
    struct mipi_dsi_msg read={.type=MIPI_DSI_DCS_READ,.tx_len=1,.tx_buf=&reg,.rx_buf=&value,.rx_len=1};
    struct mipi_dsi_msg write={.type=MIPI_DSI_DCS_SHORT_WRITE,.tx_len=1,.tx_buf=&reg};
    for(int id=0;id<2;id++) {
        hosts[id]=(struct msm_dsi_host){.base={id},.cfg_hnd=&cfg,.id=id,.mode=&mode,.mode_flags=1};
        devices[id].host=&hosts[id].base;
    }
    for(int sync=0;sync<2;sync++) for(int id=0;id<2;id++) {
        sync_needed=sync; reset(); value=0;
        assert(msm_dsi_manager_cmd_xfer(id,&read)==1 && value==0xab);
        assert(commit_count==2 && wait_count==2 && rx_count==1);
        assert(committed[0]==id && committed[1]==id);
        assert(packets[0]==MIPI_DSI_SET_MAXIMUM_RETURN_PACKET_SIZE && packets[1]==MIPI_DSI_DCS_READ);
        assert(prepared[id]==1 && restored[id]==1);
        assert(prepared[1-id]==0 && restored[1-id]==0);
        reset(); assert(msm_dsi_manager_cmd_xfer(id,&write)>=1);
        if(sync && id==0) assert(commit_count==0 && wait_count==0 && add_count==0);
        else if(sync) {
            assert(commit_count==2 && committed[0]==0 && committed[1]==1 && wait_count==1);
            assert(prepared[0]==1 && restored[0]==1 && prepared[1]==1 && restored[1]==1);
        } else assert(commit_count==1 && committed[0]==id && wait_count==1);
    }
    sync_needed=true;
    for(int id=0;id<2;id++) {
        for(int stage=1;stage<=2;stage++) {
            reset(); fail_wait=stage;
            assert(msm_dsi_manager_cmd_xfer(id,&read)<0);
            assert(wait_count==stage && rx_count==0);
            assert(prepared[id]==1 && restored[id]==1 && !prepared[1-id] && !restored[1-id]);
            reset(); fail_add=stage;
            assert(msm_dsi_manager_cmd_xfer(id,&read)<0 && rx_count==0);
            assert(prepared[id]==1 && restored[id]==1);
        }
        reset(); base_error=-EIO;
        assert(msm_dsi_manager_cmd_xfer(id,&read)<0 && rx_count==0 && wait_count==0);
        assert(prepared[id]==1 && restored[id]==1);
        reset(); fail_prepare=id;
        assert(msm_dsi_manager_cmd_xfer(id,&read)<0 && commit_count==0 && restored[id]==0);
    }
}
C
} >> "$work/check.c"
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -Wno-sign-compare \
    -Wno-missing-field-initializers -fsanitize=undefined -fsanitize-undefined-trap-on-error \
    -I "$kernel/include" -I "$objects/drivers/gpu/drm/msm/generated" "$work/check.c" -o "$work/check"
"$work/check"
printf 'Actual DSI manager/host/DMA: independent bonded reads on both links including max-return-size; write broadcast retained; timeout/error cleanup passed\n'

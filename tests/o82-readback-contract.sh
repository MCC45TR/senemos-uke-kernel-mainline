#!/usr/bin/env bash
# Execute the O82 advisory read helper through the actual MIPI DCS transfer API.
set -Eeuo pipefail
kernel=${1:?Pass prepared kernel source}
panel=$kernel/drivers/gpu/drm/panel/panel-xiaomi-o82.c
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
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <video/mipi_display.h>
typedef uint8_t u8;
#define ARRAY_SIZE(a) (sizeof(a)/sizeof((a)[0]))
#define MIPI_DSI_MODE_LPM 0x800UL
#define MIPI_DSI_CLOCK_NON_CONTINUOUS 0x400UL
#define MIPI_DSI_MSG_USE_LPM 2
struct device {int link;};
struct mipi_dsi_msg {u8 channel,type; unsigned int flags; const void *tx_buf; size_t tx_len; void *rx_buf; size_t rx_len;};
struct mipi_dsi_host;
struct mipi_dsi_host_ops {ssize_t (*transfer)(struct mipi_dsi_host *,const struct mipi_dsi_msg *);};
struct mipi_dsi_host {const struct mipi_dsi_host_ops *ops; int id;};
struct mipi_dsi_device {struct device dev; struct mipi_dsi_host *host; unsigned long mode_flags; u8 channel;};
struct o82_panel {struct mipi_dsi_device *dsi[2];};
static int calls,logs,warnings;
static ssize_t results[4];
static char messages[4][160];
static struct o82_panel *context;
static void record(struct device *dev,bool warning,const char *format,...) {
    assert(logs<4 && dev->link==logs/2);
    va_list args; va_start(args,format);
    assert(vsnprintf(messages[logs],sizeof(messages[logs]),format,args)>0);
    va_end(args); ++logs; warnings+=warning;
}
#define dev_info(dev,...) record(dev,false,__VA_ARGS__)
#define dev_warn(dev,...) record(dev,true,__VA_ARGS__)
static ssize_t transfer(struct mipi_dsi_host *host,const struct mipi_dsi_msg *msg) {
    assert(calls<4 && host->id==calls/2);
    assert(msg->type==MIPI_DSI_DCS_READ && msg->tx_len==1 && msg->rx_len==1);
    assert(msg->channel==0 && !(msg->flags&MIPI_DSI_MSG_USE_LPM));
    assert(!(context->dsi[host->id]->mode_flags&MIPI_DSI_MODE_LPM));
    assert(*(const u8 *)msg->tx_buf==(calls%2 ? MIPI_DCS_GET_POWER_MODE:0xda));
    *(u8 *)msg->rx_buf=(u8)(0xa0+calls);
    return results[calls++];
}
C
{
    extract 'static ssize_t mipi_dsi_device_transfer(struct mipi_dsi_device *dsi,' "$kernel/drivers/gpu/drm/drm_mipi_dsi.c"
    extract 'ssize_t mipi_dsi_dcs_read(struct mipi_dsi_device *dsi, u8 cmd, void *data,' "$kernel/drivers/gpu/drm/drm_mipi_dsi.c"
    extract 'static void o82_readback(struct o82_panel *ctx)' "$panel"
    cat <<'C'
int main(void) {
    struct mipi_dsi_host_ops ops={transfer};
    struct mipi_dsi_host hosts[2]={{&ops,0},{&ops,1}};
    struct mipi_dsi_device dsis[2]={{{0},&hosts[0],0x941UL|MIPI_DSI_MODE_LPM|MIPI_DSI_CLOCK_NON_CONTINUOUS,0},
                                  {{1},&hosts[1],0x51UL|MIPI_DSI_CLOCK_NON_CONTINUOUS,0}};
    struct o82_panel panel={{&dsis[0],&dsis[1]}}; context=&panel;
    for(int scenario=0;scenario<3;scenario++) {
        calls=logs=warnings=0; memset(messages,0,sizeof(messages));
        for(int i=0;i<4;i++) results[i]=scenario==2 ? -EIO:1;
        if(scenario==1) {results[0]=0;results[1]=-ETIMEDOUT;results[2]=2;}
        unsigned long flags[2]={dsis[0].mode_flags,dsis[1].mode_flags};
        o82_readback(&panel);
        assert(calls==4 && logs==4);
        assert(dsis[0].mode_flags==flags[0] && dsis[1].mode_flags==flags[1]);
        assert(warnings==(scenario==0 ? 0:scenario==1 ? 3:4));
        for(int i=0;i<4;i++) {
            assert(strstr(messages[i]," hs result="));
            assert(strstr(messages[i],i%2 ? "cmd=0xa ":"cmd=0xda "));
            if(results[i]==1) assert(!strstr(messages[i],"unavailable"));
            else assert(strstr(messages[i],"value=unavailable"));
        }
    }
    context=NULL;
}
C
} >> "$work/check.c"
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -Wno-sign-compare \
    -fsanitize=undefined -fsanitize-undefined-trap-on-error \
    -I "$kernel/include" "$work/check.c" -o "$work/check"
"$work/check"
printf 'O82 actual MIPI/helper: per-link HS DA/0A reads, advisory success/short/error logs and all mode flags restored\n'

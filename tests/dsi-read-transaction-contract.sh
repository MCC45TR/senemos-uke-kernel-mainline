#!/usr/bin/env bash
# Execute the real bonded manager and host read/write path with bounded fake DMA.
set -Eeuo pipefail
kernel=${1:?Pass prepared kernel source}
objects=${2:?Pass object tree with generated DSI register headers}
headers=${3:-$kernel}
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
#include <sys/types.h>
#include <video/mipi_display.h>
#define FD_NO_DEPRECATED_PACK
#include "dsi.xml.h"
typedef uint8_t u8; typedef uint32_t u32;
#define U32_MAX UINT32_MAX
#define BIT(n) (1U << (n))
#define DSI_CMD_DMA_CTRL_BROADCAST_MASTER BIT(30)
#define SINGLE_DEPTH_NESTING 1
#define READ_ONCE(x) (x)
#define WRITE_ONCE(x,v) ((x)=(v))
#define DSI_RESET_TOGGLE_DELAY_MS 20
#define SZ_4K 4096
#define DBG(...) ((void)0)
#define pr_err(...) ((void)0)
#define pr_warn(...) ((void)0)
#define dev_info_once(dev,message) do { (void)(dev); \
    assert(!strcmp(message,"Uke O82 staged command broadcast completed on both links\n")); \
    ++broadcast_notices; } while(0)
#define pr_err_ratelimited(...) ((void)0)
#define container_of(ptr,type,member) ((type *)((char *)(ptr)-offsetof(type,member)))
#define DSI_ERR_STATE_MDP_FIFO_UNDERFLOW 0x0008
#define ARRAY_SIZE(a) (sizeof(a)/sizeof((a)[0]))
#define wmb() ((void)0)
#define DSI_0 0
#define DSI_1 1
#define MIPI_DSI_MODE_VIDEO 1
#define MSM_DSI_VER_MAJOR_6G 6
#define MSM_DSI_6G_VER_MINOR_V1_1 1
#define MSM_DSI_6G_VER_MINOR_V2_8_0 0x20080000
#define MIPI_DSI_MSG_USE_LPM 1
struct mipi_dsi_msg {u8 channel,type; size_t tx_len; const void *tx_buf; void *rx_buf; size_t rx_len; unsigned int flags;};
struct mipi_dsi_host {int id;};
struct msm_dsi_host;
struct test_ops {int (*dma_base_get)(struct msm_dsi_host *,uint64_t *); void (*link_clk_disable)(struct msm_dsi_host *);
    int (*tx_buf_alloc)(struct msm_dsi_host *,int);};
struct msm_dsi_cfg_handler {int major,minor; struct test_ops *ops;};
struct drm_display_mode {int hdisplay;};
struct drm_device {void *dev;};
struct work_struct {int unused;};
struct msm_dsi_host {struct mipi_dsi_host base; const struct msm_dsi_cfg_handler *cfg_hnd;
    int id,format,dma_comp,cmd_mutex; unsigned long mode_flags; struct drm_display_mode *mode; u8 rx_buf[16];
    bool power_on,cphy_mode,enabled,cmd_dma_blocked; int irq; u32 dma_cmd_ctrl_restore; void *vm;
    struct platform_device *pdev; struct drm_device *dev; void *tx_gem_obj,*tx_buf;
    int tx_size; unsigned long tx_buf_paddr; u32 err_work_state; struct work_struct err_work;};
struct device_node {int unused;};
struct drm_panel {int unused;};
struct platform_device {struct {struct device_node *of_node;} dev;};
struct msm_dsi {struct mipi_dsi_host *host; struct platform_device *pdev;};
static struct msm_dsi_host hosts[2];
static struct msm_dsi devices[2];
static bool sync_needed,bonded,board_uke,board_sm7675,panel_o82,panel_error;
static struct device_node panel_node;
static struct drm_panel panel;
#define IS_SYNC_NEEDED() sync_needed
#define IS_BONDED_DSI() bonded
#define IS_ERR_OR_NULL(p) (!(p) || (intptr_t)(p)==-EIO)
static bool of_machine_is_compatible(const char *name) {
    if(!strcmp(name,"xiaomi,uke")) return board_uke;
    assert(!strcmp(name,"qcom,sm7675")); return board_sm7675;
}
static unsigned long msm_dsi_host_get_mode_flags(struct mipi_dsi_host *host) {return hosts[host->id].mode_flags;}
static struct device_node *of_graph_get_remote_node(struct device_node *node,int port,int endpoint) {
    (void)node; assert(port==1 && endpoint==-1); return &panel_node;
}
static bool of_device_is_compatible(struct device_node *node,const char *name) {
    assert(node==&panel_node);
    assert(!strcmp(name,"xiaomi,o82-36-02-0a") || !strcmp(name,"xiaomi,o82-42-02-0b"));
    return panel_o82;
}
static struct drm_panel *of_drm_find_panel(struct device_node *node) {
    assert(node==&panel_node); return panel_error ? (struct drm_panel *)(intptr_t)-EIO:&panel;
}
static void of_node_put(struct device_node *node) {assert(node==&panel_node);}
static struct msm_dsi *dsi_mgr_get_dsi(int id) {assert(id==0 || id==1); return &devices[id];}
static struct msm_dsi_host *to_msm_dsi_host(struct mipi_dsi_host *host) {
    return (struct msm_dsi_host *)host;
}
static int committed[8],commit_count,wait_count,fail_wait,base_error,add_count,fail_add,rx_count;
static int prepared[2],restored[2],fail_prepare,packets[8];
static int lock_count,unlock_count,staged[2],triggers[2],trigger_count,waited[8],dma_size=4;
static int writes_count,ctrl_writes[2],reinitialized[2];
static u32 dma_ctrl[2],saved_ctrl[2],prepared_ctrl[2],dma_address[2],dma_len[2];
static bool high_address;
static int resets[2],irq_sync[2],irq_masked[2],busy_host=-1,idle_reads[2];
static u32 ctrl_register[2];
static bool reset_asserted[2];
static int clock_disables[2],pm_puts;
static int gem_puts,vm_puts,tx_allocs,dma_frees;
static int error_irq_enables,outer_locks;
static int broadcast_notices;
static int tx_buf_alloc(struct msm_dsi_host *host,int size) {(void)host; assert(size==4096); ++tx_allocs; return 0;}
static void msm_gem_kernel_put(void *gem,void *vm) {assert(gem && vm); ++gem_puts;}
static void drm_gpuvm_put(void *vm) {assert(vm); ++vm_puts;}
static void dma_free_coherent(void *dev,int size,void *buf,unsigned long phys) {
    (void)dev;(void)size;(void)buf;(void)phys; ++dma_frees;
}
static void link_clk_disable(struct msm_dsi_host *host) {++clock_disables[host->id];}
static void pm_runtime_put(void *dev) {(void)dev; ++pm_puts;}
static void msleep(unsigned int ms) {assert(ms==20);}
static void synchronize_irq(int irq) {assert(irq==0 || irq==1); ++irq_sync[irq];}
static void dsi_intr_ctrl(struct msm_dsi_host *host,u32 mask,int enable) {
    if(enable) {assert(mask==DSI_IRQ_MASK_ERROR && !host->cmd_dma_blocked && host->cmd_mutex); ++error_irq_enables; return;}
    if(mask==DSI_IRQ_MASK_CMD_DMA_DONE) ++irq_masked[host->id];
    else assert(mask==(DSI_IRQ_MASK_CMD_MDP_DONE|DSI_IRQ_MASK_VIDEO_DONE));
}
#define read_poll_timeout(op,val,cond,delay,timeout,sleep_first,host,reg) ({ \
    int poll_result=-ETIMEDOUT; assert((delay)==10 && (timeout)==5000 && !(sleep_first)); \
    for(int probe=0;probe<3;probe++) { (val)=op(host,reg); if(cond) {poll_result=0;break;} } \
    poll_result; })
static void lockdep_assert_held(int *lock) {assert(lock==&hosts[1].cmd_mutex && *lock);}
static void mutex_lock_nested(int *lock,int subclass) {
    assert(lock==&hosts[0].cmd_mutex && !*lock && hosts[1].cmd_mutex && subclass==1);
    *lock=1; ++lock_count;
}
static void mutex_unlock(int *lock) {assert((lock==&hosts[0].cmd_mutex || lock==&hosts[1].cmd_mutex) && *lock); *lock=0; ++unlock_count;}
static void mutex_lock(int *lock) {assert(!*lock); *lock=1; ++outer_locks;}
static int invalid_logs,register_reads,last_log_link,last_log_cmd,last_ctrl_valid;
static u32 last_ctrl,last_raw[4],last_timeout;
static u8 response[4]={MIPI_DSI_RX_DCS_SHORT_READ_RESPONSE_1BYTE,0xab,0,0};
static u8 last_header[4];
static int rx_result=4;
static u32 dsi_read(struct msm_dsi_host *host,u32 address) {
    if(address==REG_DSI_CMD_DMA_CTRL) return dma_ctrl[host->id];
    if(address==REG_DSI_CTRL) return ctrl_register[host->id];
    if(address==REG_DSI_STATUS0) {
        ++idle_reads[host->id]; assert(resets[host->id]==1);
        return host->id==busy_host ? DSI_STATUS0_CMD_MODE_DMA_BUSY:0;
    }
    ++register_reads;
    if(address==REG_DSI_RDBK_DATA_CTRL) return 0x00040000U+(u32)host->id;
    if(address==REG_DSI_TIMEOUT_STATUS) return 1U+(u32)host->id;
    for(int i=0;i<4;i++) if(address==REG_DSI_RDBK_DATA(i))
        return 0xa0000000U+((u32)host->id<<16)+(u32)i;
    assert(false); return 0;
}
static void invalid_log(const char *format,const char *function,int id,unsigned int cmd,
                        int width,const void *header,int valid,u32 ctrl,
                        u32 raw0,u32 raw1,u32 raw2,u32 raw3,u32 timeout) {
    assert(strstr(format,"Invalid response link=") && strstr(format,"header=%*ph"));
    assert(strstr(format,"rdbk_ctrl_valid=") && strstr(format,"raw=%08x"));
    assert(!strcmp(function,"msm_dsi_host_cmd_rx") && width==4);
    ++invalid_logs; last_log_link=id; last_log_cmd=(int)cmd; last_ctrl_valid=valid; last_ctrl=ctrl;
    memcpy(last_header,header,4);
    last_raw[0]=raw0; last_raw[1]=raw1; last_raw[2]=raw2; last_raw[3]=raw3;
    last_timeout=timeout;
}
#define pr_warn_ratelimited(...) invalid_log(__VA_ARGS__)
static int dma_base_get(struct msm_dsi_host *host,uint64_t *address) {
    *address=0x1000+host->id*0x100+(high_address ? UINT64_C(0x100000000):0); return base_error;
}
static void msm_dsi_host_cmd_xfer_commit(struct mipi_dsi_host *host,u32 address,u32 len) {
    assert(address==(u32)(0x1000+host->id*0x100) || (sync_needed && host->id==0));
    assert(len==4 && commit_count<8); committed[commit_count++]=host->id;
}
static void reinit_completion(int *completion) {++reinitialized[completion==&hosts[0].dma_comp ? 0:1];}
static void dsi_wait4video_eng_busy(struct msm_dsi_host *host) {(void)host;}
static int wait_for_completion_timeout(int *completion,int timeout) {
    assert(timeout==200 && wait_count<8); waited[wait_count]=completion==&hosts[0].dma_comp ? 0:1;
    return ++wait_count==fail_wait ? 0:1;
}
static int msecs_to_jiffies(int ms) {return ms;}
static int mipi_dsi_pixel_format_to_bpp(int format) {(void)format; return 30;}
static int dsi_cmd_dma_add(struct msm_dsi_host *host,const struct mipi_dsi_msg *msg) {
    (void)host; assert(add_count<8); packets[add_count++]=msg->type;
    return add_count==fail_add ? -EIO:dma_size;
}
static int dsi_cmd_dma_rx(struct msm_dsi_host *host,u8 *buf,int bytes,int size) {
    (void)host; assert(bytes==4 && size==1); ++rx_count;
    memcpy(buf,response,4); return rx_result;
}
static int dsi_short_read2_resp(u8 *buf,const struct mipi_dsi_msg *msg) {(void)buf;(void)msg;return 0;}
static int dsi_long_read_resp(u8 *buf,const struct mipi_dsi_msg *msg) {(void)buf;(void)msg;return 0;}
static void dsi_write(struct msm_dsi_host *host,u32 address,u32 value) {
    int id=host->id;
    if(address==REG_DSI_RDBK_DATA_CTRL) {assert(value==0 || value==DSI_RDBK_DATA_CTRL_CLR); return;}
    assert(hosts[0].cmd_mutex && hosts[1].cmd_mutex);
    ++writes_count;
    if(address==REG_DSI_CTRL) {
        assert(!(value&(DSI_CTRL_ENABLE|DSI_CTRL_CMD_MODE_EN|DSI_CTRL_VID_MODE_EN)));
        ctrl_register[id]=value; return;
    }
    if(address==REG_DSI_CLK_CTRL) {assert(irq_sync[0] && irq_sync[1]); return;}
    if(address==REG_DSI_RESET) {
        assert(!(ctrl_register[0]&DSI_CTRL_ENABLE) && !(ctrl_register[1]&DSI_CTRL_ENABLE));
        assert(irq_masked[0] && irq_masked[1]);
        if(value) reset_asserted[id]=true;
        else {assert(reset_asserted[id]); reset_asserted[id]=false; ++resets[id];}
        return;
    }
    if(address==REG_DSI_CMD_DMA_CTRL) {
        if(ctrl_writes[id]++==0) {
            assert(value & DSI_CMD_DMA_CTRL_BROADCAST_EN);
            assert(!!(value & DSI_CMD_DMA_CTRL_BROADCAST_MASTER)==!id);
            assert((value & ~(BIT(31)|BIT(30)))==(prepared_ctrl[id] & ~(BIT(31)|BIT(30))));
        } else {
            assert(value==prepared_ctrl[id] && wait_count==2);
            if(fail_wait>0) assert(resets[0]==1 && resets[1]==1 && idle_reads[0] && idle_reads[1]);
            assert(!hosts[0].cmd_dma_blocked && !hosts[1].cmd_dma_blocked);
        }
        dma_ctrl[id]=value; return;
    }
    if(address==REG_DSI_DMA_BASE) {assert(!trigger_count); dma_address[id]=value; staged[id]|=1; return;}
    if(address==REG_DSI_DMA_LEN) {assert(!trigger_count); dma_len[id]=value; staged[id]|=2; return;}
    assert(address==REG_DSI_TRIG_DMA && value==1 && trigger_count<2);
    assert(staged[0]==3 && staged[1]==3 && dma_address[0]==dma_address[1] && dma_len[0]==dma_len[1]);
    assert(id==1-trigger_count); triggers[trigger_count++]=id;
}
static int msm_dsi_host_xfer_prepare(struct mipi_dsi_host *host,const struct mipi_dsi_msg *msg) {
    int id=host->id; ++prepared[id];
    if(id==fail_prepare) return -EIO;
    saved_ctrl[id]=dma_ctrl[id];
    hosts[id].dma_cmd_ctrl_restore=ctrl_register[id];
    if(!(msg->flags & MIPI_DSI_MSG_USE_LPM)) dma_ctrl[id]&=~DSI_CMD_DMA_CTRL_LOW_POWER;
    prepared_ctrl[id]=dma_ctrl[id]; return 0;
}
static void msm_dsi_host_xfer_restore(struct mipi_dsi_host *host,const struct mipi_dsi_msg *msg) {
    (void)msg; ++restored[host->id];
    if(!hosts[host->id].cmd_dma_blocked) dma_ctrl[host->id]=saved_ctrl[host->id];
}
C
{
    extract 'bool msm_dsi_manager_cmd_xfer_trigger(int id, u32 dma_base, u32 len,' "$base/dsi_manager.c"
    sed -n '/^#define DSI_CLK_CTRL_ENABLE_CLKS/,/^$/p' "$base/dsi_host.c"
    extract 'static void dsi_sw_reset(struct msm_dsi_host *msm_host)' "$base/dsi_host.c"
    extract 'static void dsi_err_worker(struct work_struct *work)' "$base/dsi_host.c"
    extract 'static void dsi_op_mode_config(struct msm_dsi_host *msm_host,' "$base/dsi_host.c"
    extract 'static void dsi_set_tx_power_mode(int mode, struct msm_dsi_host *msm_host)' "$base/dsi_host.c"
    extract 'void msm_dsi_host_xfer_restore(struct mipi_dsi_host *host,' "$base/dsi_host.c" | sed 's/^void msm_dsi_host_xfer_restore(/void actual_xfer_restore(/'
    extract 'void msm_dsi_tx_buf_free(struct mipi_dsi_host *host)' "$base/dsi_host.c"
    extract 'int msm_dsi_host_modeset_init(struct mipi_dsi_host *host,' "$base/dsi_host.c"
    extract 'int msm_dsi_host_enable(struct mipi_dsi_host *host)' "$base/dsi_host.c"
    extract 'static int dsi_cmd_dma_wait_idle(struct msm_dsi_host *msm_host)' "$base/dsi_host.c"
    extract 'static int dsi_cmd_dma_abort_broadcast(struct msm_dsi_host *master,' "$base/dsi_host.c"
    extract 'static int dsi_cmd_dma_broadcast(struct msm_dsi_host *master,' "$base/dsi_host.c"
    extract 'static int dsi_cmd_dma_tx(struct msm_dsi_host *msm_host, int len, bool is_read,' "$base/dsi_host.c"
    extract 'static int dsi_cmds2buf_tx(struct msm_dsi_host *msm_host,' "$base/dsi_host.c"
    extract 'static int dsi_short_read1_resp(u8 *buf, const struct mipi_dsi_msg *msg)' "$base/dsi_host.c"
    extract 'int msm_dsi_host_cmd_tx(struct mipi_dsi_host *host,' "$base/dsi_host.c"
    extract 'int msm_dsi_host_cmd_rx(struct mipi_dsi_host *host,' "$base/dsi_host.c"
    extract 'int msm_dsi_host_cmd_broadcast(struct mipi_dsi_host *master_host,' "$base/dsi_host.c"
    extract 'static struct drm_panel *dsi_mgr_o82_panel(struct msm_dsi *msm_dsi)' "$base/dsi_manager.c"
    extract 'int msm_dsi_manager_cmd_xfer(int id, const struct mipi_dsi_msg *msg)' "$base/dsi_manager.c"
    extract 'static ssize_t dsi_host_transfer(struct mipi_dsi_host *host,' "$base/dsi_host.c"
    cat <<'C'
static void reset(void) {
    commit_count=wait_count=base_error=add_count=rx_count=0;
    fail_wait=fail_add=fail_prepare=-1;
    bonded=board_uke=board_sm7675=panel_o82=panel_error=false;
    lock_count=unlock_count=trigger_count=writes_count=0; high_address=false; dma_size=4;
    memset(staged,0,sizeof(staged)); memset(ctrl_writes,0,sizeof(ctrl_writes));
    memset(reinitialized,0,sizeof(reinitialized));
    memset(resets,0,sizeof(resets)); memset(irq_sync,0,sizeof(irq_sync));
    memset(irq_masked,0,sizeof(irq_masked)); memset(idle_reads,0,sizeof(idle_reads));
    memset(reset_asserted,0,sizeof(reset_asserted)); busy_host=-1;
    memset(clock_disables,0,sizeof(clock_disables)); pm_puts=0;
    gem_puts=vm_puts=tx_allocs=dma_frees=0;
    error_irq_enables=outer_locks=0;
    broadcast_notices=0;
    for(int id=0;id<2;id++) {
        hosts[id].cmd_mutex=id; hosts[id].power_on=true; hosts[id].cphy_mode=false; hosts[id].vm=hosts;
        hosts[id].cmd_dma_blocked=false; hosts[id].enabled=true; hosts[id].irq=id;
        ctrl_register[id]=0x1f3;
        dma_ctrl[id]=0x1c123456; prepared_ctrl[id]=saved_ctrl[id]=0;
    }
    memset(prepared,0,sizeof(prepared)); memset(restored,0,sizeof(restored));
    invalid_logs=register_reads=0; rx_result=4;
    response[0]=MIPI_DSI_RX_DCS_SHORT_READ_RESPONSE_1BYTE;
    response[1]=0xab; response[2]=response[3]=0;
}
static void admit_o82(void) {
    reset(); sync_needed=bonded=board_uke=board_sm7675=panel_o82=true;
}
static void assert_cleanup(void) {
    assert(lock_count==1 && unlock_count==1 && !hosts[0].cmd_mutex && hosts[1].cmd_mutex);
    assert(dma_ctrl[0]==0x1c123456 && dma_ctrl[1]==0x1c123456);
}
int main(void) {
    struct test_ops ops={dma_base_get,link_clk_disable,tx_buf_alloc};
    struct msm_dsi_cfg_handler cfg={6,1,&ops};
    struct drm_display_mode mode={3200};
    static struct platform_device pdev;
    static struct drm_device drm,other_drm;
    u8 reg=0xda,value=0;
    struct mipi_dsi_msg read={.type=MIPI_DSI_DCS_READ,.tx_len=1,.tx_buf=&reg,.rx_buf=&value,.rx_len=1};
    struct mipi_dsi_msg write={.type=MIPI_DSI_DCS_SHORT_WRITE,.tx_len=1,.tx_buf=&reg};
    for(int id=0;id<2;id++) {
        hosts[id]=(struct msm_dsi_host){.base={id},.cfg_hnd=&cfg,.id=id,.mode=&mode,.mode_flags=1};
        devices[id].host=&hosts[id].base;
        devices[id].pdev=&pdev;
        hosts[id].pdev=&pdev;
        hosts[id].dev=&drm; hosts[id].tx_gem_obj=&hosts[id];
    }
    for(int sync=0;sync<2;sync++) for(int id=0;id<2;id++) {
        sync_needed=sync; reset(); value=0;
        assert(msm_dsi_manager_cmd_xfer(id,&read)==1 && value==0xab);
        assert(commit_count==2 && wait_count==2 && rx_count==1);
        assert(committed[0]==id && committed[1]==id);
        assert(packets[0]==MIPI_DSI_SET_MAXIMUM_RETURN_PACKET_SIZE && packets[1]==MIPI_DSI_DCS_READ);
        assert(prepared[id]==1 && restored[id]==1);
        assert(prepared[1-id]==0 && restored[1-id]==0);
        assert(invalid_logs==0 && register_reads==0);
        reset(); assert(msm_dsi_manager_cmd_xfer(id,&write)>=1);
        if(sync && id==0) assert(commit_count==0 && wait_count==0 && add_count==0);
        else if(sync) {
            assert(commit_count==2 && committed[0]==0 && committed[1]==1 && wait_count==1);
            assert(prepared[0]==1 && restored[0]==1 && prepared[1]==1 && restored[1]==1);
        } else assert(commit_count==1 && committed[0]==id && wait_count==1);
    }
    /* Execute the actual invalid-response branch without changing its result.
     * Both hardware revisions and both links retain bounded selected-host reads.
     */
    for(int sync=0;sync<2;sync++) for(int id=0;id<2;id++) for(int modern=0;modern<2;modern++) {
        sync_needed=sync; cfg.minor=modern;
        reset(); response[0]=0x7f; response[1]=0x12; response[2]=0x34; response[3]=0x56;
        value=0xee;
        assert(msm_dsi_manager_cmd_xfer(id,&read)==0 && value==0xee);
        assert(invalid_logs==1 && register_reads==(modern ? 6:5));
        assert(last_log_link==id && last_log_cmd==0x7f && last_ctrl_valid==modern);
        assert(last_ctrl==(modern ? 0x00040000U+(u32)id:0));
        assert(!memcmp(last_header,response,4));
        assert(last_timeout==1U+(u32)id);
        for(int word=0;word<4;word++) assert(last_raw[word]==0xa0000000U+((u32)id<<16)+(u32)word);
        assert(prepared[id]==1 && restored[id]==1 && !prepared[1-id] && !restored[1-id]);
        assert(commit_count==2 && committed[0]==id && committed[1]==id);
        reset(); rx_result=0;
        assert(msm_dsi_manager_cmd_xfer(id,&read)==0 && invalid_logs==0 && register_reads==0);
        assert(prepared[id]==1 && restored[id]==1);
        reset(); response[0]=MIPI_DSI_RX_ACKNOWLEDGE_AND_ERROR_REPORT;
        assert(msm_dsi_manager_cmd_xfer(id,&read)==0 && invalid_logs==0 && register_reads==0);
        assert(prepared[id]==1 && restored[id]==1);
    }
    cfg.minor=1;
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
    cfg.minor=MSM_DSI_6G_VER_MINOR_V2_8_0;
    for(int lpm=0;lpm<2;lpm++) {
        admit_o82(); write.flags=lpm ? MIPI_DSI_MSG_USE_LPM:0;
        assert(msm_dsi_manager_cmd_xfer(1,&write)==4);
        assert(add_count==1 && !commit_count && trigger_count==2 && triggers[0]==1 && triggers[1]==0);
        assert(broadcast_notices==1);
        assert(wait_count==2 && waited[0]==0 && waited[1]==1);
        assert(reinitialized[0]==1 && reinitialized[1]==1 && writes_count==10);
        assert(prepared[0]==1 && prepared[1]==1 && restored[0]==1 && restored[1]==1);
        assert(ctrl_writes[0]==2 && ctrl_writes[1]==2);
        assert(!resets[0] && !resets[1] && !irq_sync[0] && !irq_sync[1]);
        assert_cleanup();
        admit_o82(); assert(msm_dsi_manager_cmd_xfer(0,&write)==1);
        assert(!writes_count && !prepared[0] && !prepared[1] && !lock_count);
        assert(!broadcast_notices);
        for(int id=0;id<2;id++) {
            admit_o82(); assert(msm_dsi_manager_cmd_xfer(id,&read)==1);
            assert(!writes_count && !lock_count && commit_count==2 && committed[0]==id && committed[1]==id);
            assert(!broadcast_notices);
            assert(packets[0]==MIPI_DSI_SET_MAXIMUM_RETURN_PACKET_SIZE && packets[1]==MIPI_DSI_DCS_READ);
        }
    }
    /* Each admission condition independently retains the legacy write path. */
    for(int gate=0;gate<7;gate++) {
        admit_o82();
        switch(gate) {
        case 0: board_uke=false; break;
        case 1: board_sm7675=false; break;
        case 2: panel_o82=false; break;
        case 3: panel_error=true; break;
        case 4: bonded=false; break;
        case 5: sync_needed=false; break;
        case 6: hosts[0].mode_flags=0; break;
        }
        assert(msm_dsi_manager_cmd_xfer(1,&write)==4);
        assert(!lock_count && !writes_count && wait_count==1);
        assert(!broadcast_notices);
        assert(commit_count==(sync_needed ? 2:1));
        hosts[0].mode_flags=MIPI_DSI_MODE_VIDEO;
    }
    /* Unsupported transfer contracts are rejected before touching hardware. */
    for(int gate=0;gate<7;gate++) {
        admit_o82();
        switch(gate) {
        case 0: cfg.minor=1; break;
        case 1: cfg.major=2; break;
        case 2: hosts[0].vm=NULL; break;
        case 3: hosts[1].vm=&panel; break;
        case 4: hosts[0].power_on=false; break;
        case 5: hosts[1].cphy_mode=true; break;
        case 6: hosts[0].id=1; break;
        }
        assert(msm_dsi_manager_cmd_xfer(1,&write)==-EINVAL);
        assert(!writes_count && !lock_count && !prepared[0] && !prepared[1]);
        cfg.major=6; cfg.minor=MSM_DSI_6G_VER_MINOR_V2_8_0; hosts[0].id=0;
    }
    for(int stage=1;stage<=2;stage++) {
        admit_o82(); fail_wait=stage;
        assert(msm_dsi_manager_cmd_xfer(1,&write)==-ETIMEDOUT);
        assert(wait_count==2 && trigger_count==2 && restored[0]==1 && restored[1]==1);
        assert(!broadcast_notices);
        assert(resets[0]==1 && resets[1]==1 && irq_sync[0]==2 && irq_sync[1]==2);
        assert(reinitialized[0]==2 && reinitialized[1]==2);
        assert(!hosts[0].enabled && !hosts[1].enabled);
        assert(!(hosts[0].dma_cmd_ctrl_restore & (DSI_CTRL_ENABLE|DSI_CTRL_VID_MODE_EN|DSI_CTRL_CMD_MODE_EN)));
        assert(!(hosts[1].dma_cmd_ctrl_restore & (DSI_CTRL_ENABLE|DSI_CTRL_VID_MODE_EN|DSI_CTRL_CMD_MODE_EN)));
        assert_cleanup();
    }
    for(int stuck=0;stuck<2;stuck++) {
        admit_o82(); fail_wait=1; busy_host=stuck;
        assert(msm_dsi_manager_cmd_xfer(1,&write)==-EIO);
        assert(hosts[0].cmd_dma_blocked && hosts[1].cmd_dma_blocked);
        assert(!broadcast_notices);
        assert(reset_asserted[0] && reset_asserted[1]);
        assert(resets[0]==1 && resets[1]==1 && ctrl_writes[0]==1 && ctrl_writes[1]==1);
        assert(idle_reads[stuck]==3 && idle_reads[1-stuck]==1);
        int prior_writes=writes_count,prior_add=add_count,prior_prepare=prepared[0]+prepared[1];
        hosts[0].cmd_mutex=hosts[1].cmd_mutex=0;
        for(int id=0;id<2;id++) {
            assert(dsi_host_transfer(&hosts[id].base,&read)==-EIO);
            assert(dsi_host_transfer(&hosts[id].base,&write)==-EIO);
            dsi_sw_reset(&hosts[id]);
            actual_xfer_restore(&hosts[id].base,&write);
            assert(msm_dsi_host_enable(&hosts[id].base)==-EIO);
            assert(msm_dsi_host_modeset_init(&hosts[id].base,&other_drm)==-EIO);
            assert(hosts[id].dev==&drm && hosts[id].tx_gem_obj==&hosts[id] && hosts[id].vm==hosts);
            msm_dsi_tx_buf_free(&hosts[id].base);
            assert(hosts[id].tx_gem_obj==&hosts[id] && hosts[id].vm==hosts);
            hosts[id].err_work_state=DSI_ERR_STATE_MDP_FIFO_UNDERFLOW;
            int prior_locks=outer_locks;
            dsi_err_worker(&hosts[id].err_work);
            assert(outer_locks==prior_locks+1 && !hosts[id].cmd_mutex);
        }
        assert(writes_count==prior_writes && add_count==prior_add && prepared[0]+prepared[1]==prior_prepare);
        assert(clock_disables[0]==1 && clock_disables[1]==1 && pm_puts==2);
        assert(!tx_allocs && !gem_puts && !vm_puts && !dma_frees);
        assert(!error_irq_enables);
        hosts[1].cmd_mutex=1;
        assert(msm_dsi_host_cmd_broadcast(&hosts[0].base,&hosts[1].base,&write)==-EIO);
        assert(writes_count==prior_writes && add_count==prior_add && prepared[0]+prepared[1]==prior_prepare);
    }
    for(int stage=0;stage<2;stage++) {
        admit_o82(); fail_prepare=stage;
        assert(msm_dsi_manager_cmd_xfer(1,&write)==-EIO);
        assert(!writes_count && !wait_count && prepared[0]==1 && prepared[1]==stage);
        assert(restored[0]==stage && restored[1]==0); assert_cleanup();
    }
    for(int failure=0;failure<4;failure++) {
        admit_o82();
        if(failure==0) base_error=-EIO;
        if(failure==1) fail_add=1;
        if(failure==2) dma_size=16384;
        if(failure==3) high_address=true;
        int result=msm_dsi_manager_cmd_xfer(1,&write);
        assert(result==(failure==2 ? -EINVAL:failure==3 ? -ERANGE:-EIO));
        assert(!writes_count && !wait_count && restored[0]==1 && restored[1]==1);
        assert_cleanup();
    }
    reset();
    assert(msm_dsi_host_modeset_init(&hosts[0].base,&drm)==0 && tx_allocs==1);
    msm_dsi_tx_buf_free(&hosts[0].base);
    assert(gem_puts==1 && vm_puts==1 && !hosts[0].tx_gem_obj && !hosts[0].vm);
    msm_dsi_tx_buf_free(&hosts[0].base);
    assert(gem_puts==1 && vm_puts==1 && !dma_frees);
    reset(); hosts[0].cmd_mutex=0; hosts[0].err_work_state=0;
    dsi_err_worker(&hosts[0].err_work);
    assert(outer_locks==1 && !hosts[0].cmd_mutex && error_irq_enables==1 && !writes_count);
}
C
} >> "$work/check.c"
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -Wno-sign-compare \
    -Wno-missing-field-initializers -fsanitize=undefined -fsanitize-undefined-trap-on-error \
    -I "$headers/include" -I "$objects/drivers/gpu/drm/msm/generated" "$work/check.c" -o "$work/check"
"$work/check"
printf 'Actual DSI: independent reads/generic writes, O82 ordered broadcast, bounded timeout reset and idle checks, stale-IRQ cleanup, locked worker quarantine, blocked transfer/modeset/enable/restore, retained TX and unchanged normal free passed\n'

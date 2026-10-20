#!/usr/bin/env bash
# Exercise the prepared PRM callback and its real synchronous send helper.
set -euo pipefail
kernel=${1:?Pass prepared kernel tree}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
prm=$kernel/sound/soc/qcom/qdsp6/q6prm.c
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
typedef uint32_t u32;
struct device { void *data; };
typedef struct { struct device dev; } gpr_device_t;
typedef int gpr_port_t;
typedef int wait_queue_head_t;
struct mutex { bool held; };
static void mutex_lock(struct mutex *m) { assert(!m->held); m->held = true; }
static void mutex_unlock(struct mutex *m) { assert(m->held); m->held = false; }
#define __packed __attribute__((packed))
#define HZ 1
#define dev_err(...) ((void)0)
#define EXPORT_SYMBOL_GPL(x)
#define wake_up(q) (++*(q))
static void *dev_get_drvdata(struct device *d) { return d->data; }
C
awk '/^struct gpr_hdr \{/ {emit=1} emit {print} emit && /^} __packed;/ {emit=0}' "$kernel/include/linux/soc/qcom/apr.h" >> "$work/check.c"
awk '/^struct gpr_ibasic_rsp_result_t \{/ {emit=1} emit {print} emit && /^};/ {emit=0}' "$kernel/include/linux/soc/qcom/apr.h" >> "$work/check.c"
awk '/^#define GPR_BASIC_RSP_RESULT[[:space:]]/ {print}' "$kernel/include/linux/soc/qcom/apr.h" >> "$work/check.c"
cat >> "$work/check.c" <<'C'
struct gpr_pkt { struct gpr_hdr hdr; };
struct gpr_resp_pkt { struct gpr_hdr hdr; void *payload; int payload_size; };
C
awk '/^struct q6prm \{/ {emit=1} emit {print} emit && /^};/ {emit=0}' "$prm" >> "$work/check.c"
awk '/^#define PRM_CMD_(RSP_)?(REQUEST|RELEASE)_HW_RSC[[:space:]]/ {print}' "$prm" >> "$work/check.c"
cat >> "$work/check.c" <<'C'
static int prm_callback(const struct gpr_resp_pkt *, void *, int);
static gpr_device_t *active_device;
static struct gpr_resp_pkt replies[2];
static int reply_count, reply_next, send_error, sends, callback_error;
static int gpr_send_pkt(gpr_device_t *gdev, const struct gpr_pkt *pkt)
{
 struct q6prm *prm = gdev->dev.data;
 assert(prm->lock.held && !prm->result.opcode && !prm->result.status);
 assert(pkt->hdr.opcode == PRM_CMD_REQUEST_HW_RSC || pkt->hdr.opcode == PRM_CMD_RELEASE_HW_RSC);
 active_device = gdev; sends++; return send_error;
}
static int gpr_send_port_pkt(gpr_port_t *port, const struct gpr_pkt *pkt)
{ (void)port; (void)pkt; assert(false); return -EINVAL; }
static void inject_reply(void)
{
 int ret = prm_callback(&replies[reply_next++], active_device, 0);
 if (ret) callback_error = ret;
}
#define wait_event_timeout(q, condition, timeout) ({ \
 (void)(q); (void)(timeout); \
 while (!(condition) && reply_next < reply_count) inject_reply(); \
 (condition) ? 1 : 0; })
C
awk '/^int audioreach_send_cmd_sync\(/ {emit=1} emit {print} emit && /^}/ {emit=0}' "$kernel/sound/soc/qcom/qdsp6/audioreach.c" >> "$work/check.c"
awk '/^static int (q6prm_send_cmd_sync|prm_callback)\(/ {emit=1} emit {print} emit && /^}/ {emit=0}' "$prm" >> "$work/check.c"
cat >> "$work/check.c" <<'C'
static int request(struct q6prm *prm, u32 cmd, u32 rsp)
{
 struct gpr_pkt pkt = { .hdr = { .opcode = cmd } };
 prm->result = (struct gpr_ibasic_rsp_result_t){ 0xdead, 0xbeef };
 prm->wait = reply_next = callback_error = 0;
 int ret = q6prm_send_cmd_sync(prm, &pkt, rsp);
 assert(!prm->lock.held);
 return ret;
}
int main(void)
{
 struct q6prm prm = {0}; gpr_device_t gdev = { .dev = { &prm } };
 prm.gdev = &gdev; prm.dev = &gdev.dev;
 struct gpr_ibasic_rsp_result_t result;
 _Static_assert(sizeof(result) == 8, "PRM response wire size");
 const u32 cmds[] = { PRM_CMD_REQUEST_HW_RSC, PRM_CMD_RELEASE_HW_RSC };
 const u32 rsps[] = { PRM_CMD_RSP_REQUEST_HW_RSC, PRM_CMD_RSP_RELEASE_HW_RSC };
 for (unsigned i = 0; i < 2; i++) {
  result = (struct gpr_ibasic_rsp_result_t){ cmds[i], 7 };
  replies[0] = (struct gpr_resp_pkt){ .hdr = { .opcode = GPR_BASIC_RSP_RESULT }, .payload = &result, .payload_size = 8 };
  reply_count = 1;
  int ret = request(&prm, cmds[i], rsps[i]);
  if (ret != -EINVAL) fprintf(stderr, "PRM basic error returned %d; expected %d\n", ret, -EINVAL);
  assert(ret == -EINVAL && prm.wait == 1);
  for (int len = -1; len < 8; len++) {
   replies[0].payload_size = len;
   assert(request(&prm, cmds[i], rsps[i]) == -ETIMEDOUT && !prm.wait && callback_error == -EINVAL);
  }
  replies[0].payload_size = 8; replies[0].payload = NULL;
  assert(request(&prm, cmds[i], rsps[i]) == -ETIMEDOUT && !prm.wait && callback_error == -EINVAL);
  replies[0].payload = &result; result.opcode = 0xdead;
  assert(request(&prm, cmds[i], rsps[i]) == -ETIMEDOUT && !prm.wait);
  result.opcode = cmds[i]; result.status = 0;
  assert(request(&prm, cmds[i], rsps[i]) == -ETIMEDOUT && !prm.wait);
  replies[1] = replies[0]; replies[1].hdr.opcode = rsps[i]; reply_count = 2;
  assert(request(&prm, cmds[i], rsps[i]) == 0 && prm.wait == 1 && reply_next == 2);
  replies[0] = replies[1]; reply_count = 1;
  assert(request(&prm, cmds[i], rsps[i]) == 0 && prm.wait == 1);
  result.status = 9;
  assert(request(&prm, cmds[i], rsps[i]) == -EINVAL && prm.wait == 1);
  send_error = -EPIPE; int before = sends;
  assert(request(&prm, cmds[i], rsps[i]) == -EPIPE && !reply_next && !prm.wait && sends == before + 1);
  send_error = 0; reply_count = 0;
  assert(request(&prm, cmds[i], rsps[i]) == -ETIMEDOUT && !prm.wait);
 }
}
C
${CC:-cc} -std=gnu11 -Wall -Wextra -Werror -Wno-sign-compare -Wno-unused-parameter \
    -fsanitize=address,undefined -fno-omit-frame-pointer "$work/check.c" -o "$work/check"
"$work/check"
printf 'PRM actual-source basic errors, ACK, resource replies, bounds and send/timeout fixtures passed.\n'

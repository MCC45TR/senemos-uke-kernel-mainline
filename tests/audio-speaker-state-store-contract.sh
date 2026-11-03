#!/usr/bin/env bash
# COPR only: actual control descriptor and transaction parser, synthetic state.
# alsa-utils v1.2.16 stores readable controls even when marked volatile.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=${1:?Prepared kernel}
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
cat > "$stage/check.c" <<'C'
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <sound/asound.h>
#include "uke-fs19xx-protocol.h"
struct snd_kcontrol_new {
 unsigned int iface;
 const char *name;
 unsigned int access;
 int (*info)(void), (*get)(void), (*put)(void);
};
static int fs19xx_control_info(void) { return 0; }
static int fs19xx_control_get(void) { return 0; }
static int fs19xx_control_put(void) { return 0; }
static int fs19xx_state_info(void) { return 0; }
static int fs19xx_state_get(void) { return 0; }
C
awk '/^static const struct snd_kcontrol_new fs19xx_controls\[\] = [{]/ {emit=1}
 emit {print} emit && /^};/ {exit}' "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c" >> "$stage/check.c"
cat >> "$stage/check.c" <<'C'
/* Model v1.2.16 get_control() admission and writable restore. A readable
 * provisioning control formerly returned exactly this all-zero value. Feed
 * that replay to the real protocol rather than asserting a literal flag. */
static unsigned int store_restore(const struct snd_kcontrol_new *control,
                                 struct uke_fs19xx_state *state)
{
 unsigned char saved[UKE_FS19XX_FRAME_BYTES] = {0};
 if (!(control->access & SNDRV_CTL_ELEM_ACCESS_READ)) return 0;
 assert(control->get);
 if (control->access & SNDRV_CTL_ELEM_ACCESS_WRITE) {
  assert(uke_fs19xx_provision(state, saved, sizeof(saved), false, NULL, NULL) == -EINVAL);
 }
 return 1;
}
int main(void)
{
 struct uke_fs19xx_state state = {.status = UKE_FS_READY};
 struct snd_kcontrol_new before = fs19xx_controls[0];
 before.access = SNDRV_CTL_ELEM_ACCESS_READWRITE | SNDRV_CTL_ELEM_ACCESS_VOLATILE;
 before.get = fs19xx_control_get;
 assert(store_restore(&before, &state) == 1 && state.status == UKE_FS_FAULT);
 state.status = UKE_FS_READY;
 assert(!strcmp(fs19xx_controls[0].name, UKE_FS19XX_CONTROL));
 assert(fs19xx_controls[0].access & SNDRV_CTL_ELEM_ACCESS_WRITE);
 assert(!fs19xx_controls[0].get);
 assert(store_restore(&fs19xx_controls[0], &state) == 0 && state.status == UKE_FS_READY);
 assert(!strcmp(fs19xx_controls[1].name, UKE_FS19XX_STATUS));
 assert(fs19xx_controls[1].access & SNDRV_CTL_ELEM_ACCESS_READ);
 assert(!(fs19xx_controls[1].access & SNDRV_CTL_ELEM_ACCESS_WRITE));
 puts("Actual speaker control descriptor: legacy volatile zero replay faults; write-only provisioning preserves READY and exposes status separately; synthetic state only");
}
C
"${CC:-clang}" -std=gnu11 -Wall -Wextra -Werror -Wno-unused-function \
 -fsanitize=undefined -fno-sanitize-recover=all -I "$owner/src/audio" "$stage/check.c" -o "$stage/check"
"$stage/check"

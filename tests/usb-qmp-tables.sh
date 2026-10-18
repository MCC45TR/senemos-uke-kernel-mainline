#!/usr/bin/env bash
# Host-only native-table execution against memory; never maps a physical register.
set -Eeuo pipefail
kernel=${1:?Pass kernel source with the USB patches applied}
source=$kernel/drivers/phy/qualcomm/phy-qcom-qmp-combo.c
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
{
cat <<'C'
#include <assert.h>
#include <stdint.h>
#include <stddef.h>
typedef uint8_t u8;
#define __iomem
struct device { int unused; };
static unsigned int writes;
static void writel(unsigned int value, void *address) { *(unsigned int *)address=value; writes++; }
#define dev_dbg(dev, ...) ((void)(dev))
C
printf '#include "%s/drivers/phy/qualcomm/phy-qcom-qmp-common.h"\n' "$kernel"
printf '#include "%s/drivers/phy/qualcomm/phy-qcom-qmp-qserdes-com-v6.h"\n' "$kernel"
awk '/^static const struct qmp_phy_init_tbl uke_usb3_serdes_tbl\[\]/ {emit=1}
     /^static const struct qmp_phy_cfg sm7675_usb3dpphy_cfg/ {emit=0}
     emit {print}' "$source"
cat <<'C'
#define COUNT(a) (sizeof(a)/sizeof((a)[0]))
static unsigned int txa[128], txb[128], rxa[128], rxb[128], pcs[256], usb[128], com[128];
int main(void) {
 qmp_configure(NULL,com,uke_usb3_serdes_tbl,COUNT(uke_usb3_serdes_tbl));
 qmp_configure_lane(NULL,txa,uke_usb3_txa_tbl,COUNT(uke_usb3_txa_tbl),1);
 qmp_configure_lane(NULL,txb,uke_usb3_txa_tbl,COUNT(uke_usb3_txa_tbl),2);
 qmp_configure_lane(NULL,rxa,uke_usb3_rxa_tbl,COUNT(uke_usb3_rxa_tbl),1);
 qmp_configure_lane(NULL,rxb,uke_usb3_rxa_tbl,COUNT(uke_usb3_rxa_tbl),2);
 qmp_configure(NULL,pcs,uke_usb3_pcs_tbl,COUNT(uke_usb3_pcs_tbl));
 qmp_configure(NULL,usb,uke_usb3_pcs_usb_tbl,COUNT(uke_usb3_pcs_usb_tbl));
 assert(writes==167);
 assert(txa[0xe4/4]==0x21 && txb[0xe4/4]==0x05);
 assert(rxa[0x15c/4]==0x3f && rxb[0x15c/4]==0xbf);
 assert(rxa[0x164/4]==0xff && rxb[0x164/4]==0xbf);
 assert(rxa[0x16c/4]==0xed && rxb[0x16c/4]==0xfd);
 assert(pcs[0x138/4]==0x1f && pcs[0x16c/4]==0x16);
 qmp_configure(NULL,com,uke_dp_serdes_tbl,COUNT(uke_dp_serdes_tbl));
 assert(com[QSERDES_V6_COM_PLL_IVCO/4]==0x07);
 assert(uke_dp_swing_hbr2[0][0]==0x02 && uke_dp_pre_hbr2[3][0]==0x04);
 assert(uke_dp_swing_rbr_hbr[0][0]==0x07 && uke_dp_swing_rbr_hbr[3][0]==0x1f);
 assert(uke_dp_pre_rbr_hbr[0][0]==0x00 && uke_dp_pre_rbr_hbr[3][0]==0x02);
 return 0;
}
C
} > "$work/qmp.c"
"${CC:-cc}" -std=gnu11 -Wall -Wextra -Werror "$work/qmp.c" -o "$work/qmp"
"$work/qmp"
printf 'Uke QMP tables exercised in host memory; no PHY or DP hardware result\n'

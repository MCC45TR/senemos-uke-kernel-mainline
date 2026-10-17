#!/usr/bin/env bash
# Compile the actual public header for built-in/module/unreachable providers.
set -Eeuo pipefail
header=${1:?Pass candidate include/linux/qcom-uke-display.h}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
mkdir -p "$work/linux"
printf 'struct device;\n' > "$work/linux/device.h"
printf '#define ENODEV 19\n#define EOPNOTSUPP 95\n' > "$work/linux/errno.h"
cat > "$work/linux/kconfig.h" <<'C'
#define IS_ENABLED(x) ((x)==1 || (x)==2)
#define IS_REACHABLE(x) ((x)==1 || ((x)==2 && BUILD_MODULE))
C
cp "$header" "$work/api.h"
cat > "$work/check.c" <<'C'
#include <assert.h>
#include "api.h"
#if IS_REACHABLE(CONFIG_DRM_MSM) && IS_ENABLED(CONFIG_DRM_MSM_DSI)
int qcom_uke_dsi_tp_fps_batch(struct mipi_dsi_device *dsi,const struct mipi_dsi_msg *msgs)
{
    (void)dsi; (void)msgs; return 0;
}
int qcom_uke_dsi_on_batch(struct mipi_dsi_device *dsi,const struct mipi_dsi_msg *msgs,unsigned int count)
{
    (void)dsi; (void)msgs; (void)count; return 0;
}
int qcom_uke_dsi_lp_batch(struct mipi_dsi_device *dsi,const struct mipi_dsi_msg *msgs,unsigned int count)
{
    (void)dsi; (void)msgs; (void)count; return 0;
}
#endif
int main(void)
{
    assert(qcom_uke_dsi_tp_fps_batch(0,0)==
        (IS_REACHABLE(CONFIG_DRM_MSM) && IS_ENABLED(CONFIG_DRM_MSM_DSI) ? 0:-EOPNOTSUPP));
    assert(qcom_uke_display_release(0,0)==-ENODEV);
    assert(qcom_uke_dsi_on_batch(0,0,0)==
        (IS_REACHABLE(CONFIG_DRM_MSM) && IS_ENABLED(CONFIG_DRM_MSM_DSI) ? 0:-EOPNOTSUPP));
    assert(qcom_uke_dsi_lp_batch(0,0,0)==
        (IS_REACHABLE(CONFIG_DRM_MSM) && IS_ENABLED(CONFIG_DRM_MSM_DSI) ? 0:-EOPNOTSUPP));
}
C
for msm in 0 1 2; do
    for dsi in 0 1; do
        for module in 0 1; do
            "${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -Wno-unused-parameter \
                -fsanitize=undefined -fsanitize-undefined-trap-on-error \
                -I "$work" -DCONFIG_ARM_SMMU=0 -DCONFIG_DRM_MSM="$msm" \
                -DCONFIG_DRM_MSM_DSI="$dsi" -DBUILD_MODULE="$module" \
                "$work/check.c" -o "$work/check"
            "$work/check"
        done
    done
done
printf 'Actual Uke header: 12 built-in/module/DSI reachability combinations passed\n'

#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Native provider and reset functions; host boundary models, no device access.
set -Eeuo pipefail
[[ $# == 1 ]] || exit 2
kernel=$(realpath -- "$1")
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
(cd "$kernel"; jq -r '.prepared_helpers[] | .sha256 + "  " + .path' \
    "$project/manifests/camcc-source-candidate-20261021.json" | sha256sum -c -)
mkdir -p "$work/drivers/clk/qcom"
cp "$kernel/drivers/clk/qcom/"{gdsc.c,gdsc.h,common.c,common.h,reset.c} "$work/drivers/clk/qcom/"
for patch in "$project"/src/camera/provider/*.patch; do
    git -C "$work" apply --check "$patch"
    git -C "$work" apply "$patch"
done
for file in vdd-class.h vdd-level.h; do
    sed '/^#include /d' "$kernel/drivers/clk/qcom/$file" > "$work/$file"
done
cp "$kernel/include/dt-bindings/regulator/qcom,rpmh-regulator-levels.h" "$work/rpmh-levels.h"
sed '/^#include /d' "$kernel/drivers/clk/qcom/vdd-class.c" > "$work/vdd-functions.c"
sed '/^#include /d' "$project/src/camera/provider/camcc-sm7675-power.h" > "$work/provider-power.h"
awk '/^static DEFINE_VDD_REGULATORS/ {print}
     /^static struct clk_vdd_class \*cam_cc_sm7675_regulators/ {group=1}
     group {print; if ($0=="};")group=0}' "$project/src/camera/camcc-sm7675-data.h" > "$work/camcc-rails.h"
sed -n '/^#define CAM_CC_SM7675_REGMAP_FORMAT/,/^};/p' \
    "$project/src/camera/camcc-sm7675-data.h" > "$work/camcc-config.h"
awk '/^int pm_runtime_force_(suspend|resume)\(/ {inside=1}
     inside {print; if ($0=="}")inside=0}' "$kernel/drivers/base/power/runtime.c" > "$work/force-pm.c"
awk '/^(int|void) clk_(pre_change_regmap|post_change_regmap|prepare_regmap|unprepare_regmap)\(/ {inside=1}
     inside {print; if ($0=="}")inside=0}' "$kernel/drivers/clk/qcom/clk-regmap.c" > "$work/clock-votes.c"
sed '/^#include /d' "$work/drivers/clk/qcom/reset.c" > "$work/reset-functions.c"
sed -n '/^\tif (!desc->skip_reset_provider) {/,/^\t}/p' \
    "$work/drivers/clk/qcom/common.c" > "$work/common-reset.c"
sed '/^#include /d' "$project/src/camera/camcc-sm7675.c" > "$work/native-provider.c"
read -r -a flags <<< "${CAMCC_TEST_FLAGS:-}"
"${CC:-cc}" -std=gnu11 -O1 -g -Wall -Wextra -Werror -pthread \
    -Wno-unused-function -Wno-unused-parameter -Wno-sign-compare \
    -Wno-unused-but-set-variable -I"$work" "${flags[@]}" \
    "$project/tests/fixtures/camcc-native-check.c" -o "$work/native"
timeout 30 "$work/native"

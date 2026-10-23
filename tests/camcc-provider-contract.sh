#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Actual provider/VDD/forced-PM functions with host-only hardware boundaries.
set -Eeuo pipefail
[[ $# == 1 ]] || exit 2
kernel=$(realpath -- "$1")
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
printf '%s  %s\n' \
    58333db1f02cd0d39d7b96d71ff828d35734eae67165c4b6aa573a1b61d815eb "$kernel/drivers/clk/qcom/vdd-class.c" \
    5d9ac761527a5fa82aa540305690b2b6f4a9a091dcd4a956dae02960b5d95edf "$kernel/drivers/clk/qcom/vdd-level.h" \
    63b02af3ee079df0d063c2a2d2720296a97db8f3f958f694c4f9ef28ff1b7cf9 "$kernel/drivers/clk/qcom/vdd-class.h" \
    86a4ab8982d610b0ff1a1eb998adaf99a5f914833a56e70fb62efda2764af566 "$kernel/drivers/base/power/runtime.c" \
    77e3f7970c89c51890982a711ea6fd72803ce00b04a7e03ae0611c5e83b5469b "$kernel/include/dt-bindings/regulator/qcom,rpmh-regulator-levels.h" | sha256sum -c -
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
read -r -a flags <<< "${CAMCC_TEST_FLAGS:-}"
"${CC:-cc}" -std=gnu11 -O1 -g -Wall -Wextra -Werror \
    -Wno-unused-function -Wno-unused-parameter -Wno-sign-compare \
    -Wno-unused-but-set-variable -I"$work" "${flags[@]}" \
    "$project/tests/fixtures/camcc-provider-check.c" -o "$work/provider"
"$work/provider"

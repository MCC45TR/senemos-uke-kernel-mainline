#!/usr/bin/env bash
# Isolated host preparation only; does not change configuration, DT or devices.
set -Eeuo pipefail
[[ $# == 1 && -d $1 ]] || exit 2
kernel=$(realpath "$1")
here=$(cd -- "$(dirname -- "$0")" && pwd)
[[ $(awk '/^VERSION =/ {v=$3} /^PATCHLEVEL =/ {p=$3} /^SUBLEVEL =/ {s=$3} END {print v "." p "." s}' "$kernel/Makefile") == 7.2.10 ]]
[[ $(jq -er .version "$kernel/senemos-adaptation/source-lock.json") == 7.2.10 ]]
cmp "$kernel/senemos-applied-patches.txt" <(jq -er '.patches[].path | split("/") | last' "$kernel/senemos-adaptation/source-lock.json")
patch=$here/../../patches/display/7.2.10/0001-native-display-providers.patch
paths=(
    drivers/gpu/drm/msm/disp/dpu1/catalog/dpu_10_1_sm7675.h
    drivers/gpu/drm/panel/panel-xiaomi-o82.c
    drivers/gpu/drm/panel/o82-data.h
    drivers/clk/qcom/uke-dispcc-votes.c
    drivers/interconnect/qcom/cliffs-display-icc.h
    drivers/iommu/arm/arm-smmu/uke-display-smmu.c
    drivers/gpu/drm/msm/uke-mdss-handoff.c
    include/linux/qcom-uke-display.h
)
for path in "${paths[@]}"; do [[ ! -e $kernel/$path ]]; done
git -C "$kernel" apply --check "$patch"
git -C "$kernel" apply "$patch"
for path in "${paths[@]}"; do install -m644 "$here/${path##*/}" "$kernel/$path"; done
printf 'Native display providers staged; kernel config and DT activation unchanged\n'

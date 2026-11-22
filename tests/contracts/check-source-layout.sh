#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C

[[ $# -le 1 ]]
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
inputs=$root/packaging/rpm/kernel/inputs
source_dir=${1:-}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

(cd "$inputs"; sha256sum --check --strict --quiet SHA256SUMS)
cd "$root"
cut -f 1 kernel/source-layout.tsv | sort -cu
while IFS=$'\t' read -r path digest source member; do
    [[ -n $path && $digest =~ ^[a-f0-9]{64}$ && -n $source && -n $member ]]
    printf '%s  %s\n' "$digest" "$path"
done < kernel/source-layout.tsv | sha256sum --check --strict --quiet

while IFS=$'\t' read -r path _ source member; do
    if [[ -n $source_dir ]]; then
        original=$source_dir/$source
    elif [[ -f $inputs/$source ]]; then
        original=$inputs/$source
    else
        continue
    fi
    if [[ $member == - ]]; then
        cmp -- "$path" "$original"
        continue
    fi
    if [[ ! -d $work/$source ]]; then
        mkdir -- "$work/$source"
        tar -xJf "$original" -C "$work/$source"
    fi
    cmp -- "$path" "$work/$source/$member"
done < kernel/source-layout.tsv

while IFS= read -r patch; do
    [[ -f kernel/patches/$patch ]]
    printf '%s\n' "${patch##*/}"
done < kernel/patches/series > "$work/base-series"
jq -r '.patches[].path | split("/") | last' kernel/source-lock.json |
    cmp - "$work/base-series"
if [[ -n $source_dir ]]; then
    cmp "$work/base-series" "$work/senemos-uke-adaptation-7.3.5.tar.xz/senemos-adaptation/patches/series"
fi

spec=packaging/rpm/kernel/senemos-uke-linux-kernel-mainline.spec
sed -nE 's/^(dpu_gamma|o82_preferred|fixed_dsi|rtc_bindings|rtc_counter)_patch=\$[a-z0-9_]+\/([^[:space:]]+\.patch)$/\2/p' "$spec" |
    cmp - <(sed 's|.*/||' kernel/patches/release-delta.series)
while IFS= read -r patch; do
    [[ -f kernel/patches/$patch ]]
done < kernel/patches/release-delta.series

printf 'Kernel source layout checks passed.\n'

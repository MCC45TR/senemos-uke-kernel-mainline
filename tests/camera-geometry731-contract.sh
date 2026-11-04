#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# COPR only: actual prepared mode data and 7.3.1 state callbacks.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 2 ]] || exit 2
kernel=$(realpath -- "$1")
before=$(realpath -- "$2")
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
ulimit -c 0
printf '%s  %s\n' 96aad491915796d54e2a8cd20c90a9a8c4e58515c64f7ad4d5faae39caa4d31c "$before" | sha256sum -c --strict -
extract() {
    local source=$1
    awk '/^#define OV08D10_/ {print}
      /^struct ov08d10_reg \{/ {copy=1}
      /^static const char \* const ov08d10_test_pattern_menu/ {copy=0}
      /^struct ov08d10_lane_cfg \{/ {copy=1}
      /^static u32 ov08d10_get_format_code\(/ {copy=0}
      copy {print}' "$source" > "$work/geometry-data.h"
    : > "$work/geometry-functions.c"
    local name
    for name in ov08d10_get_format_code ov08d10_modes_num to_rate to_pixels_per_line ov08d10_update_pad_format ov08d10_set_format ov08d10_get_format ov08d10_enum_mbus_code ov08d10_enum_frame_size ov08d10_get_selection ov08d10_open; do
        awk -v name="$name" '$0 ~ "^static .* " name "\\(" {copy=1} copy {print; if ($0=="}")copy=0}' "$source" >> "$work/geometry-functions.c"
    done
    awk '/^static const struct v4l2_subdev_pad_ops ov08d10_pad_ops =/ {copy=1}
      copy {print; if ($0=="};")copy=0}' "$source" >> "$work/geometry-functions.c"
    [[ $(grep -c '^static .* ov08d10_pad_ops =' "$work/geometry-functions.c") == 1 ]]
}
fixture=$project/tests/fixtures/camera-geometry731.c
flags=(-std=gnu11 -O1 -g -Wall -Wextra -Werror -Wno-unused-const-variable -Wno-unused-parameter -I"$work")
expect_failure() {
    local binary=$1 label=$2 status
    set +e
    "$binary" > "$work/$label.log" 2>&1
    status=$?
    set -e
    [[ $status == 134 ]] && grep -Fq 'Assertion' "$work/$label.log" || {
        cat "$work/$label.log" >&2
        printf 'Geometry %s did not reproduce the required assertion (exit %s)\n' "$label" "$status" >&2
        exit 1
    }
    printf 'OV08D10 geometry negative control: %s refused with assertion134\n' "$label"
}
extract "$before"
for compiler in gcc clang; do
    "$compiler" "${flags[@]}" "$fixture" -o "$work/before-$compiler"
    expect_failure "$work/before-$compiler" "original-$compiler"
done
extract "$kernel/drivers/media/i2c/ov08d10.c"
[[ $(grep -c '^static int ov08d10_get_selection(' "$work/geometry-functions.c") == 1 ]]
for compiler in gcc clang; do
    for variant in ordinary ubsan asan; do
        extra=()
        case $variant in
          ubsan) extra=(-fsanitize=undefined -fno-sanitize-recover=all -fno-omit-frame-pointer);;
          asan) extra=(-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer);;
        esac
        "$compiler" "${flags[@]}" "${extra[@]}" "$fixture" -o "$work/check-$compiler-$variant"
        "$work/check-$compiler-$variant"
    done
done
cp "$work/geometry-data.h" "$work/original-data.h"
cp "$work/geometry-functions.c" "$work/original-functions.c"
for mutant in binned-crop try-state active-state; do
    cp "$work/original-data.h" "$work/geometry-data.h"
    cp "$work/original-functions.c" "$work/geometry-functions.c"
    case $mutant in
      binned-crop)
        awk '/\.width = 1632,/ {binned=1}
          binned && /\.crop =/ {changed+=sub(/width = 3264/, "width = 1632")}
          {print} END {if(changed!=1)exit 1}' "$work/geometry-data.h" > "$work/mutated-data.h"
        cp "$work/mutated-data.h" "$work/geometry-data.h";;
      try-state)
        sed -i '/\*v4l2_subdev_state_get_crop(sd_state, fmt->pad) = mode->crop;/d' "$work/geometry-functions.c";;
      active-state)
        sed -i 's/sel->r = ov08d10->cur_mode->crop;/sel->r = *v4l2_subdev_state_get_crop(sd_state, sel->pad);/' "$work/geometry-functions.c";;
    esac
    ! cmp -s "$work/original-data.h" "$work/geometry-data.h" || ! cmp -s "$work/original-functions.c" "$work/geometry-functions.c"
    clang "${flags[@]}" "$fixture" -o "$work/mutant-$mutant"
    expect_failure "$work/mutant-$mutant" "$mutant"
done
printf 'Actual geometry callback checks passed; modeled API boundaries do not establish camera/calibration or physical acceptance\n'

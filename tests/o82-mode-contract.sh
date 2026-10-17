#!/usr/bin/env bash
# Host-only execution of the shared exact OEM mode admission helper.
set -Eeuo pipefail
header=${1:?Pass src/display/o82-mode.h}
[[ -f $header && ! -L $header ]]
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
mkdir -p "$work/linux" "$work/drm"
cp "$header" "$work/o82-mode.h"
printf '#define EINVAL 22\n' > "$work/linux/errno.h"
cat > "$work/drm/drm_modes.h" <<'C'
#include <stdbool.h>
struct drm_display_mode {
    int clock, hdisplay, hsync_start, hsync_end, htotal, hskew;
    int vdisplay, vsync_start, vsync_end, vtotal, vscan;
    unsigned int flags;
};
C
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <limits.h>
#include <stddef.h>
#include "o82-mode.h"

static const struct {
    struct drm_display_mode mode;
    int group;
} oem[] = {
    {{804988,3200,3808,3840,3872,0,2136,6782,6784,6930,0,0},2},
    {{804988,3200,3808,3840,3872,0,2136,4183,4185,4331,0,0},2},
    {{804988,3200,3808,3840,3872,0,2136,4010,4012,4158,0,0},2},
    {{967428,3200,3426,3458,3490,0,2136,4472,4474,4620,0,0},0},
    {{804988,3200,3808,3840,3872,0,2136,2162,2164,2310,0,0},2},
    {{967428,3200,3426,3458,3490,0,2136,2162,2164,2310,0,0},0},
    {{1097712,3200,3236,3268,3300,0,2136,2162,2164,2310,0,0},1},
};

int main(void)
{
    assert(qcom_uke_o82_mode_group(NULL) == -EINVAL);
    assert(!qcom_uke_o82_mode(NULL));
    assert(!qcom_uke_o82_live_change(NULL, NULL));
    for (size_t i = 0; i < sizeof(oem) / sizeof(oem[0]); i++) {
        assert(qcom_uke_o82_mode_group(&oem[i].mode) == oem[i].group);
        assert(qcom_uke_o82_mode(&oem[i].mode));
        assert(!qcom_uke_o82_live_change(&oem[i].mode, NULL));
        assert(!qcom_uke_o82_live_change(NULL, &oem[i].mode));
        for (size_t j = 0; j < sizeof(oem) / sizeof(oem[0]); j++) {
            bool expected = i != j;
            assert(qcom_uke_o82_live_change(&oem[i].mode, &oem[j].mode) == expected);
        }
        for (unsigned int field = 0; field < 12; field++) {
            struct drm_display_mode bad = oem[i].mode;
            switch (field) {
            case 0: bad.clock++; break;
            case 1: bad.hdisplay++; break;
            case 2: bad.hsync_start++; break;
            case 3: bad.hsync_end++; break;
            case 4: bad.htotal++; break;
            case 5: bad.hskew++; break;
            case 6: bad.vdisplay++; break;
            case 7: bad.vsync_start++; break;
            case 8: bad.vsync_end++; break;
            case 9: bad.vtotal++; break;
            case 10: bad.vscan++; break;
            case 11: bad.flags++; break;
            }
            assert(qcom_uke_o82_mode_group(&bad) == -EINVAL);
            assert(!qcom_uke_o82_mode(&bad));
            assert(!qcom_uke_o82_live_change(&oem[i].mode, &bad));
            assert(!qcom_uke_o82_live_change(&bad, &oem[i].mode));
        }
        for (unsigned int bit = 0; bit < 32; bit++) {
            struct drm_display_mode bad = oem[i].mode;
            bad.flags = 1U << bit;
            assert(!qcom_uke_o82_mode(&bad));
        }
        struct drm_display_mode bad = oem[i].mode;
        bad.htotal = INT_MIN;
        assert(!qcom_uke_o82_mode(&bad));
        bad = oem[i].mode;
        bad.vtotal = INT_MIN;
        assert(!qcom_uke_o82_mode(&bad));
        /* A group's pixel clock must never select another group's porch. */
        for (size_t j = 0; j < sizeof(oem) / sizeof(oem[0]); j++) {
            if (oem[i].group == oem[j].group)
                continue;
            struct drm_display_mode bad = oem[i].mode;
            bad.clock = oem[j].mode.clock;
            assert(!qcom_uke_o82_mode(&bad));
        }
    }
}
C
"${CC:-cc}" -std=c11 -O2 -Wall -Wextra -Werror -fsanitize=undefined \
    -fsanitize-undefined-trap-on-error -I"$work" "$work/check.c" -o "$work/check"
"$work/check"
printf 'Actual shared O82 mode helper: all seven exact OEM modes, group mapping, field/flag and invalid-mode refusals passed\n'

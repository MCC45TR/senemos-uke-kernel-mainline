#!/usr/bin/env bash
# COPR only: execute the actual prepared codec functions against synthetic I2C.
set -Eeuo pipefail
kernel=${1:?Prepared protected kernel source}
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
codec=$kernel/sound/soc/codecs/fs19xx.c
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
grep -E '^#define FS19XX_(REG_|STATUS_|PWRCTRL_|SYSCTRL_|DACCTRL_|TSCTRL_|VOL_|LOCK_POLL_|HEALTH_POLL_)' \
    "$codec" > "$stage/codec-definitions.h"
for function in fs19xx_read_stable fs19xx_set_volume_reg fs19xx_chip_stop \
    fs19xx_check_health fs19xx_unmute_output fs19xx_unmute_work fs19xx_power_off; do
    awk -v name="$function" '
        $0 ~ "^static (int|void) " name "\\(" {emit=1; found=1}
        emit {print}
        emit && /^}/ {exit}
        END {if (!found) exit 1}' "$codec" >> "$stage/codec-under-test.h"
done
"${CC:-clang}" -std=gnu11 -Wall -Wextra -Werror -fsanitize=address,undefined \
    -I"$stage" -I"$owner/src/audio" "$owner/tests/audio-speaker-safety.c" -o "$stage/test"
"$stage/test"

#!/usr/bin/bash
# COPR only. Catch fixture/header type errors before cumulative preparation.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Unpacked kernel}")
profile=$kernel/native-profile
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir "$work/sound"
cp "$kernel/include/uapi/sound/asound.h" "$work/sound/asound.h"
awk '/^const struct snd_pcm_chmap_elem snd_pcm_std_chmaps\[\] = / {copy=1} copy{print} copy&&/^};/{found++;exit} END{if(found!=1)exit 1}' \
 "$kernel/sound/core/pcm_lib.c" > "$work/actual-alsa-standard-chmaps.inc"
for cc in gcc clang;do
 "$cc" -std=gnu11 -UNDEBUG -Wall -Wextra -Werror -I"$work" -fsyntax-only "$profile/tests/speaker-surround-stream.c"
done
printf 'Surround FE fixture type preflight passed before cumulative preparation; runtime tests remain required.\n'

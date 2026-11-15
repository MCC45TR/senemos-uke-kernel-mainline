#!/usr/bin/bash
# COPR only; the inverse authenticates the entire existing AudioReach unit.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
profile=$kernel/native-profile
work=$kernel/native-generated/pcm-surround733
file=sound/soc/qcom/qdsp6/audioreach.c
patch=$profile/src/audio/0033-audioreach-eight-channel-pcm.patch
[[ ! -e $work ]]
mkdir -p "$work/inverse/sound/soc/qcom/qdsp6"
cp "$kernel/$file" "$work/before.c"
git -C "$kernel" apply --check --whitespace=error "$patch"
git -C "$kernel" apply --whitespace=error "$patch"
cp "$kernel/$file" "$work/inverse/$file"
git -C "$work/inverse" init -q
git -C "$work/inverse" apply -R --whitespace=error "$patch"
cmp "$work/before.c" "$work/inverse/$file"
(cd "$kernel";sha256sum "$file") > "$work/applied.sha256"
printf 'PCM6/8 transport applied with whole-unit inverse; gains, routing, DMA and compressed encoder unchanged.\n'

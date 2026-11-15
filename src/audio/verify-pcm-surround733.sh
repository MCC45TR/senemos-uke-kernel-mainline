#!/usr/bin/bash
# Host-only whole-unit proof for retained source-view checks.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
work=$kernel/native-generated/pcm-surround733
file=sound/soc/qcom/qdsp6/audioreach.c
[[ -f $work/before.c && ! -L $work/before.c ]]
(cd "$kernel";sha256sum -c --strict --quiet "$work/applied.sha256")
expected=$(awk -v path="$file" '$2==path{print $1;n++}END{if(n!=1)exit 1}' "$kernel/native-generated/surround-full733/applied.sha256")
printf '%s  %s\n' "$expected" "$work/before.c" | sha256sum -c --strict --quiet -
# Reconstruct from the current source, rather than trusting a saved inverse.
check=$(mktemp -d)
trap 'find "$check" -depth -delete' EXIT
mkdir -p "$check/sound/soc/qcom/qdsp6"
cp "$kernel/$file" "$check/$file"
git -C "$check" init -q
git -C "$check" apply -R --whitespace=error "$kernel/native-profile/src/audio/0033-audioreach-eight-channel-pcm.patch"
cmp "$check/$file" "$work/before.c"

#!/usr/bin/env bash
# COPR only, after all cumulative protected STOP preparation.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative source}")
profile=$(realpath "${2:?Cumulative native profile}")
[[ $profile == "$kernel/native-profile" ]]
source=$kernel/sound/soc/qcom/qdsp6/q6apm-dai.c
before=$kernel/native-generated/pcm-before-period-work.c
test ! -e "$before"
printf '%s  %s\n' acb1773a93e99881ff51bcc78c26e8d48b6e8c59cb396755d47100dd91a6797b "$source" | sha256sum -c --strict -
cp "$source" "$before"
git -C "$kernel" apply --check --whitespace=error "$profile/src/audio/0025-q6apm-defer-pcm-periods.patch"
git -C "$kernel" apply --whitespace=error "$profile/src/audio/0025-q6apm-defer-pcm-periods.patch"
bash "$profile/packaging/native/check-pcm-period733.sh" "$kernel" "$kernel/native-generated" source
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
install -Dm644 "$source" "$work/sound/soc/qcom/qdsp6/q6apm-dai.c"
git -C "$work" apply --reverse --whitespace=error "$profile/src/audio/0025-q6apm-defer-pcm-periods.patch"
cmp "$before" "$work/sound/soc/qcom/qdsp6/q6apm-dai.c"
for cc in gcc clang;do for sanitize in 0 1;do
 CC=$cc SANITIZE=$sanitize bash "$profile/tests/pcm-period-worker.sh" "$kernel" "$before"
done;done
# Admit exact new bytes before any inherited source view or object claim.
cp "$source" "$work/new.c"
printf '\n' >> "$source"
if bash "$profile/packaging/native/check-pcm-period733.sh" "$kernel" "$kernel/native-generated" source > "$work/refusal.txt" 2>&1;then exit 1;fi
grep -Fq FAILED "$work/refusal.txt"
cp "$work/new.c" "$source"
printf 'PCM period source alteration refused.\n'
bash "$profile/packaging/native/check-pcm-period733.sh" "$kernel" "$kernel/native-generated" source
printf 'Actual cumulative PCM period callbacks and whole-source inverse passed; physical STOP acceptance separate.\n'

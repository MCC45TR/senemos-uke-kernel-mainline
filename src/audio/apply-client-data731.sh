#!/usr/bin/env bash
# COPR only. Extend the complete14 backend after all inherited prep controls.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared complete14 kernel}")
profile=$(realpath "${2:?Cumulative native profile}")
[[ $profile == "$kernel/native-profile" ]]
actual=$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-oob-backend.c
before=$kernel/native-generated/backend-before-client-data.c
test ! -e "$before"
printf '%s  %s\n' 785cc934edcad0cbdcbd78248bed352e3c80992f9a1b0961c4c466c9d1508b73 "$actual" | sha256sum -c --strict -
cp "$actual" "$before"
patch -d "$kernel" --dry-run --batch --fuzz=0 -p1 -i "$profile/src/audio/0010-uke-gpr-response-client-data.patch"
patch -d "$kernel" --batch --fuzz=0 -p1 -i "$profile/src/audio/0010-uke-gpr-response-client-data.patch"
printf '%s  %s\n' bcbff25aebc8189deafbc957dd754943c76434ed12712b45bb3ff998c2ef1690 "$actual" | sha256sum -c --strict -
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
mkdir -p "$work/sound/soc/qcom/qdsp6"
cp "$actual" "$work/sound/soc/qcom/qdsp6/uke-fs19xx-oob-backend.c"
patch -R -d "$work" --batch --fuzz=0 -p1 -i "$profile/src/audio/0010-uke-gpr-response-client-data.patch"
cmp "$work/sound/soc/qcom/qdsp6/uke-fs19xx-oob-backend.c" "$before"
for cc in gcc clang;do for san in 0 1;do
 CC=$cc SANITIZE=$san bash "$profile/tests/audio-gpr-client-data.sh" "$kernel"
done;done
bash "$profile/tests/audio-gpr-client-data-seal.sh" "$kernel"
printf 'GPR defined client data and true-reserved refusal qualified; private tuning and lifetime source unchanged; physical audio remains open.\n'

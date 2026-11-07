#!/usr/bin/env bash
# COPR-only focused callback proof; no full kernel or device qualification.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?Source result directory}")
[[ ! -e $output ]]
mkdir -p "$output" "$output/source/sound/soc/codecs" "$output/source/sound/soc/qcom/qdsp6"
cd "$output/source"
for name in 0115-asoc-fs19xx-smart-amplifier 0117-asoc-uke-audio-runtime-safety 0118-asoc-fs19xx-speaker-rotation 0119-asoc-uke-probe-readiness;do
 git apply --include=sound/soc/codecs/fs19xx.c "$owner/patches/7.3.0/$name.patch"
done
git apply --include=sound/soc/codecs/fs19xx.c "$owner/patches/boot/0058-fs19xx-current-workqueue.patch"
# The authenticated protected layer is acquired by the source worker from7331.
git apply --include=sound/soc/codecs/fs19xx.c "$owner/retained-stop-inputs/0073-uke-fs19xx-protected-runtime.patch"
git apply --include=sound/soc/codecs/fs19xx.c "$owner/src/audio/0015-uke-protected-stop-drain.patch"
git apply --include=sound/soc/codecs/fs19xx.c "$owner/src/audio/0017-uke-protected-idle-worker.patch"
printf '%s  %s\n' d8a9e70f14fd854e3333352199abc0fb5fe8d632c1bf298b25d01d931cc494cb sound/soc/codecs/fs19xx.c | sha256sum -c --strict -
cp sound/soc/codecs/fs19xx.c codec-before-deadline.c
cp "$owner/src/audio/uke-fs19xx-muted-stop.h" sound/soc/codecs/uke-fs19xx-muted-stop.h
cp sound/soc/codecs/uke-fs19xx-muted-stop.h muted-before-deadline.h
cp "$owner/retained-stop-inputs/uke-fs19xx-safety.h" sound/soc/qcom/qdsp6/uke-fs19xx-safety.h
git apply --check --whitespace=error "$owner/src/audio/0020-fs19xx-muted-stop-deadline.patch"
git apply --whitespace=error "$owner/src/audio/0020-fs19xx-muted-stop-deadline.patch"
for cc in gcc clang;do for san in 0 1;do for ticks in 100 250 1000;do
 CC=$cc SANITIZE=$san TICKS=$ticks bash "$owner/tests/audio-stop-deadline.sh" "$PWD"
done;done;done
git apply --reverse --whitespace=error "$owner/src/audio/0020-fs19xx-muted-stop-deadline.patch"
cmp sound/soc/codecs/fs19xx.c codec-before-deadline.c
cmp sound/soc/codecs/uke-fs19xx-muted-stop.h muted-before-deadline.h
printf 'Exact codec and mute-helper reverse comparison passes. No kernel ABI, full build, installation or physical acceptance.\n'

#!/usr/bin/env bash
# COPR only, after every original7331 source gate and native fixture completes.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Complete prepared cumulative7331}")
profile=$(realpath "${2:?Cumulative native profile}")
[[ $profile == "$kernel/native-profile" ]]
generated=$kernel/native-generated
paths=(sound/soc/codecs/fs19xx.c sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c sound/soc/codecs/uke-fs19xx-muted-stop.h)
before=(d8a9e70f14fd854e3333352199abc0fb5fe8d632c1bf298b25d01d931cc494cb d9bf78985dd1de6db50daddce2c544d2b88496b085f821bcfdab86a44c4da157 aac729f7c7c893cf69048da8c21c8c0cdf078dd9563ddf0a594c63323a004955)
names=(codec-before-stop-deadline.c runtime-before-stop-deadline.c muted-before-stop-deadline.h)
for index in 0 1 2;do
 [[ ! -e $generated/${names[index]} ]]
 printf '%s  %s\n' "${before[index]}" "$kernel/${paths[index]}" | sha256sum -c --strict -
 cp "$kernel/${paths[index]}" "$generated/${names[index]}"
done
grep -Eq '^#define APM_CMD_GRAPH_STOP[[:space:]]+0x01001003' "$kernel/sound/soc/qcom/qdsp6/audioreach.h"
for patch in 0020-fs19xx-muted-stop-deadline.patch 0021-fs19xx-publish-muted-gate.patch;do
 git -C "$kernel" apply --check --whitespace=error "$profile/src/audio/$patch"
 git -C "$kernel" apply --whitespace=error "$profile/src/audio/$patch"
done
bash "$profile/packaging/native/check-stop-deadline733.sh" "$kernel" "$generated" source
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
for path in "${paths[@]}";do install -Dm644 "$kernel/$path" "$work/$path";done
for patch in 0021-fs19xx-publish-muted-gate.patch 0020-fs19xx-muted-stop-deadline.patch;do
 git -C "$work" apply --reverse --whitespace=error "$profile/src/audio/$patch"
done
for index in 0 1 2;do cmp "$work/${paths[index]}" "$generated/${names[index]}";done
# Existing test entrypoints consume these explicit exact baseline source views.
cp "$generated/codec-before-stop-deadline.c" "$kernel/codec-before-deadline.c"
cp "$generated/muted-before-stop-deadline.h" "$kernel/muted-before-deadline.h"
for cc in gcc clang;do for san in 0 1;do for ticks in 100 250 1000;do
 CC=$cc SANITIZE=$san TICKS=$ticks bash "$profile/tests/audio-stop-deadline.sh" "$kernel"
done;done;done
for path in "${paths[@]}";do
 cp "$kernel/$path" "$work/$path"
 printf '\n' >> "$kernel/$path"
 if bash "$profile/packaging/native/check-stop-deadline733.sh" "$kernel" "$generated" source > "$work/refusal.txt" 2>&1;then exit 1;fi
 grep -Fq FAILED "$work/refusal.txt"
 cp "$work/$path" "$kernel/$path"
 printf 'Muted deadline source alteration refused: %s.\n' "$path"
done
bash "$profile/packaging/native/check-stop-deadline733.sh" "$kernel" "$generated" source
printf 'Actual cumulative muted STOP callbacks, inverse sources and all timer/mutant modes passed; physical speaker acceptance separate.\n'

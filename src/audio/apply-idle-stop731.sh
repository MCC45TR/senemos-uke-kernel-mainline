#!/usr/bin/env bash
# COPR only. Actual complete17 and every original STOP control run first.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared complete17 kernel}")
profile=$(realpath "${2:?Cumulative profile}")
[[ $profile == "$kernel/native-profile" ]]
generated=$kernel/native-generated
paths=(sound/soc/codecs/fs19xx.c sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c include/sound/uke-fs19xx-guard.h)
names=(codec runtime guard-header)
before=(4c7ce07b2868cdc76fc0534f9bfe46805b956ebdb6200dacd44fa205579651e2 3774c03041895fb5876611c4e73d3bf19aaa191d1d5cd3278fd13667dc1492b5 f3b03a6846b034f64def55739191354919ecb395eac89685fc845364e6bd889f)
for i in 0 1 2;do
 [[ ! -e $generated/${names[i]}-before-idle-stop.c ]]
 printf '%s  %s\n' "${before[i]}" "$kernel/${paths[i]}" | sha256sum -c --strict -
 cp "$kernel/${paths[i]}" "$generated/${names[i]}-before-idle-stop.c"
done
git -C "$kernel" apply --check --whitespace=error "$profile/src/audio/0017-uke-protected-idle-worker.patch"
git -C "$kernel" apply --whitespace=error "$profile/src/audio/0017-uke-protected-idle-worker.patch"
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
for path in "${paths[@]}";do install -Dm644 "$kernel/$path" "$work/$path";done
git -C "$work" apply --reverse --whitespace=error "$profile/src/audio/0017-uke-protected-idle-worker.patch"
for i in 0 1 2;do cmp "$work/${paths[i]}" "$generated/${names[i]}-before-idle-stop.c";done
bash "$profile/packaging/native/check-idle-stop731.sh" "$kernel" "$generated" source
for cc in gcc clang;do for san in 0 1;do CC=$cc SANITIZE=$san bash "$profile/tests/audio-idle-stop.sh" "$kernel";done;done
for path in "${paths[@]}";do
 cp "$kernel/$path" "$work/$path"
 printf '\n' >> "$kernel/$path"
 if bash "$profile/packaging/native/check-idle-stop731.sh" "$kernel" "$generated" source > "$work/refusal.log" 2>&1;then exit 1;fi
 grep -Fq FAILED "$work/refusal.log"
 cp "$work/$path" "$kernel/$path"
 printf 'Idle STOP source refusal passed: %s.\n' "$path"
done
bash "$profile/packaging/native/check-idle-stop731.sh" "$kernel" "$generated" source
printf 'Actual healthy idle classification and all retained STOP controls pass; gain, calibration and bounded fault shutdown retained; hardware acceptance separate.\n'

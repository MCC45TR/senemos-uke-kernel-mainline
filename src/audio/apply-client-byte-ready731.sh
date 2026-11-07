#!/usr/bin/env bash
# COPR only; all complete15 controls run before this layer.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared complete15 kernel}")
profile=$(realpath "${2:?Cumulative profile}")
[[ $profile == "$kernel/native-profile" ]]
core=$kernel/sound/soc/qcom/qdsp6
before_byte=$kernel/native-generated/backend-before-client-byte.c
before_ready=$kernel/native-generated/runtime-before-initial-ready.c
[[ ! -e $before_byte && ! -e $before_ready ]]
printf '%s  %s\n' \
 bcbff25aebc8189deafbc957dd754943c76434ed12712b45bb3ff998c2ef1690 "$core/uke-fs19xx-oob-backend.c" \
 58626ac77c9fd677ccadc991f5789766ba380bab63fcc76e5030979e8b87d4e3 "$core/uke-fs19xx-runtime.c" | sha256sum -c --strict -
cp "$core/uke-fs19xx-oob-backend.c" "$before_byte"
cp "$core/uke-fs19xx-runtime.c" "$before_ready"
install -m644 "$profile/src/audio/uke-fs19xx-initial-ready.h" "$core/uke-fs19xx-initial-ready.h"
patch -d "$kernel" --dry-run --batch --fuzz=0 -p1 -i "$profile/src/audio/0012-uke-gpr-client-byte-and-initial-ready.patch"
patch -d "$kernel" --batch --fuzz=0 -p1 -i "$profile/src/audio/0012-uke-gpr-client-byte-and-initial-ready.patch"
printf '%s  %s\n' \
 6d9b4b98558345593762a2f10291d7d17f1279453bc8dacb15ee42c4a33d5113 "$core/uke-fs19xx-oob-backend.c" \
 0e526c3eddccff940925900fc2db4cd0279136de14cac7f393375f98f1ae21ee "$core/uke-fs19xx-runtime.c" | sha256sum -c --strict -
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
mkdir -p "$work/sound/soc/qcom/qdsp6"
for name in uke-fs19xx-oob-backend.c uke-fs19xx-runtime.c;do cp "$core/$name" "$work/sound/soc/qcom/qdsp6/$name";done
patch -R -d "$work" --batch --fuzz=0 -p1 -i "$profile/src/audio/0012-uke-gpr-client-byte-and-initial-ready.patch"
cmp "$work/sound/soc/qcom/qdsp6/uke-fs19xx-oob-backend.c" "$before_byte"
cmp "$work/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c" "$before_ready"
for cc in gcc clang;do for san in 0 1;do
 CC=$cc SANITIZE=$san bash "$profile/tests/audio-gpr-client-byte.sh" "$kernel"
 CC=$cc SANITIZE=$san bash "$profile/tests/audio-initial-ready.sh" "$kernel"
done;done
bash "$profile/tests/audio-client-byte-ready-seal.sh" "$kernel"
printf 'Target client byte and bounded initial-ready source controls pass; tuning/protection/lifetime stay exact; physical sound remains open.\n'

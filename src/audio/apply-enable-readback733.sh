#!/usr/bin/env bash
# COPR only: append a read-only control after retained source gates complete.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative source}")
profile=$(realpath "${2:?Native profile}")
[[ $profile == "$kernel/native-profile" ]]
generated=$kernel/native-generated
core=$kernel/sound/soc/qcom/qdsp6
[[ ! -e $generated/runtime-before-enable-readback.c ]]
printf '%s  %s\n' 2db81985157213fbe61d9d58bd997784264fcee05d34f96f9d4fe1474e92205f "$core/uke-fs19xx-runtime.c" | sha256sum -c --strict -
cp "$core/uke-fs19xx-runtime.c" "$generated/runtime-before-enable-readback.c"
cp "$core/Makefile" "$generated/qdsp6-makefile-before-enable-readback"
[[ $(grep -Fc 'snd-q6apm-y :=' "$core/Makefile") == 1 ]]
[[ $(grep -Fc 'snd-q6apm-y += uke-fs19xx-oob-backend.o' "$core/Makefile") == 1 ]]
for file in uke-fs19xx-readback.c uke-fs19xx-readback.h uke-fs19xx-enable-control.h;do
 [[ ! -e $core/$file ]]
 install -m644 "$profile/src/audio/$file" "$core/$file"
done
git -C "$kernel" apply --check --whitespace=error "$profile/src/audio/0026-fs19xx-enable-readback-control.patch"
git -C "$kernel" apply --whitespace=error "$profile/src/audio/0026-fs19xx-enable-readback-control.patch"
printf '\nsnd-q6apm-y += uke-fs19xx-readback.o\n' >> "$core/Makefile"
bash "$profile/packaging/native/check-enable-readback733.sh" "$kernel" "$generated" source
for cc in gcc clang;do for san in 0 1;do
 CC=$cc SANITIZE=$san bash "$profile/tests/audio-fs19xx-readback.sh"
 CC=$cc SANITIZE=$san bash "$profile/tests/audio-fs19xx-enable-control.sh"
done;done
printf 'Additive speaker enable control and real callback tests passed; gain223 and every original callback retained.\n'

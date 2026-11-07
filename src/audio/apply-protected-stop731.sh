#!/usr/bin/env bash
# COPR only. Complete16 preparation and controls precede this source layer.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared complete16 kernel}")
profile=$(realpath "${2:?Cumulative profile}")
[[ $profile == "$kernel/native-profile" ]]
core=$kernel/sound/soc/qcom/qdsp6
generated=$kernel/native-generated
for path in runtime-before-protected-stop.c codec-before-protected-stop.c q6apm-before-protected-stop.c runtime-header-before-protected-stop.h;do [[ ! -e $generated/$path ]];done
printf '%s  %s\n' \
 0e526c3eddccff940925900fc2db4cd0279136de14cac7f393375f98f1ae21ee "$core/uke-fs19xx-runtime.c" \
 e2ca68c256f47bb7bc339ffb4dfb5833dc5787904828eed68f75dafd613f77b8 "$kernel/sound/soc/codecs/fs19xx.c" \
 58bd8b9c9c947632cae1c0951fb0b5facd25a683e8a6b2bd93e0a27d35a0466a "$core/uke-fs19xx-runtime.h" | sha256sum -c --strict -
cp "$core/uke-fs19xx-runtime.c" "$generated/runtime-before-protected-stop.c"
cp "$core/uke-fs19xx-runtime.h" "$generated/runtime-header-before-protected-stop.h"
cp "$core/q6apm.c" "$generated/q6apm-before-protected-stop.c"
cp "$kernel/sound/soc/codecs/fs19xx.c" "$generated/codec-before-protected-stop.c"
awk '/^int q6apm_graph_stop\(/ {copy=1} copy{print} copy&&/^}/ {found++;exit} END{if(found!=1)exit 1}' "$core/q6apm.c" > "$generated/graph-stop-before-protected-stop.c"
printf '%s  %s\n' 7ccd1442087c2f26769bae2f3378b33539d7aa6868880d32aac71ad14e91dd43 "$generated/graph-stop-before-protected-stop.c" | sha256sum -c --strict -
install -m644 "$profile/src/audio/uke-fs19xx-muted-stop.h" "$kernel/sound/soc/codecs/uke-fs19xx-muted-stop.h"
patch -d "$kernel" --dry-run --batch --fuzz=0 -p1 -i "$profile/src/audio/0015-uke-protected-stop-drain.patch"
patch -d "$kernel" --batch --fuzz=0 -p1 -i "$profile/src/audio/0015-uke-protected-stop-drain.patch"
bash "$profile/packaging/native/check-protected-stop731.sh" "$kernel" "$generated" source
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
for path in sound/soc/codecs/fs19xx.c sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c sound/soc/qcom/qdsp6/uke-fs19xx-runtime.h sound/soc/qcom/qdsp6/q6apm.c;do install -Dm644 "$kernel/$path" "$work/$path";done
patch -R -d "$work" --batch --fuzz=0 -p1 -i "$profile/src/audio/0015-uke-protected-stop-drain.patch"
cmp "$work/sound/soc/codecs/fs19xx.c" "$generated/codec-before-protected-stop.c"
cmp "$work/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c" "$generated/runtime-before-protected-stop.c"
cmp "$work/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.h" "$generated/runtime-header-before-protected-stop.h"
cmp "$work/sound/soc/qcom/qdsp6/q6apm.c" "$generated/q6apm-before-protected-stop.c"
for cc in gcc clang;do for san in 0 1;do CC=$cc SANITIZE=$san bash "$profile/tests/audio-protected-stop.sh" "$kernel";done;done
bash "$profile/tests/audio-protected-stop-seal.sh" "$kernel"
printf 'Muted protected STOP ordering and actual callback controls pass; private tuning/gain/VI and fault containment retained; physical speakers remain unqualified.\n'

#!/usr/bin/env bash
# COPR only; extend the complete protected12211 source after all legacy gates.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
profile=$(realpath "${2:?Cumulative native profile}")
[[ $profile == "$kernel/native-profile" ]]
marker=$kernel/native-generated/uke-oob-native-layer
test ! -e "$marker"
printf '%s  %s\n' 8b6202e36fbfb9c94f290a19a2dfc907d1b1e0c2018dd1f31547ed70df66ea57 \
 "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c" | sha256sum -c --strict -
for asset in uke-fs19xx-oob-backend.c uke-fs19xx-oob-backend.h;do
 install -m644 "$profile/src/audio/$asset" "$kernel/sound/soc/qcom/qdsp6/$asset"
done
install -m644 "$profile/src/audio/uke-audio-config-memory.c" "$kernel/drivers/soc/qcom/uke-audio-config-memory.c"
install -m644 "$profile/src/audio/uke-audio-config-memory.h" "$kernel/include/linux/soc/qcom/uke-audio-config-memory.h"
install -m644 "$profile/src/audio/uke-audio-config-dt.h" "$kernel/arch/arm64/kernel/uke-audio-config-dt.h"
install -Dm644 "$profile/src/audio/xiaomi,uke-audio-config-memory.yaml" \
 "$kernel/Documentation/devicetree/bindings/soc/qcom/xiaomi,uke-audio-config-memory.yaml"
patch -d "$kernel" --dry-run -p1 --fuzz=0 --batch -i "$profile/src/audio/0007-fs19xx-protected-oob.patch"
patch -d "$kernel" -p1 --fuzz=0 --batch -i "$profile/src/audio/0007-fs19xx-protected-oob.patch"
test "$(grep -Fc 'snd-q6apm-y :=' "$kernel/sound/soc/qcom/qdsp6/Makefile")" = 1
! grep -Fq uke-fs19xx-oob-backend.o "$kernel/sound/soc/qcom/qdsp6/Makefile"
! grep -Fq uke-audio-config-memory.o "$kernel/drivers/soc/qcom/Makefile"
printf '\nsnd-q6apm-y += uke-fs19xx-oob-backend.o\n' >> "$kernel/sound/soc/qcom/qdsp6/Makefile"
printf '\nobj-$(CONFIG_ARCH_QCOM) += uke-audio-config-memory.o\n' >> "$kernel/drivers/soc/qcom/Makefile"
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
awk '
 $0=="#include \"uke-pstore-dt.h\"" {print;print "#include \"uke-audio-config-dt.h\"";header++;next}
 $0=="\tret = fdt_pack(output);" {print "\tret = uke_audio_config_graph(output);";print "\tif (ret)";print "\t\treturn ret;";call++}
 {print} END {if(header!=1||call!=1)exit 1}
' "$kernel/arch/arm64/kernel/uke-abl.c" > "$work/abl.c"
install -m644 "$work/abl.c" "$kernel/arch/arm64/kernel/uke-abl.c"
printf 'Exact protected OOB runtime/DT/backend layer installed in prepared source only.\n' > "$marker"
bash "$profile/packaging/native/check-oob-runtime731.sh" "$kernel"
dt-doc-validate "$kernel/Documentation/devicetree/bindings/soc/qcom/xiaomi,uke-audio-config-memory.yaml"
for compiler in gcc clang;do
 for sanitizer in 0 1;do
  CC=$compiler SANITIZE=$sanitizer bash "$profile/tests/audio-fs19xx-oob-backend.sh" "$kernel"
  CC=$compiler SANITIZE=$sanitizer bash "$profile/tests/audio-config-dt.sh" "$kernel"
 done
done

#!/usr/bin/bash
# COPR-only source composition; the firmware guard and probe remain unchanged.
set -Eeuo pipefail
[[ $# == 3 ]]
kernel=$(realpath "$1");owner=$(realpath "$2");result=$(realpath -m "$3")
target=$kernel/drivers/clk/qcom/camcc-sm7675.c
[[ -f $target && ! -L $target && ! -e $result && ! -L $result ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
awk '
 $0=="#include \"provider/camcc-sm7675-crm-rom.h\""{rom++;next}
 $0=="#include \"provider/camcc-sm7675-crm-owner.h\""{owner++;next}
 {print}
 END{if(rom!=1||owner!=1)exit 1}
' "$owner/src/camera/camcc-sm7675.c" > "$work/parent.c"
cmp "$target" "$work/parent.c"
for name in rom owner;do
 [[ ! -e $kernel/drivers/clk/qcom/provider/camcc-sm7675-crm-$name.h ]]
done
for name in core lut passive pm transport;do
 cmp "$owner/src/camera/provider/camcc-sm7675-crm-$name.h" "$kernel/drivers/clk/qcom/provider/camcc-sm7675-crm-$name.h"
done
mkdir "$result"
cp "$target" "$result/parent-camcc-sm7675.c"
(cd "$kernel";sha256sum drivers/clk/qcom/provider/{camcc-sm7675-crm-guard,camcc-sm7675-registration,camcc-sm7675-crmc-resource,camcc-sm7675-crm-transport,camcc-sm7675-crm-pm}.h) > "$result/retained.sha256"
install -m644 "$owner/src/camera/camcc-sm7675.c" "$target"
for name in rom owner;do
 install -m644 "$owner/src/camera/provider/camcc-sm7675-crm-$name.h" "$kernel/drivers/clk/qcom/provider/"
done
(cd "$kernel";sha256sum -c --strict --quiet "$result/retained.sha256";sha256sum drivers/clk/qcom/camcc-sm7675.c drivers/clk/qcom/provider/{camcc-sm7675-crm-rom,camcc-sm7675-crm-owner}.h) > "$result/source.sha256"

#!/usr/bin/bash
# COPR-only source composition; the firmware guard and probe remain unchanged.
set -Eeuo pipefail
[[ $# == 3 ]]
kernel=$(realpath "$1");owner=$(realpath "$2");result=$(realpath -m "$3")
target=$kernel/drivers/clk/qcom/camcc-sm7675.c
[[ -f $target && ! -L $target && ! -e $result && ! -L $result ]]
printf '%s  %s\n' a12590ce926d3a08a2b651cf49733633d0a0dc270c6f471e7a541f14864f89a7 "$target" | sha256sum -c --strict --quiet -
for name in rom owner startup floor;do
 [[ ! -e $kernel/drivers/clk/qcom/provider/camcc-sm7675-crm-$name.h ]]
done
for name in core lut passive pm transport;do
 cmp "$owner/src/camera/provider/camcc-sm7675-crm-$name.h" "$kernel/drivers/clk/qcom/provider/camcc-sm7675-crm-$name.h"
done
mkdir "$result"
cp "$target" "$result/parent-camcc-sm7675.c"
(cd "$kernel";sha256sum drivers/clk/qcom/provider/{camcc-sm7675-crm-guard,camcc-sm7675-registration,camcc-sm7675-crmc-resource,camcc-sm7675-crm-transport,camcc-sm7675-crm-pm}.h) > "$result/retained.sha256"
node - "$target" <<'JS'
const fs=require('fs'),p=process.argv[2],s=fs.readFileSync(p,'utf8');
const anchor='#include "provider/camcc-sm7675-crm-passive.h"';
if(s.split(anchor).length!==2||s.includes('camcc-sm7675-crm-rom.h')||s.includes('camcc-sm7675-crm-owner.h'))throw Error('Exact prepared camera provider required');
fs.writeFileSync(p,s.replace(anchor,anchor+'\n#include "provider/camcc-sm7675-crm-rom.h"\n#include "provider/camcc-sm7675-crm-owner.h"'));
JS
awk '
 $0=="#include \"provider/camcc-sm7675-crm-rom.h\""{rom++;next}
 $0=="#include \"provider/camcc-sm7675-crm-owner.h\""{owner++;next}
 {print}
 END{if(rom!=1||owner!=1)exit 1}
' "$target" | cmp - "$result/parent-camcc-sm7675.c"
for name in rom owner startup floor;do
 install -m644 "$owner/src/camera/provider/camcc-sm7675-crm-$name.h" "$kernel/drivers/clk/qcom/provider/"
done
(cd "$kernel";sha256sum -c --strict --quiet "$result/retained.sha256";sha256sum drivers/clk/qcom/camcc-sm7675.c drivers/clk/qcom/provider/{camcc-sm7675-crm-rom,camcc-sm7675-crm-owner,camcc-sm7675-crm-startup,camcc-sm7675-crm-floor}.h) > "$result/source.sha256"

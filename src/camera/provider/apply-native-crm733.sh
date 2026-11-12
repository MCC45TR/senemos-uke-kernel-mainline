#!/usr/bin/bash
# COPR only: adopt the complete qualified backend without dropping s2idle.
set -Eeuo pipefail
[[ ! -e /etc/senemos/kernel-update.conf && $# == 2 ]]
kernel=$(realpath "$1")
profile=$(realpath "$2")
manifest=$profile/manifests/camera-crmc-owner-20261113.json
while IFS=$'\t' read -r path before;do
 if [[ $before == absent ]];then [[ ! -e $kernel/$path && ! -L $kernel/$path ]];
 else printf '%s  %s\n' "$before" "$kernel/$path" | sha256sum -c --strict --quiet -;fi
done < <(jq -er '.runtime_units[]|[.path,(.before_sha256//"absent")]|@tsv' "$manifest")
cmp "$profile/src/camera/sleep/camcc-sm7675-sleep.h" "$kernel/drivers/clk/qcom/provider/camcc-sm7675-sleep.h"
while IFS=$'\t' read -r path source;do
 install -Dm644 "$profile/$source" "$kernel/$path"
done < <(jq -er '.runtime_units[]|[.path,.source_path]|@tsv' "$manifest")
node - "$kernel/drivers/clk/qcom" <<'JS'
const fs=require('fs'),root=process.argv[2];
function edit(path,changes){const p=root+'/'+path;let s=fs.readFileSync(p,'utf8');for(const [before,after]of changes){if(s.split(before).length!==2)throw Error('Exact sleep projection drift: '+path);s=s.replace(before,after);}fs.writeFileSync(p,s);}
edit('camcc-sm7675.c',[
 ['#include "provider/camcc-sm7675-registration.h"','#include "provider/camcc-sm7675-registration.h"\n#include "provider/camcc-sm7675-sleep.h"'],
 ['.pm = &cam_cc_power_pm_ops,','.pm = &cam_cc_native_pm_ops,']
]);
edit('provider/camcc-sm7675-owner.h',[
 ['static bool cam_cc_owner_busy(void)','static const struct dev_pm_ops cam_cc_native_pm_ops;\n\nstatic bool cam_cc_owner_busy(void)'],
 ['dev->driver->pm != &cam_cc_power_pm_ops)','(dev->driver->pm != &cam_cc_power_pm_ops &&\n\t     dev->driver->pm != &cam_cc_native_pm_ops))']
]);
JS
while IFS=$'\t' read -r path after;do
 printf '%s  %s\n' "$after" "$kernel/$path" | sha256sum -c --strict --quiet -
done < <(jq -er '.runtime_units[]|[.path,.after_sha256]|@tsv' "$manifest")
printf 'Complete native CAMCC backend/resources installed; exact guard and s2idle retained; no transport activation\n'

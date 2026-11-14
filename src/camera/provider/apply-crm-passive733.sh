#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# COPR only: retain the cumulative full26 provider and system-sleep projection.
set -Eeuo pipefail
[[ $# == 2 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1")
project=$(realpath "$2")
manifest=$project/manifests/camera-crm-passive-20261114.json
while IFS=$'\t' read -r path before;do
 if [[ $before == absent ]];then [[ ! -e $kernel/$path && ! -L $kernel/$path ]];
 else printf '%s  %s\n' "$before" "$kernel/$path" | sha256sum -c --strict --quiet -;fi
done < <(jq -er '.runtime_units[]|[.path,.before_sha256]|@tsv' "$manifest")
while IFS=$'\t' read -r path source;do
 install -Dm644 "$project/$source" "$kernel/$path"
done < <(jq -er '.runtime_units[]|[.path,.source_path]|@tsv' "$manifest")
node - "$kernel/drivers/clk/qcom/camcc-sm7675.c" <<'JS'
const fs=require('fs'),p=process.argv[2];let s=fs.readFileSync(p,'utf8');
for(const [a,b] of [
 ['#include "provider/camcc-sm7675-registration.h"','#include "provider/camcc-sm7675-registration.h"\n#include "provider/camcc-sm7675-sleep.h"'],
 ['.pm = &cam_cc_power_pm_ops,','.pm = &cam_cc_native_pm_ops,']
]) {if(s.split(a).length!==2)throw Error('Exact retained s2idle projection');s=s.replace(a,b);}
fs.writeFileSync(p,s);
JS
while IFS=$'\t' read -r path after;do
 printf '%s  %s\n' "$after" "$kernel/$path" | sha256sum -c --strict --quiet -
done < <(jq -er '.runtime_units[]|[.path,.after_sha256]|@tsv' "$manifest")
printf 'Reviewed full26 passive CRM delta applied; original firmware guard, owner and system-sleep paths retained\n'

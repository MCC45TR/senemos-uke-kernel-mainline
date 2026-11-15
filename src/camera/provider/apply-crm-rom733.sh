#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# COPR only: append the declared ROM resolver to exact cumulative28 sources.
set -Eeuo pipefail
[[ $# == 2 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1"); project=$(realpath "$2")
manifest=$project/manifests/camera-crm-rom-20261115.json
verify_retained() {
 while IFS=$'\t' read -r path hash; do
  printf '%s  %s\n' "$hash" "$kernel/$path" | sha256sum -c --strict --quiet -
 done < <(jq -er '.retained_camera_units[]|[.path,.sha256]|@tsv' "$manifest")
}
verify_retained
while IFS=$'\t' read -r path before; do
 if [[ $before == absent ]]; then [[ ! -e $kernel/$path && ! -L $kernel/$path ]];
 else printf '%s  %s\n' "$before" "$kernel/$path" | sha256sum -c --strict --quiet -; fi
done < <(jq -er '.runtime_units[]|[.path,.before_sha256]|@tsv' "$manifest")
install -Dm644 "$project/src/camera/provider/camcc-sm7675-crm-rom.h" \
 "$kernel/drivers/clk/qcom/provider/camcc-sm7675-crm-rom.h"
node - "$kernel/drivers/clk/qcom/camcc-sm7675.c" <<'JS'
const fs=require('fs'),p=process.argv[2],s=fs.readFileSync(p,'utf8');
const before='#include "provider/camcc-sm7675-crm-passive.h"';
if(s.split(before).length!==2||s.includes('camcc-sm7675-crm-rom.h'))throw Error('Exact cumulative28 ROM include preimage');
fs.writeFileSync(p,s.replace(before,before+'\n#include "provider/camcc-sm7675-crm-rom.h"'));
JS
while IFS=$'\t' read -r path after; do
 printf '%s  %s\n' "$after" "$kernel/$path" | sha256sum -c --strict --quiet -
done < <(jq -er '.runtime_units[]|[.path,.after_sha256]|@tsv' "$manifest")
verify_retained
printf 'Cumulative28 ROM-only delta sealed; provider admission and IRQ ownership unchanged\n'

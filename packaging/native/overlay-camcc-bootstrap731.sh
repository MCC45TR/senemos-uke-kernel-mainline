#!/usr/bin/env bash
# COPR/source only: exact qualified order/models, unchanged admission and power.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
profile=$(realpath "${1:?Native profile}")
boot=$(realpath "${2:?Boot recipe}")
manifest=manifests/camcc-bootstrap-layer-20261105.json
(cd "$profile"; sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
jq -e '.package_family=="senemos-uke-linux-kernel-mainline-unstable" and
 .source_commit=="bba194e74ab97dcb848887fa62430c20f9d755d9" and
 .camcc_probe_observation_abi==1 and .ssc_observation_abi==1 and
 .queued_kernel_layer==1 and .o82_memory_layer==1 and .ssc_transaction_layer==1 and
 (.front_geni_dt_activation|not) and (.front_eeprom_dt_activation|not) and
 (.camera_sensor_dt_activation|not) and (.camera_capture_graph_activation|not) and
 (.physical_acceptance|not)' "$profile/source-composition.json" >/dev/null
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
mapfile -t paths < <(jq -r '.imports[].path' "$owner/$manifest"; printf '%s\n' "$manifest")
while IFS=$'\t' read -r path digest; do
    [[ $path =~ ^(src|tests|docs|packaging|manifests)/[a-zA-Z0-9_.,/-]+$ && $path != *..* ]]
    printf '%s  %s\n' "$digest" "$owner/$path" | sha256sum -c --strict --quiet -
done < <(jq -r '.imports[]|[.path,.sha256]|@tsv' "$owner/$manifest")
if [[ $(jq -r '.camcc_bootstrap_layer // 0' "$profile/source-composition.json") == 1 ]]; then
    for path in "${paths[@]}"; do
        for tree in "$profile" "$boot"; do
            [[ -f $tree/$path && ! -L $tree/$path ]]
            cmp "$owner/$path" "$tree/$path"
        done
        digest=$(sha256sum "$owner/$path"); digest=${digest%% *}
        jq -e --arg path "$path" --arg sha "$digest" \
          'any(.source_assets[];.path==$path and .sha256==$sha)' "$boot/lock.json" >/dev/null
    done
    jq -e '.camcc_bootstrap_check==11261918 and
      .camcc_critical_cbcr_order==["0x13318","0x13314","0x132ec","0x13308"] and
      .camcc_bootstrap_physical_acceptance==false' "$profile/source-composition.json" >/dev/null
    printf 'CAMCC bootstrap source layer already exact; no mutation\n'
    exit 0
fi
jq -e '(has("camcc_bootstrap_layer")|not) and (has("camcc_bootstrap_check")|not)' \
 "$profile/source-composition.json" >/dev/null
# Finish all old-byte/absence admission before changing either tree.
while IFS=$'\t' read -r path before required; do
    for role in profile boot; do
        tree=$profile
        [[ $role != boot ]] || tree=$boot
        if [[ -e $tree/$path || -L $tree/$path ]]; then
            [[ -f $tree/$path && ! -L $tree/$path && $before != null ]]
            printf '%s  %s\n' "$before" "$tree/$path" | sha256sum -c --strict --quiet -
        elif [[ $role == profile && $required == true ]]; then
            printf 'Required CAMCC parent source absent: %s\n' "$path" >&2
            exit 1
        fi
    done
done < <(jq -r '.imports[]|[.path,(.before_sha256 // "null"),(.required_profile|tostring)]|@tsv' "$owner/$manifest")
test ! -e "$profile/$manifest" && test ! -e "$boot/$manifest"
history=source-composition-before-camcc-bootstrap.json
test ! -e "$profile/$history"
cp "$profile/SHA256SUMS" "$stage/profile-before.sha256"
cp "$profile/source-composition.json" "$stage/composition-before.json"
cp "$boot/lock.json" "$stage/lock-before.json"
(cd "$boot"; find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$stage/boot-before.sha256"
for path in "${paths[@]}"; do
    for tree in "$profile" "$boot"; do install -Dm644 "$owner/$path" "$tree/$path"; done
    digest=$(sha256sum "$owner/$path"); digest=${digest%% *}
    jq --arg path "$path" --arg sha "$digest" '
      if any(.source_assets[];.path==$path) then
        (.source_assets[]|select(.path==$path)|.sha256)=$sha
      else .source_assets += [{path:$path,sha256:$sha}] end' "$boot/lock.json" > "$stage/lock-next.json"
    install -m644 "$stage/lock-next.json" "$boot/lock.json"
done
cp "$stage/composition-before.json" "$profile/$history"
jq --arg history "$history" --slurpfile layer "$owner/$manifest" '. + {
 source_mode:(.source_mode+"+oem-camcc-transport-bootstrap"),
 overlays:(reduce ((.overlays // [])+($layer[0].imports|map(.path)))[] as $p
   ([];if index($p)==null then .+[$p] else . end)),
 camcc_bootstrap_layer:1,camcc_bootstrap_check:11261918,
 camcc_bootstrap_reference_source:"4024165658f2fc852741bf3905ceb6717fbb6ad4",
 camcc_critical_cbcr_order:["0x13318","0x13314","0x132ec","0x13308"],
 camcc_bootstrap_parent_composition:$history,
 camcc_bootstrap_physical_acceptance:false}' "$stage/composition-before.json" > "$profile/source-composition.json"
jq -e --slurpfile before "$stage/composition-before.json" '
 del(.source_mode,.overlays,.camcc_bootstrap_layer,.camcc_bootstrap_check,
 .camcc_bootstrap_reference_source,.camcc_critical_cbcr_order,
 .camcc_bootstrap_parent_composition,.camcc_bootstrap_physical_acceptance)
 == ($before[0]|del(.source_mode,.overlays))' "$profile/source-composition.json" >/dev/null
for role in profile boot; do
    tree=$profile; receipt=$stage/profile-before.sha256
    [[ $role != boot ]] || { tree=$boot; receipt=$stage/boot-before.sha256; }
    while read -r digest path; do
        path=${path#./}
        if [[ $role == profile && $path == source-composition.json ]]; then continue; fi
        if ! printf '%s\n' "${paths[@]}" | grep -Fxq "$path"; then
            printf '%s  %s\n' "$digest" "$tree/$path" | sha256sum -c --strict --quiet -
        fi
    done < "$receipt"
done
cmp <(jq -cS 'del(.source_assets)' "$stage/lock-before.json") <(jq -cS 'del(.source_assets)' "$boot/lock.json")
jq -e --slurpfile before "$stage/lock-before.json" '
 [.source_assets[].path] as $paths |
 all($before[0].source_assets[];.path as $p|$paths|index($p)!=null) and
 ((.source_assets|map(.path)|length)==(.source_assets|map(.path)|unique|length))' "$boot/lock.json" >/dev/null
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
printf 'Exact CAMCC bootstrap layer applied; unrelated source/config/firmware/admission and boot assets retained\n'

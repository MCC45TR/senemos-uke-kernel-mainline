#!/usr/bin/env bash
# COPR only: add the qualified touch layer without resetting cumulative sources.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 2 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
profile=$(realpath "$1")
boot=$(realpath "$2")
manifest=manifests/qualified-touch-layer-20261105.json
(cd "$owner"; jq -r '.imports[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
[[ -f $profile/SHA256SUMS && -f $profile/source-composition.json && -f $boot/lock.json ]]
(cd "$profile"; sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
jq -e '.package_family=="senemos-uke-linux-kernel-mainline-unstable" and
 .camcc_probe_observation_abi==1 and .ssc_observation_abi==1 and
 .nfc_wakeup_owner=="i2c-core"' "$profile/source-composition.json" >/dev/null
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
verify_outputs()
{
    local tree=$1 digest relative
    while IFS=$'\t' read -r relative digest; do
        if [[ ! -e $tree/$relative ]]; then
            [[ $tree == "$boot" ]] || exit 1
            continue
        fi
        printf '%s  %s\n' "$digest" "$tree/$relative" | sha256sum -c --strict --quiet -
    done < <(jq -r '.preimages[]|[.path,.after_sha256]|@tsv' "$owner/$manifest")
}
if [[ $(jq -r '.qualified_touch_layer // 0' "$profile/source-composition.json") == 1 ]]; then
    verify_outputs "$profile"
    verify_outputs "$boot"
    cmp "$owner/$manifest" "$profile/$manifest"
    for tree in "$profile" "$boot"; do
        while IFS=$'\t' read -r relative digest; do
            if [[ $relative == src/input/nt36532-uke-protocol.c && ! -f $tree/$relative ]]; then
                [[ $tree == "$boot" ]] || exit 1
                continue
            fi
            printf '%s  %s\n' "$digest" "$tree/$relative" | sha256sum -c --strict --quiet -
        done < <(jq -r '.imports[]|select(.embedded)|[.path,.sha256]|@tsv' "$owner/$manifest")
    done
    printf 'Qualified touch layer already present; cumulative sources left unchanged\n'
    exit 0
fi
history=source-composition-before-qualified-touch.json
test ! -e "$profile/$history"
cp "$profile/source-composition.json" "$stage/old-composition.json"
cp "$profile/SHA256SUMS" "$stage/profile-before.sha256"
cp "$boot/lock.json" "$stage/old-lock.json"
(cd "$boot"; find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$stage/boot-before.sha256"
jq -r '.new_paths[]' "$owner/$manifest" > "$stage/new-assets"
for role in profile boot; do
    tree=$profile
    [[ $role != boot ]] || tree=$boot
    : > "$stage/$role-overlays"
    while IFS=$'\t' read -r relative digest; do
        [[ $relative =~ ^(src|tests)/[a-zA-Z0-9_,./-]+$ && $relative != *..* ]]
        if [[ ! -e $tree/$relative ]]; then
            [[ $role == boot ]] || exit 1
            continue
        fi
        printf '%s  %s\n' "$digest" "$tree/$relative" | sha256sum -c --strict --quiet -
        printf '%s\n' "$relative" >> "$stage/$role-overlays"
    done < <(jq -r '.preimages[]|[.path,.sha256]|@tsv' "$owner/$manifest")
    if [[ -f $tree/src/display/panel-xiaomi-o82.c ]]; then
        patch --batch --fuzz=0 -d "$tree" -p1 --dry-run \
            -i "$owner/patches/display/0074-o82-touch-retain-before-off.patch"
        patch --batch --fuzz=0 -d "$tree" -p1 \
            -i "$owner/patches/display/0074-o82-touch-retain-before-off.patch"
    fi
    if [[ -f $tree/tests/o82-panel-contract.sh ]]; then
        patch --batch --fuzz=0 -d "$tree" -p1 --dry-run \
            -i "$owner/patches/display/0074-o82-touch-retain-test.patch"
        patch --batch --fuzz=0 -d "$tree" -p1 \
            -i "$owner/patches/display/0074-o82-touch-retain-test.patch"
    fi
    if [[ -f $tree/src/input/nt36532-uke-protocol.c ]]; then
        install -m644 "$owner/src/input/nt36532-uke-protocol.c" "$tree/src/input/nt36532-uke-protocol.c"
    fi
    while read -r relative; do
        [[ $relative =~ ^(patches|tests|docs|manifests|packaging)/[a-zA-Z0-9_,./-]+$ && $relative != *..* ]]
        test ! -e "$tree/$relative"
        install -Dm644 "$owner/$relative" "$tree/$relative"
        printf '%s\n' "$relative" >> "$stage/$role-overlays"
    done < "$stage/new-assets"
    verify_outputs "$tree"
done
while read -r relative; do
    digest=$(sha256sum "$boot/$relative"); digest=${digest%% *}
    jq --arg path "$relative" --arg digest "$digest" \
        'if any(.source_assets[];.path==$path) then
          (.source_assets[]|select(.path==$path)|.sha256)=$digest
         else .source_assets += [{path:$path,sha256:$digest}] end' \
        "$boot/lock.json" > "$stage/lock.json"
    install -m644 "$stage/lock.json" "$boot/lock.json"
done < "$stage/boot-overlays"
for role in profile boot; do
    tree=$profile receipt=$stage/profile-before.sha256
    [[ $role != boot ]] || { tree=$boot; receipt=$stage/boot-before.sha256; }
    while read -r expected relative; do
        relative=${relative#./}
        if [[ $role == profile && $relative == source-composition.json ]]; then continue; fi
        if ! grep -Fxq "$relative" "$stage/$role-overlays"; then
            printf '%s  %s\n' "$expected" "$tree/$relative" | sha256sum -c --strict --quiet -
        fi
    done < "$receipt"
done
cmp <(jq -S 'del(.source_assets)' "$stage/old-lock.json") <(jq -S 'del(.source_assets)' "$boot/lock.json")
jq -e --slurpfile old "$stage/old-lock.json" --rawfile overlays "$stage/boot-overlays" '
 ($overlays|split("\n")|map(select(length>0))) as $allowed |
 [.source_assets[].path] as $paths |
 all($old[0].source_assets[]; .path as $p | $paths|index($p)!=null) and
 all(.source_assets[]; .path as $p |
   any($old[0].source_assets[];.path==$p) or ($allowed|index($p)!=null)) and
 ((.source_assets|map(.path)|length)==(.source_assets|map(.path)|unique|length))' \
    "$boot/lock.json" >/dev/null
cp "$stage/old-composition.json" "$profile/$history"
producer=$(git -C "$owner" rev-parse HEAD)
jq --arg history "$history" --arg producer "$producer" --rawfile overlays "$stage/profile-overlays" '
 . + {source_mode:(.source_mode+"-with-qualified-touch-layer"),
 touch_layer_parent_composition:$history,qualified_touch_layer:1,
 touch_layer_producer:$producer,touch_order_check:11260818,
 touch_order_source:"27471abc9cf4ed25011fb26383ccf35f8505aa43",
 touch_retention_before_panel_off:true,touch_ack_observation_cached_only:true,
 touch_layer_source_manifest:"manifests/qualified-touch-layer-20261105.json",
 overlays:((.overlays+($overlays|split("\n")|map(select(length>0))))|unique)}' \
    "$stage/old-composition.json" > "$profile/source-composition.json"
jq -e --slurpfile old "$stage/old-composition.json" '
 . as $current | all($old[0]|to_entries[];
  if .key=="source_mode" or .key=="overlays" then true else $current[.key]==.value end)' \
    "$profile/source-composition.json" >/dev/null
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
printf 'Qualified touch layer applied; all undeclared source/config/feature fields and boot assets retained\n'

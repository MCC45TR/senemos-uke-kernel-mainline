#!/usr/bin/env bash
# COPR source-worker checks on the actual cumulative profile/boot inputs.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
manifest=$owner/manifests/governor-options-layer-20261105.json
profile=$(realpath "${1:?Original cumulative native profile}")
boot=$(realpath "${2:?Original cumulative boot recipe}")
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
helper=$owner/packaging/native/overlay-governor-options731.sh
snapshot()
{
    (cd "$1"; find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum
     find . -printf '%y %m %p %l\n' | LC_ALL=C sort)
}
refresh()
{
    (cd "$1/profile"; find . -type f ! -name SHA256SUMS -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS)
}
new_case()
{
    case_root=$stage/$1
    mkdir "$case_root"
    cp -a "$profile" "$case_root/profile"
    cp -a "$boot" "$case_root/boot"
}
refuse()
{
    snapshot "$case_root" > "$stage/before"
    if bash "$helper" "$case_root/profile" "$case_root/boot" > "$stage/refused.log" 2>&1; then
        printf 'Unexpected governor-layer acceptance: %s\n' "$1" >&2; exit 1
    fi
    snapshot "$case_root" > "$stage/after"
    cmp "$stage/before" "$stage/after"
    printf 'PASS: refusal without mutation: %s\n' "$1"
}
new_case exact
snapshot "$case_root" > "$stage/exact-before"
bash "$helper" "$case_root/profile" "$case_root/boot"
# Every original file outside the declared config/receipt/composition delta is exact.
while read -r digest path; do
    path=${path#./}
    case "$path" in source-composition.json|native.config|configs/nfc-cdsp-reference.config|configs/nfc-waydroid-reference.config) continue;; esac
    if jq -e --arg path "$path" 'any(.assets[];.path==$path and .before_sha256!=null)' "$manifest" >/dev/null; then continue; fi
    printf '%s  %s\n' "$digest" "$case_root/profile/$path" | sha256sum -c --strict --quiet -
done < "$profile/SHA256SUMS"
while IFS= read -r -d '' path; do
    relative=${path#"$boot/"}
    case "$relative" in lock.json|packaging/native/native.config) continue;; esac
    if jq -e --arg path "$relative" 'any(.assets[];.path==$path and .before_sha256!=null)' "$manifest" >/dev/null; then continue; fi
    cmp "$path" "$case_root/boot/$relative"
done < <(find "$boot" -type f -print0)
snapshot "$case_root" > "$stage/applied"
bash "$helper" "$case_root/profile" "$case_root/boot"
snapshot "$case_root" > "$stage/repeated"
cmp "$stage/applied" "$stage/repeated"
applied=$case_root
printf '%s\n' 'PASS: exact real-input retention and byte-identical repeat'

new_case wrong_config
sed -i 's/CONFIG_CPU_FREQ_THERMAL=y/# CONFIG_CPU_FREQ_THERMAL is not set/' "$case_root/profile/native.config"
cp "$case_root/profile/native.config" "$case_root/boot/packaging/native/native.config"
digest=$(sha256sum "$case_root/profile/native.config"); digest=${digest%% *}
jq --arg sha "$digest" '(.source_assets[]|select(.path=="packaging/native/native.config").sha256)=$sha' \
    "$case_root/boot/lock.json" > "$stage/next.json"
cp "$stage/next.json" "$case_root/boot/lock.json"
refresh "$case_root"
refuse unrelated-config-change

new_case missing_reference
unlink "$case_root/profile/configs/nfc-waydroid-reference.config"
refresh "$case_root"
refuse missing-independent-reference

new_case missing_native_record
jq 'del(.source_assets[]|select(.path=="packaging/native/native.config"))' "$case_root/boot/lock.json" > "$stage/next.json"
cp "$stage/next.json" "$case_root/boot/lock.json"
refuse missing-boot-config-record

new_case duplicate_record
jq '.source_assets += [.source_assets[0]]' "$case_root/boot/lock.json" > "$stage/next.json"
cp "$stage/next.json" "$case_root/boot/lock.json"
refuse duplicate-boot-record

new_case history_link
ln -s missing "$case_root/profile/configs/governor-before-native.config"
refuse dangling-history-symlink

new_case history_occupied
printf 'occupied\n' > "$case_root/profile/source-composition-before-governor-options.json"
refresh "$case_root"
refuse occupied-composition-history

new_case ancestor_link
mv "$case_root/profile/tests" "$case_root/detached-tests"
ln -s ../detached-tests "$case_root/profile/tests"
refuse symlinked-asset-ancestor

new_case hardlink
ln "$case_root/profile/native.config" "$case_root/profile/linked.config"
refresh "$case_root"
refuse hardlinked-input

new_case unsafe_gate
jq '.speaker_protection_graph_admitted=true' "$case_root/profile/source-composition.json" > "$stage/next.json"
cp "$stage/next.json" "$case_root/profile/source-composition.json"
refresh "$case_root"
refuse opened-hardware-admission

new_case weakened_comparator
printf '#!/usr/bin/env bash\nexit 0\n' > "$case_root/profile/tests/nfc-cohort-config731.sh"
refresh "$case_root"
refuse weakened-full-config-comparator

for kind in repeat_record repeat_history repeat_metadata; do
    case_root=$stage/$kind
    cp -a "$applied" "$case_root"
    case "$kind" in
        repeat_record)
            jq 'del(.source_assets[]|select(.path=="docs/GOVERNOR-OPTIONS.md"))' "$case_root/boot/lock.json" > "$stage/next.json"
            cp "$stage/next.json" "$case_root/boot/lock.json";;
        repeat_history)
            printf '\n' >> "$case_root/profile/configs/governor-before-native.config"
            refresh "$case_root";;
        repeat_metadata)
            jq '.governor_options_component_check=0' "$case_root/profile/source-composition.json" > "$stage/next.json"
            cp "$stage/next.json" "$case_root/profile/source-composition.json"
            refresh "$case_root";;
    esac
    refuse "$kind"
done
printf '%s\n' 'PASS: governor layer real-input retention, exact repeat and 13 refusal cases'

#!/usr/bin/env bash
# COPR/source only: preserve the real cumulative config and its NFC comparators.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
[[ -d ${1:?Native profile} && ! -L $1 && -d ${2:?Boot recipe} && ! -L $2 ]]
profile=$(realpath "$1")
boot=$(realpath "$2")
[[ $profile != "$boot" && $profile/ != "$boot/"* && $boot/ != "$profile/"* ]]
manifest=manifests/governor-options-layer-20261105.json
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
safe_path() { [[ $1 =~ ^[a-zA-Z0-9_.,/-]+$ && $1 != /* && $1 != *..* && $1 != *//* ]]; }
admit_tree()
{
    local tree=$1 path
    while IFS= read -r -d '' path; do
        safe_path "${path#"$tree/"}"
        [[ ! -L $path && (-d $path || (-f $path && $(stat -c %h "$path") == 1)) ]]
    done < <(find "$tree" -mindepth 1 -print0)
}
admit_tree "$profile"
admit_tree "$boot"
jq -e '.schema_version==1 and (.config_inputs|length)==3 and
 (.config_inputs|map(.path)|unique|length)==3 and (.assets|length)>0 and
 (.assets|map(.path)|unique|length)==(.assets|length)' "$owner/$manifest" >/dev/null
while IFS=$'\t' read -r path digest; do
    safe_path "$path"
    [[ -f $owner/$path && ! -L $owner/$path && $digest =~ ^[a-f0-9]{64}$ ]]
    printf '%s  %s\n' "$digest" "$owner/$path" | sha256sum -c --strict --quiet -
done < <(jq -r '.assets[]|[.path,.sha256]|@tsv' "$owner/$manifest")
while IFS=$'\t' read -r path history before after; do
    safe_path "$path"; safe_path "$history"
    [[ $path != "$history" && $before =~ ^[a-f0-9]{64}$ && $after =~ ^[a-f0-9]{64}$ ]]
done < <(jq -r '.config_inputs[]|[.path,.history,.before_sha256,.after_sha256]|@tsv' "$owner/$manifest")
# Validate receipt paths before feeding them to sha256sum.
awk '$0!~/^[a-f0-9]{64}  [.]\/[a-zA-Z0-9_.,/-]+$/ {exit 1}' "$profile/SHA256SUMS"
while read -r digest path; do safe_path "${path#./}"; done < "$profile/SHA256SUMS"
(cd "$profile"; sha256sum -c --strict --quiet SHA256SUMS)
while IFS=$'\t' read -r path digest; do
    safe_path "$path"
    printf '%s  %s\n' "$digest" "$profile/$path" | sha256sum -c --strict --quiet -
done < <(jq -r '.preserved_profile_inputs[]|[.path,.sha256]|@tsv' "$owner/$manifest")
(cd "$profile"; find . -type f ! -name SHA256SUMS -print | LC_ALL=C sort) > "$stage/profile-files"
sed 's/^[a-f0-9]*  //' "$profile/SHA256SUMS" | LC_ALL=C sort > "$stage/profile-records"
cmp "$stage/profile-files" "$stage/profile-records"
jq -e '(.source_assets|type)=="array" and
 (.source_assets|length)==(.source_assets|map(.path)|unique|length)' "$boot/lock.json" >/dev/null
while IFS=$'\t' read -r path digest; do
    safe_path "$path"
    [[ -f $boot/$path && $digest =~ ^[a-f0-9]{64}$ ]]
    printf '%s  %s\n' "$digest" "$boot/$path" | sha256sum -c --strict --quiet -
done < <(jq -r '.source_assets[]|[.path,.sha256]|@tsv' "$boot/lock.json")
native=packaging/native/native.config
jq -e --arg path "$native" 'any(.source_assets[];.path==$path)' "$boot/lock.json" >/dev/null
cmp "$profile/native.config" "$boot/$native"
jq -e '.package_family=="senemos-uke-linux-kernel-mainline-unstable" and
 .kernel_abi_suffix=="-unstable" and .queued_kernel_layer==1 and .o82_memory_layer==1 and
 .ssc_transaction_layer==1 and .camcc_bootstrap_layer==1 and .cdsp_actlr_layer==1 and
 .automatic_seamless_staging_required and .preserve_local_rollback_preference and
 .package_rollback_default=="enforced" and .cdsp_auto_boot==false and
 .speaker_controls_present_without_graph_admission and .speaker_protection_graph_admitted==false and
 .speaker_gain_ceiling==223 and .o82_color_initial_preset=="" and .o82_color_dma_enabled==false and
 .native_hdr_advertised==false and .front_eeprom_read_only and
 (.front_geni_dt_activation|not) and (.front_eeprom_dt_activation|not) and
 (.camera_sensor_dt_activation|not) and (.camera_capture_graph_activation|not) and
 (.physical_acceptance|not)' "$profile/source-composition.json" >/dev/null
history=source-composition-before-governor-options.json
boot_history=packaging/native/native-before-governor-options.config
mapfile -t assets < <(jq -r '.assets[].path' "$owner/$manifest"; printf '%s\n' "$manifest")
mapfile -t asset_histories < <(jq -r '.assets[]|select(.history!=null)|.history' "$owner/$manifest")
derive_composition()
{
    jq --slurpfile layer "$owner/$manifest" '. + {
      source_mode:(.source_mode+"+optional-stock-governors"),
      native_config_sha256:$layer[0].config_inputs[0].after_sha256,
      governor_options_layer:1,governor_options_component_source:"b087ca83d20841dae9a742c56cb573fd3d964952",
      governor_options_component_check:11262127,
      governor_options_layer_manifest:"manifests/governor-options-layer-20261105.json",
      governor_options_parent_composition:"source-composition-before-governor-options.json",
      governor_options_reference_inputs:$layer[0].config_inputs,
      governor_options_defaults_unchanged:true,governor_options_physical_acceptance:false}' "$1"
}
if jq -e 'has("governor_options_layer")' "$profile/source-composition.json" >/dev/null; then
    # Repeat admission validates histories, all copied assets AND their lock records.
    [[ $(jq -r .native_config_sha256 "$profile/$history") == 739882b3a07fc6a701bae81ac6623a4b576871bd4289de3a095acabc20d49d34 ]]
    derive_composition "$profile/$history" > "$stage/expected.json"
    cmp <(jq -cS . "$stage/expected.json") <(jq -cS . "$profile/source-composition.json")
    while IFS=$'\t' read -r path prior before after; do
        printf '%s  %s\n' "$before" "$profile/$prior" "$after" "$profile/$path" | sha256sum -c --strict --quiet -
        bash "$owner/tests/governor-config-contract.sh" "$profile/$prior" "$profile/$path"
    done < <(jq -r '.config_inputs[]|[.path,.history,.before_sha256,.after_sha256]|@tsv' "$owner/$manifest")
    cmp "$profile/configs/governor-before-native.config" "$boot/$boot_history"
    while IFS=$'\t' read -r prior before; do
        printf '%s  %s\n' "$before" "$profile/$prior" "$before" "$boot/$prior" | sha256sum -c --strict --quiet -
    done < <(jq -r '.assets[]|select(.history!=null)|[.history,.before_sha256]|@tsv' "$owner/$manifest")
    for path in "${assets[@]}" "${asset_histories[@]}" "$boot_history"; do
        if printf '%s\n' "${assets[@]}" | grep -Fxq "$path"; then
            cmp "$owner/$path" "$profile/$path"
            cmp "$owner/$path" "$boot/$path"
        fi
        digest=$(sha256sum "$boot/$path"); digest=${digest%% *}
        jq -e --arg path "$path" --arg sha "$digest" \
            'any(.source_assets[];.path==$path and .sha256==$sha)' "$boot/lock.json" >/dev/null
    done
    printf '%s\n' 'Governor layer already exact; no mutation'
    exit 0
fi
[[ $(jq -r .native_config_sha256 "$profile/source-composition.json") == 739882b3a07fc6a701bae81ac6623a4b576871bd4289de3a095acabc20d49d34 ]]
# Plan the entire change on copies. Any admission failure leaves both inputs intact.
for path in "$history"; do [[ ! -e $profile/$path && ! -L $profile/$path ]]; done
[[ ! -e $boot/$boot_history && ! -L $boot/$boot_history ]]
[[ ! -e $profile/$manifest && ! -e $boot/$manifest ]]
while IFS=$'\t' read -r path before prior; do
    for tree in "$profile" "$boot"; do
        if [[ $before == null ]]; then
            [[ ! -e $tree/$path && ! -L $tree/$path ]]
        else
            safe_path "$prior"
            [[ $before =~ ^[a-f0-9]{64}$ && ! -e $tree/$prior && ! -L $tree/$prior ]]
            printf '%s  %s\n' "$before" "$tree/$path" | sha256sum -c --strict --quiet -
        fi
    done
done < <(jq -r '.assets[]|[.path,(.before_sha256 // "null"),(.history // "null")]|@tsv' "$owner/$manifest")
while IFS=$'\t' read -r path prior before after; do
    [[ ! -e $profile/$prior && ! -L $profile/$prior ]]
    printf '%s  %s\n' "$before" "$profile/$path" | sha256sum -c --strict --quiet -
done < <(jq -r '.config_inputs[]|[.path,.history,.before_sha256,.after_sha256]|@tsv' "$owner/$manifest")
cp -a "$profile" "$stage/profile"
cp -a "$boot" "$stage/boot"
new=$stage/profile
while IFS=$'\t' read -r path prior before after; do
    install -Dm644 "$profile/$path" "$new/$prior"
    sed -e 's/^CONFIG_CPU_FREQ_GOV_POWERSAVE=m$/CONFIG_CPU_FREQ_GOV_POWERSAVE=y/' \
        -e 's/^CONFIG_CPU_FREQ_GOV_CONSERVATIVE=m$/CONFIG_CPU_FREQ_GOV_CONSERVATIVE=y/' \
        -e 's/^# CONFIG_DEVFREQ_GOV_PERFORMANCE is not set$/CONFIG_DEVFREQ_GOV_PERFORMANCE=y/' \
        -e 's/^# CONFIG_DEVFREQ_GOV_POWERSAVE is not set$/CONFIG_DEVFREQ_GOV_POWERSAVE=y/' \
        "$profile/$path" > "$new/$path"
    bash "$owner/tests/governor-config-contract.sh" "$profile/$path" "$new/$path"
    printf '%s  %s\n' "$after" "$new/$path" | sha256sum -c --strict --quiet -
done < <(jq -r '.config_inputs[]|[.path,.history,.before_sha256,.after_sha256]|@tsv' "$owner/$manifest")
install -m644 "$new/native.config" "$stage/boot/$native"
install -Dm644 "$boot/$native" "$stage/boot/$boot_history"
while IFS=$'\t' read -r path prior; do
    install -Dm644 "$profile/$path" "$new/$prior"
    install -Dm644 "$boot/$path" "$stage/boot/$prior"
done < <(jq -r '.assets[]|select(.history!=null)|[.path,.history]|@tsv' "$owner/$manifest")
for path in "${assets[@]}"; do
    for tree in "$new" "$stage/boot"; do install -Dm644 "$owner/$path" "$tree/$path"; done
done
for path in "$native" "$boot_history" "${assets[@]}" "${asset_histories[@]}"; do
    digest=$(sha256sum "$stage/boot/$path"); digest=${digest%% *}
    jq --arg path "$path" --arg sha "$digest" '
      if any(.source_assets[];.path==$path) then
        (.source_assets[]|select(.path==$path)|.sha256)=$sha
      else .source_assets += [{path:$path,sha256:$sha}] end' "$stage/boot/lock.json" > "$stage/next.lock"
    install -m644 "$stage/next.lock" "$stage/boot/lock.json"
done
install -m644 "$profile/source-composition.json" "$new/$history"
derive_composition "$profile/source-composition.json" > "$new/source-composition.json"
(cd "$new"; find . -type f ! -name SHA256SUMS -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS)
# Every original boot asset record except the declared native config is exact.
jq -e --slurpfile prior "$boot/lock.json" --slurpfile layer "$owner/$manifest" '
 .source_assets as $after |
 all($prior[0].source_assets[]; . as $old |
   any($after[]; .path==$old.path and
     (if .path=="packaging/native/native.config" or (.path as $p|any($layer[0].assets[];.path==$p and .before_sha256!=null))
      then del(.sha256)==($old|del(.sha256)) else .==$old end)))' \
 "$stage/boot/lock.json" >/dev/null
cmp <(jq -cS 'del(.source_assets)' "$boot/lock.json") <(jq -cS 'del(.source_assets)' "$stage/boot/lock.json")
# Commit only planned files; unrelated source bytes and metadata are untouched.
mapfile -t config_paths < <(jq -r '.config_inputs[]|.path,.history' "$owner/$manifest")
for path in "${config_paths[@]}" "${assets[@]}" "${asset_histories[@]}" "$history" source-composition.json SHA256SUMS; do
    install -Dm644 "$new/$path" "$profile/$path"
done
for path in "$native" "$boot_history" "${assets[@]}" "${asset_histories[@]}" lock.json; do
    install -Dm644 "$stage/boot/$path" "$boot/$path"
done
printf '%s\n' 'Governor layer applied: both production configs and both NFC references extended; all other config bytes and composition fields retained'

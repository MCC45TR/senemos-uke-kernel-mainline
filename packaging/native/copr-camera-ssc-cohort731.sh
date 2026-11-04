#!/usr/bin/env bash
# COPR only: one cumulative kernel with SSC and cached CAMCC observations.
set -Eeuo pipefail
trap 'status=$?; printf "Combined kernel preparation failed at line %s (exit %s)\n" "$LINENO" "$status" >&2; exit "$status"' ERR
export LC_ALL=C
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 2 && $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "$1")
revision=$2
[[ $revision =~ ^[1-9][0-9]{4}$ && $revision -ge 12100 ]]
manifest=manifests/camera-probe-cohort-20261104.json
(cd "$owner"; jq -r '.imports[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
curl -q -fsSL --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11260755 | \
    jq -e '.state=="succeeded" and .source_package.name=="uke-camcc-probe-check" and
     .source_package.version=="1.0-2"' >/dev/null
curl -q -fsSL --max-time 45 https://copr.fedorainfracloud.org/api_3/build/source-build-config/11260755 | \
    jq -e '.source_dict.script|contains("commit=a1afff0dd7d42ea7c5a979519417d6f371c3ebae\n")' >/dev/null
# This exact imported producer proves all11003 bytes outside its six qualified
# SSC observations and ABI-specific audio identity are retained.
bash "$owner/packaging/native/copr-ssc-observation-cohort731.sh" "$output" "$revision"
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
mkdir "$stage/unpacked"
native_archive=senemos-native-profile-7.3.1.tar.xz
boot_archive=senemos-uke-boot-recipe.tar.xz
spec=$output/senemos-uke-linux-kernel-mainline-unstable.spec
find "$output" -maxdepth 1 -type f ! -name "${spec##*/}" \
    ! -name "$native_archive" ! -name "$boot_archive" ! -name boot-payload.json \
    -print0 | sort -z | xargs -0 sha256sum > "$stage/retained-sources.sha256"
for archive in "$native_archive" "$boot_archive"; do
    tar -tJf "$output/$archive" > "$stage/entries"
    awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/entries"
    tar -xJf "$output/$archive" -C "$stage/unpacked"
done
profile=$stage/unpacked/native-profile
boot=$stage/unpacked/boot-recipe
(cd "$profile"; sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
cmp "$boot/lock.json" "$output/boot-payload.json"
cmp "$profile/native.config" "$boot/packaging/native/native.config"
jq -e '.source_mode=="qualified11003-with-read-only-ssc-discovery-observations" and
 .ssc_observation_abi==1 and .qualified_ssc_observation_check==11260554 and
 .diagnostic_camera_stage==1 and .camcc_boot_fdt_activation and
 (.front_geni_dt_activation|not) and (.front_eeprom_dt_activation|not) and
 (.camera_sensor_dt_activation|not) and (.camera_capture_graph_activation|not) and
 (.calibration_consumed|not) and (.rear_focus|not) and (.physical_acceptance|not)' \
    "$profile/source-composition.json" >/dev/null
(cd "$profile"; jq -r '.imports_before[]|.sha256+"  "+.path' "$owner/$manifest" | sha256sum -c --strict --quiet -)
(cd "$profile"; jq -r '.unchanged[]|.sha256+"  "+.path' "$owner/$manifest" | sha256sum -c --strict --quiet -)
while read -r relative; do
    test ! -e "$profile/$relative"
done < <(jq -r '.new_paths[]' "$owner/$manifest")
cp "$profile/SHA256SUMS" "$stage/parent-profile.sha256"
cp "$boot/lock.json" "$stage/parent-boot-lock.json"
(cd "$boot"; find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$stage/parent-boot.sha256"
jq -r '.imports[].path' "$owner/$manifest" > "$stage/overlays"
for tree in "$profile" "$boot"; do
    while read -r relative; do
        [[ $relative =~ ^(src|tests)/[a-zA-Z0-9_,./-]+$ && $relative != *..* ]]
        install -Dm644 "$owner/$relative" "$tree/$relative"
    done < "$stage/overlays"
done
while read -r relative; do
    digest=$(sha256sum "$boot/$relative"); digest=${digest%% *}
    jq --arg path "$relative" --arg digest "$digest" \
        'if any(.source_assets[];.path==$path) then
          (.source_assets[]|select(.path==$path)|.sha256)=$digest
         else .source_assets += [{path:$path,sha256:$digest}] end' \
        "$boot/lock.json" > "$stage/lock.json"
    install -m644 "$stage/lock.json" "$boot/lock.json"
done < "$stage/overlays"
for role in profile boot; do
    tree=$profile receipt=$stage/parent-profile.sha256
    [[ $role != boot ]] || { tree=$boot; receipt=$stage/parent-boot.sha256; }
    while read -r expected relative; do
        relative=${relative#./}
        if [[ $role == profile && $relative == source-composition.json ]]; then continue; fi
        if ! grep -Fxq "$relative" "$stage/overlays"; then
            printf '%s  %s\n' "$expected" "$tree/$relative" | sha256sum -c --strict --quiet -
        fi
    done < "$receipt"
done
cmp <(jq -S 'del(.source_assets)' "$stage/parent-boot-lock.json") \
    <(jq -S 'del(.source_assets)' "$boot/lock.json")
jq -e --slurpfile old "$stage/parent-boot-lock.json" --rawfile overlays "$stage/overlays" '
 ($overlays|split("\n")|map(select(length>0))) as $allowed |
 [.source_assets[].path] as $paths |
 all($old[0].source_assets[]; .path as $p | $paths|index($p)!=null) and
 all(.source_assets[]; .path as $p |
   any($old[0].source_assets[];.path==$p) or ($allowed|index($p)!=null)) and
 ((.source_assets|map(.path)|length)==(.source_assets|map(.path)|unique|length))' \
    "$boot/lock.json" >/dev/null
history=source-composition-before-camcc-probe-observations.json
test ! -e "$profile/$history"
cp "$profile/source-composition.json" "$profile/$history"
install -Dm644 "$owner/$manifest" "$profile/$manifest"
jq --arg history "$history" --rawfile overlays "$stage/overlays" '
 . + {source_mode:"complete11003-with-ssc-and-camcc-probe-observations",
 camcc_probe_parent_composition:$history,
 overlays:((.overlays+($overlays|split("\n")|map(select(length>0))))|unique),
 camcc_probe_observation_abi:1,camcc_probe_observation_check:11260755,
 camcc_probe_observation_source:"a1afff0dd7d42ea7c5a979519417d6f371c3ebae",
 camcc_probe_observation_cached_only:true,camcc_probe_additional_mmio:false,
 camcc_probe_hardware_cause_qualified:false,
 shared_cumulative_kernel_queue:true,all_existing_features_retained:true,
 physical_acceptance:false}' "$profile/$history" > "$profile/source-composition.json"
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
install -m644 "$boot/lock.json" "$output/boot-payload.json"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
for tree in native-profile boot-recipe; do
    archive=$native_archive
    [[ $tree != boot-recipe ]] || archive=$boot_archive
    tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
        -cJf "$output/$archive" -C "$stage/unpacked" "$tree"
done
awk -v revision="$revision" '
 /^%check$/ {
  print
  print "cmp native-profile/src/camera/camcc-sm7675.c drivers/clk/qcom/camcc-sm7675.c"
  print "cmp native-profile/src/camera/provider/sysfs-driver-camcc-sm7675 Documentation/ABI/testing/sysfs-driver-camcc-sm7675"
  check++;next
 }
 /^%changelog$/ {
  print;print "* Wed Nov 04 2026 Uke contributors - 7.3.1-"revision
  print "- Preserve the complete11003 feature set and qualified SSC observations."
  print "- Record existing CAMCC probe phases and gate readbacks without extra MMIO."
  print "- Retain physical admission gates, seamless staging and local rollback choice."
  print "";next
 }
 {print}
 END {if(check!=1)exit 1}
' "$spec" > "$stage/next.spec"
install -m644 "$stage/next.spec" "$spec"
sha256sum -c --strict --quiet "$stage/retained-sources.sha256"
bash "$owner/tests/unstable-boot-family731-contract.sh" "$spec"
[[ $(rpmspec --target aarch64 --define 'dist %{nil}' -q --srpm --qf '%{VERSION}-%{RELEASE}' "$spec") == 7.3.1-$revision ]]
printf 'All11003 features plus qualified SSC/CAMCC observations composed; full kernel and hardware qualification pending\n'

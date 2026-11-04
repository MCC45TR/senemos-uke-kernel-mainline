#!/usr/bin/env bash
# COPR only: retain the exact 7300 diagnostic graph and add CDSP/pogo.
set -Eeuo pipefail
trap 'status=$?; printf "CDSP/pogo source preparation failed at line %s (exit %s)\n" "$LINENO" "$status" >&2; exit "$status"' ERR
export LC_ALL=C
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
revision=${CDSP_POGO_RPM_REVISION:-9003}
[[ $revision =~ ^[1-9][0-9]{3,4}$ ]]
release=7.3.1-$revision-unstable
bash "$owner/packaging/native/refuse-published-release.sh" senemos-uke-linux-kernel-mainline-unstable "7.3.1-$revision"
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
curl -fLsS --retry 2 --max-time 300 --proto '=https' --proto-redir '=https' \
    https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11259919/senemos-uke-linux-kernel-mainline-unstable-7.3.1-7300.src.rpm \
    -o "$stage/base.src.rpm"
printf '%s  %s\n' 4cc89bc2d5fb99a76a2d4db9b3ec983fd03ad88d4cdbf2c9c7e7bff77edebd03 "$stage/base.src.rpm" | sha256sum -c --strict
[[ $(rpm -qp --qf '%{SHA256HEADER}' "$stage/base.src.rpm") == 2538f7e4027ca8f926cf2ccd965715a6d080835443d2bafec41b96ccaab6c250 ]]
[[ $(rpm -qp --qf '%{PAYLOADSHA256}' "$stage/base.src.rpm") == 147edc8fae715ba6e8beb958fc6873df8ab60c7439f74831bb58154c56de0d49 ]]
rpmkeys --checksig --nosignature "$stage/base.src.rpm"
rpm2cpio "$stage/base.src.rpm" > "$stage/base.cpio"
cpio -t --quiet < "$stage/base.cpio" | awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}'
mkdir -p "$output" "$stage/unpacked"
(cd "$output"; cpio -idm --quiet --no-absolute-filenames < "$stage/base.cpio")
spec=$output/senemos-uke-linux-kernel-mainline-unstable.spec
find "$output" -maxdepth 1 -type f ! -name "${spec##*/}" ! -name senemos-native-profile-7.3.1.tar.xz \
    ! -name senemos-uke-boot-recipe.tar.xz ! -name boot-payload.json -print0 |
    sort -z | xargs -0 sha256sum > "$stage/retained-sources.sha256"
for archive in senemos-native-profile-7.3.1.tar.xz senemos-uke-boot-recipe.tar.xz; do
    tar -tJf "$output/$archive" | awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}'
    tar -xJf "$output/$archive" -C "$stage/unpacked"
done
profile=$stage/unpacked/native-profile
boot=$stage/unpacked/boot-recipe
(cd "$profile"; sha256sum --check --strict --quiet SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --quiet -)
cmp "$boot/lock.json" "$output/boot-payload.json"
jq -e '.source_commit=="bf1f6634bafc214219de1c48b3fc72a181485343" and
 .diagnostic_producer_commit=="00ebf622ca473b9b7a799b2f531b4871ddc70497" and
 .kernel_release=="7.3.1-7300-unstable" and .diagnostic_camera_stage==0 and
 .diagnostic_pstore_panic_layout and (.camera_dt_activation|not) and
 .rtc_backend=="pmic-read-only-counter" and .rtc_secure_offset_boot_activation==false and
 .rtc_secure_provider_qualified==false and .rtc_utc_calendar_qualified==false and
 (.camera_capture_graph_activation|not) and (.front_eeprom_dt_activation|not) and
 .nfc_atomic_memory_read and .ir_explicit_word_bits==16 and
 .ssc_adsp_supplier_bound_gate==1 and .ssc_payload_limit==16384' "$profile/source-composition.json" >/dev/null
(cd "$profile"; sha256sum --check --strict "$owner/manifests/cdsp-pogo7300-overlay-before.sha256")
cat > "$stage/assets" <<'FILES'
src/boot/uke-cdsp-pogo.h
patches/boot/0041-rproc-retain-failed-startup.patch
patches/boot/0060-cliffs-cdsp-start-ownership.patch
patches/boot/0061-uke-pogo-regulator-resources.patch
patches/boot/0062-uke-cdsp-context-admission.patch
tests/pas-stop-ownership-contract.sh
tests/rproc-start-stop-retention-contract.sh
tests/uke-rpmh-resource-contract.sh
tests/cdsp-start-ownership-contract.sh
tests/cdsp-smmu-admission-contract.sh
tests/cdsp-pogo-fdt-contract.sh
tests/nanosic-protocol-contract.sh
tests/nanosic-lifecycle-contract.sh
manifests/cdsp-tested-linux731.sha256
docs/CDSP-POGO-ACCEPTANCE.md
tests/cdsp-pogo-device-report.sh
tests/cdsp-pogo-config-contract.sh
tests/front-eeprom-fdt731-contract.sh
FILES
git -C "$owner" ls-files src/pogo src/cdsp >> "$stage/assets"
for tree in "$profile" "$boot"; do
    while read -r hash path; do
        [[ ! -e $tree/$path ]] || printf '%s  %s\n' "$hash" "$tree/$path" | sha256sum -c --strict
    done < "$owner/manifests/cdsp-pogo7300-overlay-before.sha256"
    (cd "$tree"
        while read -r path; do
            case $path in SHA256SUMS|source-commit|source-composition.json|lock.json|native.config|packaging/native/native.config|prepare.sh|src/boot/uke-abl.c|src/boot/prepare-abl-source.sh|src/audio/uke-audio-card.c) continue;; esac
            grep -Fxq "$path" "$stage/assets" || sha256sum "$path"
        done < <(find . -type f -printf '%P\n' | sort)
    ) > "$stage/retained-profile.sha256"
    includes=()
    if [[ $tree != "$profile" ]]; then
        includes=(--include=src/boot/prepare-abl-source.sh)
        [[ ! -f $tree/src/boot/uke-abl.c ]] || includes+=(--include=src/boot/uke-abl.c)
    fi
    git -C "$tree" apply --check "${includes[@]}" "$owner/packaging/native/cdsp-pogo-prepare.patch"
    git -C "$tree" apply "${includes[@]}" "$owner/packaging/native/cdsp-pogo-prepare.patch"
    while read -r path; do install -Dm644 "$owner/$path" "$tree/$path"; done < "$stage/assets"
    # Preserve the isolated family's short ALSA driver ABI for the new release.
    path=$tree/src/audio/uke-audio-card.c
    if [[ -f $path ]]; then
        [[ $(grep -Fo 'uke7.3.1-7300u' "$path" | wc -l) == 2 ]]
        sed -i "s/uke7[.]3[.]1-7300u/uke7.3.1-${revision}u/g" "$path"
    fi
    (cd "$tree"; sha256sum -c --quiet "$stage/retained-profile.sha256")
done
awk '
 FNR==NR {if(/^CONFIG_/) {split($0,a,"="); settings[a[1]]=$0} next}
 {
   key=$0; sub(/^# /,"",key); sub(/[= ].*$/,"",key)
   if(key in settings) {print settings[key];delete settings[key]} else print
 }
 END {for(key in settings)print settings[key]}
' "$owner/configs/cdsp-pogo.config" "$profile/native.config" > "$stage/native.config"
grep -Fx '# CONFIG_MODULE_FORCE_UNLOAD is not set' "$stage/native.config"
install -m644 "$stage/native.config" "$profile/native.config"
install -m644 "$stage/native.config" "$boot/packaging/native/native.config"
{
    cat "$stage/assets"
    printf '%s\n' src/boot/prepare-abl-source.sh packaging/native/native.config
    [[ ! -f $boot/src/boot/uke-abl.c ]] || printf '%s\n' src/boot/uke-abl.c
    [[ ! -f $boot/src/audio/uke-audio-card.c ]] || printf '%s\n' src/audio/uke-audio-card.c
} > "$stage/boot-assets"
while read -r path; do
    hash=$(sha256sum "$boot/$path");hash=${hash%% *}
    jq --arg path "$path" --arg hash "$hash" \
        '.source_assets |= (map(select(.path!=$path))+[{path:$path,sha256:$hash}])' \
        "$boot/lock.json" > "$stage/lock.json"
    install -m644 "$stage/lock.json" "$boot/lock.json"
done < "$stage/boot-assets"
install -m644 "$boot/lock.json" "$output/boot-payload.json"
cp "$profile/source-composition.json" "$profile/source-composition-before9003.json"
commit=$(git -C "$owner" rev-parse HEAD)
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
printf '%s\n' "$commit" > "$profile/source-commit"
config_sha=$(sha256sum "$profile/native.config");config_sha=${config_sha%% *}
jq --arg commit "$commit" --arg release "$release" --arg revision "$revision" --arg config_sha "$config_sha" '. + {
 source_commit:$commit,source_mode:"retained7300-cdsp-pogo-candidate",
 parent_copr_build:11259919,parent_srpm_sha256:"4cc89bc2d5fb99a76a2d4db9b3ec983fd03ad88d4cdbf2c9c7e7bff77edebd03",
 parent_composition:"source-composition-before9003.json",kernel_release:$release,rpm_revision:$revision,
 diagnostic_audio_driver:("uke7_3_1-"+$revision+"u"),
 cdsp_auto_boot:false,cdsp_context_sids:["0x0c01","0x0c02"],cdsp_secure_policy_override:false,
 cdsp_start_stop_retention:true,cdsp_permanent_platform_instance:true,
 pogo_mcu_firmware_distributed:false,pogo_report_format:"21-byte shared-protocol candidate",
 pogo_auth_provider_included:false,physical_acceptance:false,device_installation:false,
 native_config_sha256:$config_sha,
 cdsp_pogo_parent_effective_config_sha256:"7f1e3f7a5be62396b2b36534780aeb561dfbf7e0a10698677b860cbc91efbd38",
 cdsp_pogo_config_delta:["CONFIG_HID_NANOSIC_UKE=m"]
}' "$profile/source-composition-before9003.json" > "$profile/source-composition.json"
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --quiet -)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
    -cJf "$output/senemos-native-profile-7.3.1.tar.xz" -C "$stage/unpacked" native-profile
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
    -cJf "$output/senemos-uke-boot-recipe.tar.xz" -C "$stage/unpacked" boot-recipe
day=$(date -u --date="@$epoch" '+%a %b %d %Y')
[[ $(grep -Ec 'uke-rpmh-resource-contract.sh.* native$' "$spec") == 1 ]]
awk -v revision="$revision" -v day="$day" '
 /^%global senemos_build_release 7300$/ {$0="%global senemos_build_release " revision;releases++}
 /^Name:[[:space:]]/ {print;print "Provides: uke-kernel(cdsp-pogo-candidate-v1) = 1";next}
 /uke-rpmh-resource-contract.sh.* native$/ {sub(/ native$/," native-pogo");regulator++}
 /^printf / && /7f1e3f7a5be62396b2b36534780aeb561dfbf7e0a10698677b860cbc91efbd38/ && /sha256sum/ {
   print "bash native-profile/tests/cdsp-pogo-config-contract.sh %{_uke_out}/.config";configuration++;next
 }
 /^%check$/ {
   print
   print "test -s %{_uke_out}/drivers/hid/hid-nanosic-uke.o"
   print "test -s %{_uke_out}/drivers/remoteproc/qcom_q6v5_pas.o"
   print "test -n \"$(find %{buildroot}/usr/lib/modules/%{krel} -type f -name '\''hid-nanosic-uke.ko*'\'' -print -quit)\""
   next
 }
 /^%changelog$/ {
   print
   print "* " day " MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-" revision
   print "- Retain the isolated 7300 graph and add guarded CDSP and pogo transport."
   print "- Keep firmware provisioning and physical acceptance separate."
   print "";next
 }
 {print}
 END {if(releases!=1 || configuration!=1 || regulator!=1)exit 1}
' "$spec" > "$stage/next.spec"
install -m644 "$stage/next.spec" "$spec"
sha256sum -c --quiet "$stage/retained-sources.sha256"
bash "$profile/tests/unstable-boot-family731-contract.sh" "$spec"
[[ $(rpmspec --target aarch64 --define 'dist %{nil}' -q --srpm --qf '%{VERSION}-%{RELEASE}' "$spec") == "7.3.1-$revision" ]]
rpmbuild -bs --define "_sourcedir $output" --define "_srcrpmdir $output" "$spec"

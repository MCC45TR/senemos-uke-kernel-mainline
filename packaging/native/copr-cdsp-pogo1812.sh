#!/usr/bin/env bash
# COPR-only: retain production 1600, add the qualified source candidates.
set -Eeuo pipefail
export LC_ALL=C
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
bash "$owner/packaging/native/refuse-published-release.sh" senemos-uke-linux-kernel-mainline 7.3.1-1812
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
curl -fLsS --retry 2 --max-time 300 --proto '=https' --proto-redir '=https' \
    https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11251559/senemos-uke-linux-kernel-mainline-7.3.1-1600.src.rpm \
    -o "$stage/base.src.rpm"
[[ $(rpm -qp --qf '%{SHA256HEADER}' "$stage/base.src.rpm") == f71eea4d521b2937c08d81886c9338e0908834491ee9bb35238a2b72171f58e5 ]]
[[ $(rpm -qp --qf '%{PAYLOADSHA256}' "$stage/base.src.rpm") == b4f6340ccd8cd72fcfba6d462b869621eaf62793b28abc083bad53072838d5e7 ]]
rpmkeys --checksig --nosignature "$stage/base.src.rpm"
parent=$(sha256sum "$stage/base.src.rpm");parent=${parent%% *}
rpm2cpio "$stage/base.src.rpm" > "$stage/base.cpio"
cpio -t --quiet < "$stage/base.cpio" | awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}'
mkdir -p "$output" "$stage/unpacked"
(cd "$output"; cpio -idm --quiet --no-absolute-filenames < "$stage/base.cpio")
spec=$output/senemos-uke-linux-kernel-mainline.spec
find "$output" -maxdepth 1 -type f ! -name "${spec##*/}" ! -name senemos-native-profile-7.3.1.tar.xz \
    ! -name senemos-uke-boot-recipe.tar.xz ! -name boot-payload.json -print0 |
    sort -z | xargs -0 sha256sum > "$stage/retained-sources.sha256"
for archive in senemos-native-profile-7.3.1.tar.xz senemos-uke-boot-recipe.tar.xz; do
    tar -tJf "$output/$archive" | awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}'
    tar -xJf "$output/$archive" -C "$stage/unpacked"
done
profile=$stage/unpacked/native-profile
boot=$stage/unpacked/boot-recipe
[[ $(cat "$profile/source-commit") == 31313e89f719b935bcd1301d48d807bd1dc27163 ]]
(cd "$profile"; sha256sum --check --strict --quiet SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --quiet -)
cat > "$stage/assets" <<'FILES'
src/boot/uke-cdsp-pogo.h
src/boot/sm7675-uke-usb2.dtso
src/nfc/fm19511-uke.c
src/nfc/fm19511-uapi.h
src/nfc/fm,fm19511.yaml
src/nfc/prepare-source.sh
src/nfc/README.md
src/infrared/ir-spi-uke.c
patches/boot/0041-rproc-retain-failed-startup.patch
patches/boot/0060-cliffs-cdsp-start-ownership.patch
patches/boot/0061-uke-pogo-regulator-resources.patch
patches/boot/0062-uke-cdsp-context-admission.patch
tests/fm19511-contract.sh
tests/fm19511-pm-contract.sh
tests/ir-spi-contract.sh
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
FILES
git -C "$owner" ls-files src/pogo src/cdsp >> "$stage/assets"
for tree in "$profile" "$boot"; do
    # Refuse replacing a changed USB graph with a source snapshot.
    if [[ -f $tree/src/boot/sm7675-uke-usb2.dtso ]]; then
        hash=$(sha256sum "$tree/src/boot/sm7675-uke-usb2.dtso");hash=${hash%% *}
        case $hash in
            a8a242d84ae84a746661a8e2bd62d087e6e53c34c98e22238d7260ac03ad3726|b12e14b5dde82fc237f3b2e626d34c0ae0c85c3d3c14f4ff75cf9fa6cd8f7573) ;;
            *) echo 'Retained USB graph differs; review before replacement' >&2;exit 1;;
        esac
    fi
    (cd "$tree"
        while read -r file; do
            case $file in SHA256SUMS|source-commit|source-composition.json|lock.json|native.config|packaging/native/native.config|prepare.sh|src/boot/uke-abl.c|src/boot/prepare-abl-source.sh) continue;; esac
            grep -Fxq "$file" "$stage/assets" || sha256sum "$file"
        done < <(find . -type f -printf '%P\n' | sort)
    ) > "$stage/retained-profile.sha256"
    if [[ $tree == "$profile" ]]; then
        git -C "$tree" apply --check "$owner/packaging/native/cdsp-pogo-prepare.patch"
        git -C "$tree" apply "$owner/packaging/native/cdsp-pogo-prepare.patch"
    else
        includes=(--include=src/boot/prepare-abl-source.sh)
        [[ ! -f $tree/src/boot/uke-abl.c ]] || includes+=(--include=src/boot/uke-abl.c)
        git -C "$tree" apply --check "${includes[@]}" "$owner/packaging/native/cdsp-pogo-prepare.patch"
        git -C "$tree" apply "${includes[@]}" "$owner/packaging/native/cdsp-pogo-prepare.patch"
    fi
    while read -r file; do install -Dm644 "$owner/$file" "$tree/$file"; done < "$stage/assets"
    (cd "$tree"; sha256sum -c --quiet "$stage/retained-profile.sha256")
done
cat "$owner/configs/nfc-ir.config" "$owner/configs/cdsp-pogo.config" > "$stage/feature.config"
awk '
 FNR==NR {if(/^CONFIG_/) {split($0,a,"="); settings[a[1]]=$0} next}
 {
   key=$0; sub(/^# /,"",key); sub(/[= ].*$/,"",key)
   if(key in settings) {print settings[key];delete settings[key]} else print
 }
 END {for(key in settings)print settings[key]}
' "$stage/feature.config" "$profile/native.config" > "$stage/native.config"
install -m644 "$stage/native.config" "$profile/native.config"
install -m644 "$stage/native.config" "$boot/packaging/native/native.config"
{
    cat "$stage/assets"
    printf '%s\n' src/boot/prepare-abl-source.sh packaging/native/native.config
    [[ ! -f $boot/src/boot/uke-abl.c ]] || printf '%s\n' src/boot/uke-abl.c
} > "$stage/boot-assets"
while read -r file; do
    hash=$(sha256sum "$boot/$file");hash=${hash%% *}
    jq --arg file "$file" --arg hash "$hash" \
        '.source_assets |= (map(select(.path!=$file))+[{path:$file,sha256:$hash}])' \
        "$boot/lock.json" > "$stage/lock.json"
    install -m644 "$stage/lock.json" "$boot/lock.json"
done < "$stage/boot-assets"
install -m644 "$boot/lock.json" "$output/boot-payload.json"
cp "$profile/source-composition.json" "$profile/source-composition-before1812.json"
commit=$(git -C "$owner" rev-parse HEAD)
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg commit "$commit" --arg parent "$parent" '. + {
 source_commit:$commit,source_mode:"retained1600-cdsp-pogo-candidate",
 parent_copr_build:11251559,parent_srpm_sha256:$parent,
 parent_composition:"source-composition-before1812.json",kernel_release:"7.3.1-1812",rpm_revision:"1812",
 cdsp_auto_boot:false,cdsp_context_sids:["0x0c01","0x0c02"],cdsp_secure_policy_override:false,
 cdsp_start_stop_retention:true,cdsp_permanent_platform_instance:true,
 pogo_mcu_firmware_distributed:false,pogo_report_format:"21-byte shared-protocol candidate",
 pogo_auth_provider_included:false,nfc_reader:false,ir_receive:false,
 rtc_source_retained:true,ssc_source_retained:true,binder_source_retained:true,
 physical_acceptance:false
}' "$profile/source-composition-before1812.json" > "$profile/source-composition.json"
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --quiet -)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
    -cJf "$output/senemos-native-profile-7.3.1.tar.xz" -C "$stage/unpacked" native-profile
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
    -cJf "$output/senemos-uke-boot-recipe.tar.xz" -C "$stage/unpacked" boot-recipe
[[ $(grep -Fxc '%global senemos_build_release 1600' "$spec") == 1 ]]
awk '
 /^%global senemos_build_release 1600$/ {$0="%global senemos_build_release 1812"}
 /^Name:[[:space:]]/ {print;print "Provides: uke-kernel(cdsp-pogo-candidate-v1) = 1";next}
 /^BuildRequires:[[:space:]]/ && !added {print;print "BuildRequires: libfdt-devel";added=1;next}
 /^%check$/ {
   print
   print "test -s %{_uke_out}/drivers/hid/hid-nanosic-uke.o"
   print "test -s %{_uke_out}/drivers/remoteproc/qcom_q6v5_pas.o"
   print "test -n \"$(find %{buildroot}/usr/lib/modules/%{krel} -type f -name '\''hid-nanosic-uke.ko*'\'' -print -quit)\""
   next
 }
 /^%changelog$/ {
   print
   print "* Tue Nov 03 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-1812"
   print "- Add guarded native CDSP startup and exact Uke pogo transport candidate."
   print "- Retain SSC, Binder and RTC; keep firmware and physical acceptance separate."
   print "";next
 }
 {print}
' "$spec" > "$stage/next.spec"
install -m644 "$stage/next.spec" "$spec"
sha256sum -c --quiet "$stage/retained-sources.sha256"
[[ $(rpmspec --target aarch64 --define 'dist %{nil}' -q --srpm --qf '%{VERSION}-%{RELEASE}' "$spec") == 7.3.1-1812 ]]
rpmbuild -bs --define "_sourcedir $output" --define "_srcrpmdir $output" "$spec"

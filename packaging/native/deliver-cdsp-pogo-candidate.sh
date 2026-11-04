#!/usr/bin/env bash
# Tablet-side DNF delivery. Native compilation and fixtures stay on COPR.
set -Eeuo pipefail
export LC_ALL=C
mode=${1:---preview}
[[ $# -le 1 && ( $mode == --preview || $mode == --apply ) ]] || {
    echo 'Usage: deliver-cdsp-pogo-candidate.sh [--preview|--apply]' >&2; exit 2;
}
release=7.3.1-2313
parent=7.3.1-1900
kernel_build=11252339
firmware_build=11252345
commit=7f8c01607fb1686fbd971c30468af7571993ca79
firmware_evr=0.1-2.fc46
repository=https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable:custom:cdsp-pogo-20261103
[[ $(uname -m) == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
for compatible in xiaomi,uke qcom,sm7675; do
    tr '\0' '\n' < /sys/firmware/devicetree/base/compatible | grep -Fxq "$compatible"
done
rpm -q uke-kernel-update >/dev/null
for family in senemos-uke-linux-kernel-mainline senemos-uke-linux-kernel-mainline-unstable; do
for component in '' -core -modules -dtbs -boot -singleboot; do
    while read -r version revision; do
        [[ $version =~ ^[0-9]+([.][0-9]+)*$ && $revision =~ ^[0-9]+([.][a-zA-Z0-9]+)*$ ]]
        installed=$version-$revision
        [[ $family != senemos-uke-linux-kernel-mainline || $installed != "$release.fc46" ]] || continue
        comparison=$(rpm --eval "%{lua:print(rpm.vercmp(\"$installed\", \"$parent.fc46\"))}")
        ((comparison <= 0)) || {
            echo 'A kernel newer than the retained 1900 parent is installed; compose its source changes before delivery.' >&2
            exit 1;
        }
    done < <(rpm -q "$family$component" --qf '%{VERSION} %{RELEASE}\n' 2>/dev/null | awk '/^[0-9]/')
done
done
if installed=$(rpm -q uke-cdsp-pogo-firmware --qf '%{VERSION}-%{RELEASE}' 2>/dev/null); then
    [[ $installed =~ ^[0-9]+([.][0-9]+)*-[0-9]+([.][a-zA-Z0-9]+)*$ ]]
    comparison=$(rpm --eval "%{lua:print(rpm.vercmp(\"$installed\", \"$firmware_evr\"))}")
    ((comparison <= 0)) || { echo 'A newer firmware helper is installed; review it before delivery.' >&2; exit 1; }
fi
[[ $(uname -r) != "$release" ]] || {
    echo 'Provision firmware from a retained running kernel before booting this candidate.' >&2; exit 1;
}
kernel=()
for component in '' -core -modules -dtbs -boot -singleboot; do
    kernel+=("senemos-uke-linux-kernel-mainline$component-$release.fc46.aarch64")
done
options=(--repofrompath="uke-cdsp-pogo-delivery,$repository/fedora-rawhide-aarch64/"
    '--disable-repo=*' --enable-repo=uke-cdsp-pogo-delivery
    --setopt=uke-cdsp-pogo-delivery.gpgcheck=1
    --setopt=uke-cdsp-pogo-delivery.gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-uke-selected
    --setopt=uke-cdsp-pogo-delivery.skip_if_unavailable=False
    --setopt='uke-cdsp-pogo-delivery.includepkgs=uke-cdsp-pogo-firmware,senemos-uke-linux-kernel-mainline*'
    --setopt=installonly_limit=0 --setopt=install_weak_deps=False)
printf 'Running kernel: %s; candidate: %s; retained source parent: %s\n' "$(uname -r)" "$release" "$parent"
printf 'Step 1:'; printf ' %q' /usr/bin/dnf5 "${options[@]}" install "uke-cdsp-pogo-firmware-$firmware_evr.aarch64"; printf '\n'
printf '%s\n' 'Step 2: /usr/libexec/uke-cdsp-pogo-firmware --preflight (read-only; no publication or start)'
printf 'Step 3:'; printf ' %q' /usr/bin/dnf5 "${options[@]}" install "${kernel[@]}"; printf '\n'
printf 'Step 4: /usr/libexec/uke-cdsp-pogo-firmware --import %s\n' "$release"
printf '%s\n' 'Existing kernels are retained. The installed updater may stage the inactive slot. Reboot, CDSP start and accessory tests are separate.'
[[ $mode == --apply ]] || exit 0
[[ $(id -u) == 0 ]] || { echo 'Run --apply from an administrator terminal.' >&2; exit 1; }
for build in "$kernel_build" "$firmware_build"; do
    result=$(curl -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$build")
    name=senemos-uke-linux-kernel-mainline; version=$release
    [[ $build != "$firmware_build" ]] || { name=uke-cdsp-pogo-firmware; version=0.1-2; }
    jq -e --arg name "$name" --arg version "$version" \
        '.state=="succeeded" and .source_package.name==$name and .source_package.version==$version' <<< "$result" >/dev/null || {
        echo 'A pinned COPR build has not succeeded with the expected source identity; refusing delivery.' >&2; exit 1;
    }
done
/usr/bin/dnf5 "${options[@]}" --assumeyes install "uke-cdsp-pogo-firmware-$firmware_evr.aarch64"
/usr/libexec/uke-cdsp-pogo-firmware --preflight
/usr/bin/dnf5 "${options[@]}" --assumeyes install "${kernel[@]}"
for component in '' -core -modules -dtbs -boot -singleboot; do
    rpm -q "senemos-uke-linux-kernel-mainline$component-$release.fc46"
done
jq -e --arg commit "$commit" --arg release "$release" \
    '.source_commit==$commit and .kernel_release==$release and .parent_copr_build==11252138 and
     .cdsp_auto_boot==false and .cdsp_start_stop_retention==true and
     .cdsp_context_sids==["0x0c01","0x0c02"] and .pogo_auth_provider_included==false' \
    "/usr/share/senemos/uke/$release/source-composition.json" >/dev/null
/usr/libexec/uke-cdsp-pogo-firmware --import "$release"
printf '%s\n' 'Matched RPMs and versioned device-local firmware are installed. No reboot, DSP compute or authenticated keyboard result is claimed.'

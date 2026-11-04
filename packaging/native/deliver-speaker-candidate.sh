#!/usr/bin/env bash
# DNF delivery only. Trial boot selection and physical qualification are separate.
set -Eeuo pipefail
export LC_ALL=C
mode=${1:---preview}
userspace_only=false
[[ $# -le 2 && ( $mode == --preview || $mode == --apply ) ]] || {
 echo 'Usage: deliver-speaker-candidate.sh [--preview|--apply] [--userspace-only]' >&2; exit 2;
}
if [[ $# == 2 ]]; then
 [[ $2 == --userspace-only ]] || exit 2
 userspace_only=true
fi
kernel_release=7400
kernel_build=11259935
parent_release=7200
parent_build=11259638
runtime_build=11252520
control_build=11259934
runtime_evr=0.3-1.fc46
control_evr=2.8.1-24.speech1.fc46
family=senemos-uke-linux-kernel-mainline-unstable
repository=https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-test:custom:audio-vi-20261103
[[ $(uname -m) == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
tr '\0' '\n' < /sys/firmware/devicetree/base/compatible | grep -Fxq xiaomi,uke
rpm -q uke-control uke-kernel-update >/dev/null
for component in uke-control uke-control-client uke-control-tui uke-control-client-devel uke-control-tests; do
 if installed_evr=$(rpm -q "$component" --qf '%{VERSION}-%{RELEASE}' 2>/dev/null); then
  [[ $installed_evr =~ ^[0-9]+([.][0-9]+)*-[0-9]+([.][a-zA-Z0-9]+)*$ ]]
  comparison=$(rpm --eval "%{lua:print(rpm.vercmp(\"$installed_evr\", \"$control_evr\"))}")
  ((comparison <= 0)) || {
   echo 'A newer control cohort is installed; retain its changes before delivery.' >&2; exit 1;
  }
 fi
done
userspace=("uke-control-$control_evr.aarch64")
for component in uke-control-client uke-control-tui uke-control-client-devel uke-control-tests; do
 if rpm -q "$component" >/dev/null 2>&1; then userspace+=("$component-$control_evr.aarch64"); fi
done
userspace+=(/usr/lib64/spa-0.2/aec/libspa-aec-webrtc.so)
builds=("$control_build")
if ! $userspace_only; then
 [[ $(findmnt -nr -M /mnt/vendor/persist -o TARGET) == /mnt/vendor/persist ]]
 mount_options=$(findmnt -nr -M /mnt/vendor/persist -o OPTIONS)
 [[ ,$mount_options, == *,ro,* ]]
 # This helper only stages package files. Preserve the current singleboot profile
 # and require the administrator's existing automatic activation prohibition.
 [[ $(awk -F= '$1=="automatic" {print $2}' /etc/senemos/kernel-update.conf) == 0 ]]
 for component in '' -core -modules -dtbs -boot; do
  while read -r installed_evr; do
   [[ $installed_evr =~ ^7[.]3[.]1-[0-9]+[.]fc46$ ]]
   [[ $installed_evr != 7.3.1-$kernel_release.fc46 ]] || continue
   comparison=$(rpm --eval "%{lua:print(rpm.vercmp(\"$installed_evr\", \"7.3.1-$parent_release.fc46\"))}")
   ((comparison <= 0)) || {
    echo 'A newer unstable kernel is installed; retain its changes before audio staging.' >&2; exit 1;
   }
  done < <(rpm -q "$family$component" --qf '%{VERSION}-%{RELEASE}\n' 2>/dev/null | awk '/^[0-9]/')
 done
 if installed_evr=$(rpm -q uke-speaker-runtime --qf '%{VERSION}-%{RELEASE}' 2>/dev/null); then
  [[ $installed_evr =~ ^[0-9]+([.][0-9]+)*-[0-9]+[.]fc46$ ]]
  comparison=$(rpm --eval "%{lua:print(rpm.vercmp(\"$installed_evr\", \"$runtime_evr\"))}")
  ((comparison <= 0)) || exit 1
 fi
 userspace+=("uke-speaker-runtime-$runtime_evr.aarch64")
 builds+=("$kernel_build" "$parent_build" "$runtime_build")
fi
kernel=()
# Do not update singleboot: it owns the global default-boot.img selector.
for component in '' -core -modules -dtbs -boot; do
 kernel+=("$family$component-7.3.1-$kernel_release.fc46.aarch64")
done
dnf_options=(--repofrompath="uke-audio-delivery,$repository/fedora-rawhide-aarch64/"
 --disable-repo=uke-selected --disable-repo=uke-policy
 --setopt=uke-audio-delivery.gpgcheck=1
 --setopt="uke-audio-delivery.gpgkey=https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-test/pubkey.gpg"
 --setopt=uke-audio-delivery.skip_if_unavailable=False
 --setopt=uke-audio-delivery.priority=1
 --setopt='uke-audio-delivery.includepkgs=uke-speaker-runtime,uke-control,uke-control-client,uke-control-tui,uke-control-client-devel,uke-control-tests,senemos-uke-linux-kernel-mainline-unstable*'
 --setopt=installonly_limit=0 --setopt=install_weak_deps=False)
printf 'Running kernel: %s; speaker ceiling: 223\n' "$(uname -r)"
printf 'Userspace:'; printf ' %q' dnf "${dnf_options[@]}" install "${userspace[@]}"; printf '\n'
if ! $userspace_only; then
 printf '%s\n' 'Then: generic data preparation and locked-memory read-only calibration check.'
 printf 'Package staging:'; printf ' %q' dnf "${dnf_options[@]}" install "${kernel[@]}"; printf '\n'
fi
printf '%s\n' 'No boot selection, singleboot update, versionlock change or reboot is requested.'
[[ $mode == --apply ]] || exit 0
[[ $(id -u) == 0 ]] || { echo 'Run --apply from an administrator terminal.' >&2; exit 1; }
for build in "${builds[@]}"; do
 result=$(curl -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$build")
 jq -e '.state=="succeeded"' <<< "$result" >/dev/null
 if [[ $build == "$kernel_build" ]]; then
  jq -e --arg name "$family" --arg version "7.3.1-$kernel_release" '.source_package.name==$name and .source_package.version==$version' <<< "$result" >/dev/null
 elif [[ $build == "$control_build" ]]; then
  jq -e --arg version "$control_evr" '.source_package.name=="uke-control" and .source_package.version==$version' <<< "$result" >/dev/null
 fi
done
boot_default=$(readlink /usr/lib/senemos/default-boot.img)
dnf "${dnf_options[@]}" --assumeyes install "${userspace[@]}"
if ! $userspace_only; then
 /usr/libexec/uke-speaker-prepare-data
 /usr/bin/uke-speaker-runtime --check
 dnf "${dnf_options[@]}" --assumeyes install "${kernel[@]}"
 for component in '' -core -modules -dtbs -boot; do rpm -q "$family$component-7.3.1-$kernel_release.fc46"; done
fi
[[ $(readlink /usr/lib/senemos/default-boot.img) == "$boot_default" ]]
rpm -q "uke-control-$control_evr"
printf '%s\n' 'DNF delivery complete. Physical audio checks remain pending; speaker gain stays 223.'

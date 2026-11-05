#!/usr/bin/env bash
# Legacy microphone userspace delivery only. Kernel delivery is coordinator-owned.
set -Eeuo pipefail
export LC_ALL=C
mode=${1:---preview}
[[ $# == 2 && ( $mode == --preview || $mode == --apply ) && $2 == --userspace-only ]] || {
 printf '%s\n' 'Usage: deliver-speaker-candidate.sh [--preview|--apply] --userspace-only' \
  'Kernel installation/profile selection belongs to the camera coordinator.' >&2; exit 2;
}
control_build=11259934
control_evr=2.8.1-24.speech1.fc46
control_parent_evr=2.8.1-23.fc46
repository=https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-test:custom:audio-vi-20261103
[[ $(uname -m) == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
tr '\0' '\n' < /sys/firmware/devicetree/base/compatible | grep -Fxq xiaomi,uke
rpm -q uke-control >/dev/null
for component in uke-control uke-control-client uke-control-tui uke-control-client-devel uke-control-tests; do
 if installed_evr=$(rpm -q "$component" --qf '%{VERSION}-%{RELEASE}' 2>/dev/null); then
  [[ $installed_evr =~ ^[0-9]+([.][0-9]+)*-[0-9]+([.][a-zA-Z0-9]+)*$ ]]
  [[ $installed_evr != "$control_evr" ]] || continue
  comparison=$(rpm --eval "%{lua:print(rpm.vercmp(\"$installed_evr\", \"$control_parent_evr\"))}")
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
dnf_options=(--repofrompath="uke-audio-delivery,$repository/fedora-rawhide-aarch64/"
 --disable-repo=uke-selected --disable-repo=uke-policy
 --setopt=uke-audio-delivery.gpgcheck=1
 --setopt="uke-audio-delivery.gpgkey=https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-test/pubkey.gpg"
 --setopt=uke-audio-delivery.skip_if_unavailable=False
 --setopt=uke-audio-delivery.priority=1
 --setopt='uke-audio-delivery.includepkgs=uke-control,uke-control-client,uke-control-tui,uke-control-client-devel,uke-control-tests'
 --setopt=install_weak_deps=False --exclude='kernel*' --exclude='senemos-uke-linux-kernel-mainline*')
printf 'Userspace:'; printf ' %q' dnf "${dnf_options[@]}" install "${userspace[@]}"; printf '\n'
printf '%s\n' 'Automatic staging and local rollback preferences are preserved.'
[[ $mode == --apply ]] || exit 0
[[ $(id -u) == 0 ]] || { echo 'Run --apply from an administrator terminal.' >&2; exit 1; }
result=$(curl -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$control_build")
jq -e --arg version "$control_evr" '.state=="succeeded" and .source_package.name=="uke-control" and .source_package.version==$version' <<< "$result" >/dev/null
dnf "${dnf_options[@]}" --assumeyes install "${userspace[@]}"
rpm -q "uke-control-$control_evr"
printf '%s\n' 'Close captures before a deliberate WirePlumber reload. Speaker ceiling stays223.'

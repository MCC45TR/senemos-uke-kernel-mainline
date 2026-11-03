#!/usr/bin/env bash
# Tablet-side delivery of the reviewed COPR audio candidate. No native builds.
set -Eeuo pipefail
export LC_ALL=C
mode=${1:---preview}
[[ $# -le 1 && ( $mode == --preview || $mode == --apply ) ]] || {
 echo 'Usage: deliver-speaker-candidate.sh [--preview|--apply]' >&2; exit 2;
}
kernel_release=2800
kernel_build=11252451
parent_release=2700
parent_build=11252415
runtime_build=11252242
control_build=11251908
runtime_evr=0.2-2.fc46
control_evr=2.8.1-8.speech4.fc46
repository=https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-test:custom:audio-vi-20261103
[[ $(uname -m) == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
[[ -r /sys/firmware/devicetree/base/compatible ]]
tr '\0' '\n' < /sys/firmware/devicetree/base/compatible | grep -Fxq xiaomi,uke
[[ $(findmnt -nr -M /mnt/vendor/persist -o TARGET) == /mnt/vendor/persist ]]
mount_options=$(findmnt -nr -M /mnt/vendor/persist -o OPTIONS)
[[ ,$mount_options, == *,ro,* ]]
rpm -q uke-control uke-kernel-update >/dev/null
for component in '' -core -modules -dtbs -boot -singleboot; do
 while read -r installed_version installed_release; do
  [[ $installed_version =~ ^[0-9]+([.][0-9]+)*$ && $installed_release =~ ^[0-9]+([.][a-zA-Z0-9]+)*$ ]]
  installed_evr=$installed_version-$installed_release
  [[ $installed_evr != 7.3.1-$kernel_release.fc46 ]] || continue
  comparison=$(rpm --eval "%{lua:print(rpm.vercmp(\"$installed_evr\", \"7.3.1-$parent_release.fc46\"))}")
  ((comparison <= 0)) || {
   echo 'A newer native kernel cohort is installed; retain its source changes before audio delivery.' >&2; exit 1;
  }
 done < <(rpm -q "senemos-uke-linux-kernel-mainline$component" --qf '%{VERSION} %{RELEASE}\n' 2>/dev/null | awk '/^[0-9]/')
done
for component in uke-control uke-control-client uke-control-tui uke-control-client-devel uke-control-tests uke-speaker-runtime; do
 if installed_evr=$(rpm -q "$component" --qf '%{VERSION}-%{RELEASE}' 2>/dev/null); then
  [[ $installed_evr =~ ^[0-9]+([.][0-9]+)*-[0-9]+([.][a-zA-Z0-9]+)*$ ]]
  wanted=$control_evr;[[ $component != uke-speaker-runtime ]] || wanted=$runtime_evr
  comparison=$(rpm --eval "%{lua:print(rpm.vercmp(\"$installed_evr\", \"$wanted\"))}")
  ((comparison <= 0)) || {
   echo 'A newer control/runtime cohort is installed; review its source changes before audio delivery.' >&2; exit 1;
  }
 fi
done
userspace=("uke-speaker-runtime-$runtime_evr.aarch64" "uke-control-$control_evr.aarch64")
for component in uke-control-client uke-control-tui uke-control-client-devel uke-control-tests; do
 if rpm -q "$component" >/dev/null 2>&1; then userspace+=("$component-$control_evr.aarch64"); fi
done
userspace+=(/usr/lib64/spa-0.2/aec/libspa-aec-webrtc.so)
kernel=()
for component in '' -core -modules -dtbs -boot -singleboot; do
 kernel+=("senemos-uke-linux-kernel-mainline$component-7.3.1-$kernel_release.fc46.aarch64")
done
dnf_options=(--repofrompath="uke-audio-delivery,$repository/fedora-rawhide-aarch64/"
 --disable-repo=uke-selected --disable-repo=uke-policy
 --setopt=uke-audio-delivery.gpgcheck=1
 --setopt="uke-audio-delivery.gpgkey=https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-test/pubkey.gpg"
 --setopt=uke-audio-delivery.skip_if_unavailable=False
 --setopt=uke-audio-delivery.priority=1
 --setopt='uke-audio-delivery.includepkgs=uke-speaker-runtime,uke-control,uke-control-client,uke-control-tui,uke-control-client-devel,uke-control-tests,senemos-uke-linux-kernel-mainline*'
 --setopt=installonly_limit=0 --setopt=install_weak_deps=False)
printf 'Running kernel: %s\n' "$(uname -r)"
printf 'Candidate: 7.3.1-%s; retained normal-source parent: %s; gain ceiling: 223\n' "$kernel_release" "$parent_release"
printf 'Step 1:'; printf ' %q' dnf "${dnf_options[@]}" install "${userspace[@]}"; printf '\n'
printf '%s\n' 'Step 2: /usr/libexec/uke-speaker-prepare-data (generic public data only)'
printf '%s\n' 'Step 3: /usr/bin/uke-speaker-runtime --check (private source read in locked RAM only)'
printf 'Step 4:'; printf ' %q' dnf "${dnf_options[@]}" install "${kernel[@]}"; printf '\n'
printf '%s\n' 'Existing recovery kernels are retained. The existing updater may stage the inactive boot slot. No reboot is requested.'
[[ $mode == --apply ]] || exit 0
[[ $(id -u) == 0 ]] || { echo 'Run --apply from an administrator terminal.' >&2; exit 1; }
for build in "$kernel_build" "$parent_build" "$runtime_build" "$control_build"; do
 result=$(curl -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$build")
 jq -e '.state=="succeeded"' <<< "$result" >/dev/null || {
  echo 'A pinned COPR build has not succeeded; refusing installation.' >&2; exit 1;
 }
 if [[ $build == "$kernel_build" ]]; then
  jq -e --arg version "7.3.1-$kernel_release" '.source_package.name=="senemos-uke-linux-kernel-mainline" and .source_package.version==$version' <<< "$result" >/dev/null
 fi
done
dnf "${dnf_options[@]}" --assumeyes install "${userspace[@]}"
/usr/libexec/uke-speaker-prepare-data
/usr/bin/uke-speaker-runtime --check
dnf "${dnf_options[@]}" --assumeyes install "${kernel[@]}"
rpm -q "uke-speaker-runtime-$runtime_evr" "uke-control-$control_evr"
for component in '' -core -modules -dtbs -boot -singleboot; do
 rpm -q "senemos-uke-linux-kernel-mainline$component-7.3.1-$kernel_release.fc46"
done
printf '%s\n' 'Exact audio RPM cohorts installed. Reboot and physical audio qualification remain separate; gain stays 223.'

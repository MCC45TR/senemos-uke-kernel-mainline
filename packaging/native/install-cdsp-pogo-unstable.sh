#!/usr/bin/env bash
# Install dormant COPR candidate RPMs through DNF, preserving the selected tuple.
set -Eeuo pipefail
export LC_ALL=C
mode=${1:---preview}
[[ $# -le 1 && ( $mode == --preview || $mode == --apply ) ]]
family=senemos-uke-linux-kernel-mainline-unstable
release=7.3.1-9003-unstable
build=11260109
source_commit=0d33f44fb188f6cd53f40c016a06fd80ac736f98
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
manifest=$owner/manifests/cdsp-pogo9003-rpm-audit.json
jq -e --arg commit "$source_commit" '.source_commit==$commit and .copr_build==11260109 and
 .full_binary_rpm_audit and (.packages|length)==6' "$manifest" >/dev/null
repo=uke-cdsp-pogo-9003
base=https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable:custom:cdsp-pogo-20261104/fedora-rawhide-aarch64
packages=()
for suffix in '' -core -modules -dtbs -boot; do
    packages+=("$family$suffix-7.3.1-9003.fc46.aarch64")
done
dnf=(/usr/bin/dnf5 --repofrompath="$repo,$base"
     --setopt="$repo.gpgcheck=True"
     --setopt="$repo.gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-uke-selected"
     --setopt=install_weak_deps=False --setopt=installonly_limit=0
     --setopt=keepcache=False)
state=$(curl -fLsS --max-time 20 "https://copr.fedorainfracloud.org/api_3/build/$build" | jq -er '.state')
[[ $state == succeeded ]] || { printf 'COPR %s is %s; staging is unavailable.\n' "$build" "$state" >&2; exit 1; }
printf 'Running: %s; staged candidate: %s; COPR: %s\n' "$(uname -r)" "$release" "$build"
if [[ $mode == --preview ]]; then
    if [[ $EUID != 0 && ! -r /usr/lib/sysimage/libdnf5/packages.toml ]]; then
        printf '%s\n' 'DNF system state is protected on this installation; run --preview in an administrator terminal.' >&2
        exit 1
    fi
    exec "${dnf[@]}" --assumeno install "${packages[@]}"
fi
[[ $EUID == 0 ]] || { printf '%s\n' 'Run --apply in an administrator terminal.' >&2; exit 1; }
[[ $(uname -r) == 7.3.1-7200-unstable ]]
tr '\0' '\n' < /sys/firmware/devicetree/base/compatible | grep -Fxq xiaomi,uke
tr '\0' '\n' < /sys/firmware/devicetree/base/compatible | grep -Fxq qcom,sm7675
grep -Fxq automatic=0 /etc/senemos/kernel-update.conf
grep -Fxq mode=off /etc/senemos/rollback.conf
[[ $(readlink /usr/lib/senemos/default-boot.img) == kernel-updates/7.3.1-7200-unstable/userdata.img ]]
receipt=$(mktemp -d /var/lib/senemos/cdsp-pogo-candidate.XXXXXX)
sha256sum /etc/senemos/kernel-update.conf /etc/senemos/rollback.conf \
    /var/lib/senemos/kernel-update/userdata.state /usr/share/senemos/uke/singleboot.json > "$receipt/protected-before.sha256"
readlink /usr/lib/senemos/default-boot.img > "$receipt/selected-before"
rpm -qa "$family*" --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort > "$receipt/installed-before"
"${dnf[@]}" -y install "${packages[@]}" > "$receipt/dnf.log" 2>&1
for package in "${packages[@]}"; do
    rpm -q "$package"
    rpm -V --noscripts --nomtime "$package"
    expected=$(jq -er --arg nvr "$package" '.packages[]|select(.nvr==$nvr)|.header_sha256+" "+.payload_sha256' "$manifest")
    [[ $(rpm -q --qf '%{SHA256HEADER} %{PAYLOADSHA256}' "$package") == "$expected" ]]
done
while read -r package; do rpm -q "$package" >/dev/null; done < "$receipt/installed-before"
metadata=/usr/share/senemos/uke/$release/source-composition.json
jq -e --arg commit "$source_commit" --arg release "$release" '
 .source_commit==$commit and .kernel_release==$release and
 .source_mode=="retained7300-cdsp-pogo-candidate" and .parent_copr_build==11259919 and
 .cdsp_auto_boot==false and .cdsp_start_stop_retention and
 .cdsp_context_sids==["0x0c01","0x0c02"] and .rtc_backend=="pmic-read-only-counter" and
 .rtc_secure_offset_boot_activation==false and .physical_acceptance==false
' "$metadata" > "$receipt/composition-check.txt"
sha256sum -c --strict "$receipt/protected-before.sha256"
[[ $(readlink /usr/lib/senemos/default-boot.img) == "$(cat "$receipt/selected-before")" ]]
printf 'Installed dormant %s; selected boot tuple and previous RPMs retained. Receipt: %s\n' "$release" "$receipt"
printf '%s\n' 'Firmware qualification/provisioning and a later controlled boot remain separate steps.'

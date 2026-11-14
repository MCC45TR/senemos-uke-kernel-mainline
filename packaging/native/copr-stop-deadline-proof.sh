#!/usr/bin/env bash
# COPR source worker only; focused text proof, never a kernel delivery recipe.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?Source RPM result}")
proof_release=${2:?Automatically allocated source-check release}
[[ $proof_release =~ ^[1-9][0-9]*$ && ! -e $output ]]
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' manifests/stop-deadline-callbacks-20261107.json | sha256sum -c --strict --quiet -)
bash "$owner/packaging/native/refuse-published-release.sh" uke-kernel-migration-check "7.3.3-$proof_release"
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
mkdir "$output" "$work/extracted" "$work/stop-deadline-proof"
curl -q -fsSL --retry 2 --max-time 600 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11283159/senemos-uke-linux-kernel-mainline-unstable-7.3.3-1.src.rpm -o "$work/parent.src.rpm"
printf '%s  %s\n' e5de2472b379aaceb212679bb4ef6b8363a2ef26ddc32abaaea2f84bb6cc013e "$work/parent.src.rpm" | sha256sum -c --strict -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$work/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.3-1 ]]
rpm2cpio "$work/parent.src.rpm" | (cd "$work/extracted";cpio -idm --quiet --no-absolute-filenames ./senemos-native-profile-7.3.3.tar.xz senemos-native-profile-7.3.3.tar.xz)
test -s "$work/extracted/senemos-native-profile-7.3.3.tar.xz"
tar -xJf "$work/extracted/senemos-native-profile-7.3.3.tar.xz" -C "$work/extracted" \
 native-profile/patches/boot/0073-uke-fs19xx-protected-runtime.patch native-profile/src/audio/uke-fs19xx-safety.h
(cd "$work/extracted/native-profile";jq -r '.retained_inputs|to_entries[]|.value+"  "+.key' "$owner/manifests/stop-deadline-callbacks-20261107.json" | sha256sum -c --strict -)
tree=$work/stop-deadline-proof
mapfile -t assets < <(jq -er '.source_assets[].path' "$owner/manifests/stop-deadline-callbacks-20261107.json")
assets+=(LICENSE src/audio/0015-uke-protected-stop-drain.patch src/audio/0017-uke-protected-idle-worker.patch src/audio/uke-fs19xx-muted-stop.h
 patches/7.3.0/0115-asoc-fs19xx-smart-amplifier.patch patches/7.3.0/0117-asoc-uke-audio-runtime-safety.patch
 patches/7.3.0/0118-asoc-fs19xx-speaker-rotation.patch patches/7.3.0/0119-asoc-uke-probe-readiness.patch
 patches/boot/0058-fs19xx-current-workqueue.patch manifests/stop-deadline-callbacks-20261107.json)
for path in "${assets[@]}";do install -Dm644 "$owner/$path" "$tree/$path";done
install -Dm644 "$work/extracted/native-profile/patches/boot/0073-uke-fs19xx-protected-runtime.patch" "$tree/retained-stop-inputs/0073-uke-fs19xx-protected-runtime.patch"
install -Dm644 "$work/extracted/native-profile/src/audio/uke-fs19xx-safety.h" "$tree/retained-stop-inputs/uke-fs19xx-safety.h"
git -C "$owner" rev-parse HEAD > "$tree/source-commit"
printf 'Focused actual callback proof only. No cumulative kernel objects, linked ABI, installation, boot, sound or gain243 acceptance.\n' > "$tree/SCOPE.txt"
(cd "$tree";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
tar --sort=name --owner=0 --group=0 --numeric-owner -cJf "$output/stop-deadline-proof.tar.xz" -C "$work" stop-deadline-proof
awk -v release="$proof_release" '/^%global proof_release 1$/ {$0="%global proof_release "release;n++}{print}END{if(n!=1)exit 1}' \
 "$owner/packaging/native/stop-deadline-callbacks.spec" > "$output/uke-kernel-migration-check.spec"
printf 'Focused callback source proof7.3.3-%s prepared from exact complete7331 inputs; no full kernel admission.\n' "$proof_release"

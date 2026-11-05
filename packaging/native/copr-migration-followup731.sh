#!/usr/bin/env bash
# COPR only: retain the complete12206 profile, configs, patches and firmware paths.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?Source result directory}")
revision=${2:?Planned unstable revision}
mode=${3:?check or full}
proof=${4:?Check release or admitted build}
[[ $revision =~ ^[1-9][0-9]{4}$ && ($mode == check || $mode == full) && $proof =~ ^[1-9][0-9]*$ ]]
commit=$(git -C "$owner" rev-parse HEAD)
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
[[ $(curl -q -fLsS --max-time 30 https://copr.fedorainfracloud.org/api_3/build/11267328 | jq -er .state) == succeeded ]]
if [[ $mode == full ]]; then
 [[ $revision == 12207 ]] || { printf "Historical followup constructor is restricted to12207; extend the complete qualified12207 SRPM for later candidates.\n" >&2;exit 1; }
 [[ $# == 5 && $5 =~ ^[a-f0-9]{64}$ ]]
 curl -q -fLsS --max-time 30 "https://copr.fedorainfracloud.org/api_3/build/$proof" > "$stage/proof.json"
 jq -e '.state=="succeeded" and .source_package.name=="uke-kernel-migration-check"' "$stage/proof.json" >/dev/null
 url=$(curl -q -fLsS --max-time 30 "https://copr.fedorainfracloud.org/api_3/build-chroot/$proof/fedora-rawhide-aarch64" | jq -er .result_url)
 evr=$(jq -er .source_package.version "$stage/proof.json")
 curl -q -fLsS --max-time 60 "${url}uke-kernel-migration-check-$evr.fc46.aarch64.rpm" -o "$stage/proof.rpm"
 printf '%s  %s\n' "$5" "$stage/proof.rpm" | sha256sum -c --strict -
 [[ $(rpm2cpio "$stage/proof.rpm" | cpio -i --to-stdout --quiet '*source-commit') == "$commit" ]]
 bash "$owner/packaging/native/refuse-published-release.sh" senemos-uke-linux-kernel-mainline-unstable "7.3.1-$revision"
else
 [[ $# == 4 ]]
 bash "$owner/packaging/native/refuse-published-release.sh" uke-kernel-migration-check "7.3.1-$proof"
fi
[[ ! -e $output || (-d $output && -z $(find "$output" -mindepth 1 -maxdepth 1 -print -quit)) ]]
mkdir -p "$output" "$stage/unpacked"
curl -q -fLsS --retry 2 --max-time 600 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11267328/senemos-uke-linux-kernel-mainline-unstable-7.3.1-12206.src.rpm -o "$stage/parent.src.rpm"
printf '%s  %s\n' c83d55bf40dbf34be441a5500027007ac5ed9e6389a64151b95b4db22c944ac2 "$stage/parent.src.rpm" | sha256sum -c --strict -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.1-12206 ]]
rpm2cpio "$stage/parent.src.rpm" > "$stage/parent.cpio"
cpio -t --quiet < "$stage/parent.cpio" | awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}'
(cd "$output"; cpio -idm --quiet --no-absolute-filenames < "$stage/parent.cpio")
native=senemos-native-profile-7.3.1.tar.xz
boot_archive=senemos-uke-boot-recipe.tar.xz
spec=$output/senemos-uke-linux-kernel-mainline-unstable.spec
(cd "$output"; find . -maxdepth 1 -type f ! -name "${spec##*/}" ! -name "$native" ! -name "$boot_archive" ! -name boot-payload.json -print0 | sort -z | xargs -0 sha256sum) > "$stage/retained"
for archive in "$native" "$boot_archive"; do tar -xJf "$output/$archive" -C "$stage/unpacked"; done
profile=$stage/unpacked/native-profile
boot=$stage/unpacked/boot-recipe
(cd "$profile"; sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
jq -e '.source_commit=="424caffa1313639827d8a5c523a2b3dd7d01f37a" and .kernel_release=="7.3.1-12206-unstable" and .speaker_protection_graph_admitted and .speaker_gain_ceiling==223 and (.speaker_physical_protection_qualified|not)' "$profile/source-composition.json" >/dev/null
for tree in "$profile" "$boot"; do
 printf '%s  %s\n' 13cb6a40a5e11234e5f349260f266e66c48699d68dcfcf6742d47e69bc9bf0fb "$tree/src/boot/boot-image.cpp" | sha256sum -c --strict -
done
assets=(manifests/migration-boot-header-layer-20261105.json src/boot/boot-image.cpp tests/boot-image-contract.sh tests/migration-boot-header.sh src/audio/0004-q6apm-scope-graph-open-failure.patch tests/audio-open-failure-contract.sh tests/camcc-quarantine-sleep.sh)
for asset in "${assets[@]}"; do install -Dm644 "$owner/$asset" "$profile/$asset"; done
install -Dm644 "$owner/src/camera/sleep/camcc-sm7675-sleep.h" "$profile/src/camera/provider/camcc-sm7675-sleep.h"
sed -i 's/for part in power owner clocks handoff registration crm-guard; do/for part in power owner clocks handoff registration crm-guard sleep; do/' "$profile/src/camera/prepare-controller731.sh"
(cd "$profile"; patch --dry-run -p1 --fuzz=0 --batch -i "$owner/src/camera/sleep/0001-camcc-quarantine-s2idle.patch"; patch -p1 --fuzz=0 --batch -i "$owner/src/camera/sleep/0001-camcc-quarantine-s2idle.patch")
# Explicit narrowly changed source preimages remain archived in the complete parent.
for tree in "$profile" "$boot"; do
 [[ $(grep -Fo uke7.3.1-12206u "$tree/src/audio/uke-audio-card.c" | wc -l) == 2 ]]
 sed "s/uke7[.]3[.]1-12206u/uke7.3.1-${revision}u/g" "$tree/src/audio/uke-audio-card.c" > "$stage/card.c"
 install -m644 "$stage/card.c" "$tree/src/audio/uke-audio-card.c"
done
cat >> "$profile/prepare.sh" <<'PREP'

# Only graph40 owns protected speaker state; failed IDs remain quarantined.
patch --dry-run -d "$kernel" -p1 --fuzz=0 --batch -i "$profile/src/audio/0004-q6apm-scope-graph-open-failure.patch"
patch -d "$kernel" -p1 --fuzz=0 --batch -i "$profile/src/audio/0004-q6apm-scope-graph-open-failure.patch"
bash "$profile/tests/audio-open-failure-contract.sh" "$kernel"
bash "$profile/tests/camcc-quarantine-sleep.sh"
bash "$profile/tests/migration-boot-header.sh"
PREP
cp "$profile/source-composition.json" "$profile/source-composition-before-followup.json"
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg source "$commit" --arg revision "$revision" '.+{source_commit:$source,rpm_revision:$revision,kernel_release:("7.3.1-"+$revision+"-unstable"),diagnostic_audio_driver:("uke7_3_1-"+$revision+"u"),followup_parent_build:11267328,followup_parent_source:"424caffa1313639827d8a5c523a2b3dd7d01f37a",speaker_graph_open_failure_scope_layer:1,camcc_quarantine_s2idle_layer:1,boot_header_zero_version_layer:1,boot_header_zero_version_source:"9ea9a0c8eb12fc66e76b5ea44a66d13f6a44124d",boot_header_zero_version_check:11267985,device_installation:false,physical_acceptance:false}' "$profile/source-composition-before-followup.json" > "$profile/source-composition.json"
while IFS= read -r path; do
 path=${path#./}
 case $path in packaging/native/prepare.sh|packaging/native/native.config) continue;; esac
 install -Dm644 "$profile/$path" "$boot/$path"
done < <(cd "$profile"; find src tests configs packaging -type f | LC_ALL=C sort)
install -Dm644 "$profile/manifests/migration-boot-header-layer-20261105.json" "$boot/manifests/migration-boot-header-layer-20261105.json"
install -m644 "$profile/prepare.sh" "$boot/packaging/native/cumulative-prepare.sh"
for tree in "$profile" "$boot"; do
 if [[ $tree == "$profile" ]]; then
  (cd "$tree"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
 else
  (cd "$tree"; find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$stage/assets.sha256"
  jq -Rn '[inputs|capture("^(?<sha256>[a-f0-9]{64})  [.]?/?(?<path>.*)$")]|map({path,sha256})' < "$stage/assets.sha256" > "$stage/assets.json"
  jq --slurpfile assets "$stage/assets.json" '.source_assets=$assets[0]' "$boot/lock.json" > "$stage/lock.json"
  install -m644 "$stage/lock.json" "$boot/lock.json"
 fi
done
install -m644 "$boot/lock.json" "$output/boot-payload.json"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
for tree in native-profile boot-recipe; do
 archive=$native; [[ $tree != boot-recipe ]] || archive=$boot_archive
 tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$archive" -C "$stage/unpacked" "$tree"
done
awk -v revision="$revision" '
 /^%global senemos_build_release 12206$/ {$0="%global senemos_build_release "revision;changed++}
 /^Requires: uke-kernel-update >= 1[.]8[.]97$/ {print "Requires: uke-kernel-update >= 1.8.98"; print "Requires: uke-kernel-update(alternating-checkpoint-v2) >= 1";next}
 /^%changelog$/ {print;print "* Thu Nov 05 2026 Uke contributors - 7.3.1-"revision;print "- Scope audio OPEN cleanup and retain unpublished CRM quarantine across s2idle.";print "- Preserve protected223 and every cumulative feature/admission gate.";print "";next}
 {print} END {if(changed!=1)exit 1}
' "$spec" > "$stage/full.spec"
install -m644 "$stage/full.spec" "$spec"
if [[ $mode == check ]]; then
 # Reuse the exact qualified source-check packaging, adding real changed objects.
 printf '%s  %s\n' 5493807ca28533b0bd0caa497754d99b4d366a852047a1dfb367c46b483830cd "$owner/packaging/native/copr-migration-cohort731.sh" | sha256sum -c --strict -
 awk '/^if \[\[ \$mode == check \]\]; then$/ {copy=1;next} copy && /^fi$/ {exit} copy {print}' "$owner/packaging/native/copr-migration-cohort731.sh" | sed 's| drivers/iio/common/uke-ssc/uke-ssc.o drivers/input/misc/qcom-smp2p-switch.o| sound/soc/qcom/qdsp6/q6apm.o drivers/clk/qcom/camcc-sm7675.o drivers/iio/common/uke-ssc/uke-ssc.o drivers/input/misc/qcom-smp2p-switch.o|' > "$stage/check-packaging.sh"
 test -s "$stage/check-packaging.sh"
 source "$stage/check-packaging.sh"
 sed -i 's/Complete12204/Complete12206/g' "$output/uke-kernel-migration-check.spec"
fi
(cd "$output"; sha256sum -c --strict --quiet "$stage/retained")
printf 'Complete12206 audio/sleep followup prepared for planned%s/%s; physical acceptance pending.\n' "$revision" "$mode"

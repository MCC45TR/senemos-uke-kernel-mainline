#!/usr/bin/env bash
# COPR only. Extend complete12209; preserve every driver/config/DT/firmware gate.
set -Eeuo pipefail
trap 'printf "Protected route source guard failed at line%s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?Source result directory}")
revision=${2:?Unique unstable revision}
mode=${3:?check or full}
proof=${4:?Check release or admitted build}
[[ $revision == 12210 && ($mode == check || $mode == full) && $proof =~ ^[1-9][0-9]*$ ]]
commit=$(git -C "$owner" rev-parse HEAD)
native_proof_source=$commit
stage=$(mktemp -d);trap 'find "$stage" -depth -delete' EXIT
[[ $(curl -q -fLsS --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11269020 | jq -er .state) == succeeded ]]
if [[ $mode == full ]];then
 [[ $# == 5 && $5 =~ ^[a-f0-9]{64}$ ]]
 curl -q -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$proof" > "$stage/proof.json"
 jq -e '.state=="succeeded" and .source_package.name=="uke-kernel-migration-check"' "$stage/proof.json" >/dev/null
 url=$(curl -q -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build-chroot/$proof/fedora-rawhide-aarch64" | jq -er .result_url)
 evr=$(jq -er .source_package.version "$stage/proof.json")
 curl -q -fLsS --max-time 90 "${url}uke-kernel-migration-check-$evr.fc46.aarch64.rpm" -o "$stage/proof.rpm"
 printf '%s  %s\n' "$5" "$stage/proof.rpm" | sha256sum -c --strict -
 qualified_source=$(rpm2cpio "$stage/proof.rpm" | cpio -i --to-stdout --quiet '*source-commit')
 [[ $qualified_source == "$commit" ]]
 bash "$owner/packaging/native/refuse-published-release.sh" senemos-uke-linux-kernel-mainline-unstable "7.3.1-$revision"
else
 [[ $# == 4 ]]
 bash "$owner/packaging/native/refuse-published-release.sh" uke-kernel-migration-check "7.3.1-$proof"
fi
[[ ! -e $output || (-d $output && -z $(find "$output" -mindepth 1 -maxdepth 1 -print -quit)) ]]
mkdir -p "$output" "$stage/unpacked"
curl -q -fLsS --retry 2 --max-time 600 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11269020/senemos-uke-linux-kernel-mainline-unstable-7.3.1-12209.src.rpm -o "$stage/parent.src.rpm"
printf '%s  %s\n' 2088fddf829a01fe7b2b466960a0c365891b38f18d2e31c06ec273b4990355c1 "$stage/parent.src.rpm" | sha256sum -c --strict -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.1-12209 ]]
rpm2cpio "$stage/parent.src.rpm" > "$stage/parent.cpio"
cpio -t --quiet < "$stage/parent.cpio" | awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}'
(cd "$output";cpio -idm --quiet --no-absolute-filenames < "$stage/parent.cpio")
native=senemos-native-profile-7.3.1.tar.xz
boot_archive=senemos-uke-boot-recipe.tar.xz
spec=$output/senemos-uke-linux-kernel-mainline-unstable.spec
(cd "$output";find . -maxdepth 1 -type f ! -name "${spec##*/}" ! -name "$native" ! -name "$boot_archive" ! -name boot-payload.json -print0 | sort -z | xargs -0 sha256sum) > "$stage/retained"
for archive in "$native" "$boot_archive";do tar -xJf "$output/$archive" -C "$stage/unpacked";done
profile=$stage/unpacked/native-profile
boot=$stage/unpacked/boot-recipe
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
jq -e '.source_commit=="514536ca7d4015048f2b6b9a4d8871612ac4de28" and .kernel_release=="7.3.1-12209-unstable" and .speaker_graph_open_failure_scope_layer==1 and .camcc_quarantine_s2idle_layer==1 and .boot_header_zero_version_layer==1 and .speaker_gain_ceiling==223 and .speaker_protection_graph_admitted and (.speaker_physical_protection_qualified|not)' "$profile/source-composition.json" >/dev/null
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$stage/configs"
assets=(src/audio/0005-protected-route-entry.patch tests/audio-protected-route.c tests/audio-protected-route.sh docs/PROTECTED-SPEAKER-ROUTE.md manifests/protected-speaker-route-20261106.json)
printf '%s  %s\n' 3ff2b5affd4881a6ce903782afa02cee24351ada1ef3b18643dd2a1687a4381a "$profile/src/audio/build-protected-topology.sh" | sha256sum -c --strict -
printf '%s  %s\n' 83193dd68fe748983d2febad6c345d7adb60481fe714469f530bb6e60eb994dd "$profile/src/audio/POCO-Pad-X1.conf" | sha256sum -c --strict -
install -m644 "$profile/src/audio/build-protected-topology.sh" "$stage/original-builder.sh"
for tree in "$profile" "$boot";do
 install -Dm644 "$stage/original-builder.sh" "$tree/history-before-protected-route/src/audio/build-protected-topology.sh"
 for asset in "${assets[@]}";do install -Dm644 "$owner/$asset" "$tree/$asset";done
 if [[ ! -f $tree/src/audio/build-protected-topology.sh ]];then
  install -Dm644 "$stage/original-builder.sh" "$tree/src/audio/build-protected-topology.sh"
 fi
 printf '%s  %s\n' 3ff2b5affd4881a6ce903782afa02cee24351ada1ef3b18643dd2a1687a4381a "$tree/src/audio/build-protected-topology.sh" | sha256sum -c --strict -
 (cd "$tree"; patch --dry-run -p1 --fuzz=0 --batch -i "$owner/src/audio/0005-protected-route-entry.patch";patch -p1 --fuzz=0 --batch -i "$owner/src/audio/0005-protected-route-entry.patch")
 [[ $(grep -Fo uke7.3.1-12209u "$tree/src/audio/uke-audio-card.c" | wc -l) == 2 ]]
 sed "s/uke7[.]3[.]1-12209u/uke7.3.1-${revision}u/g" "$tree/src/audio/uke-audio-card.c" > "$stage/card.c"
 install -m644 "$stage/card.c" "$tree/src/audio/uke-audio-card.c"
done
cat >> "$profile/prepare.sh" <<'CHECK'
# The original cumulative prep and protection gates have completed above.
for route_cc in gcc clang;do
 for route_san in 0 1;do CC=$route_cc SANITIZE=$route_san bash "$profile/tests/audio-protected-route.sh" "$kernel";done
done
CHECK

cp "$profile/source-composition.json" "$profile/source-composition-before-protected-route.json"
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg source "$commit" --arg revision "$revision" '.+{source_commit:$source,rpm_revision:$revision,kernel_release:("7.3.1-"+$revision+"-unstable"),diagnostic_audio_driver:("uke7_3_1-"+$revision+"u"),protected_route_parent_build:11269020,protected_route_parent_source:"514536ca7d4015048f2b6b9a4d8871612ac4de28",speaker_protected_route_entry_layer:1,speaker_frontend_entry_module:17454,minimum_kernel_updater:"1.8.101",device_installation:false,physical_acceptance:false}' "$profile/source-composition-before-protected-route.json" > "$profile/source-composition.json"
install -m644 "$profile/prepare.sh" "$boot/packaging/native/cumulative-prepare.sh"
sha256sum -c --strict --quiet "$stage/configs"
for tree in "$profile" "$boot";do
 if [[ $tree == "$profile" ]];then
  (cd "$tree";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
 else
  (cd "$tree";find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$stage/assets.sha256"
  jq -Rn '[inputs|capture("^(?<sha256>[a-f0-9]{64})  [.]?/?(?<path>.*)$")]|map({path,sha256})' < "$stage/assets.sha256" > "$stage/assets.json"
  jq --slurpfile assets "$stage/assets.json" '.source_assets=$assets[0]' "$boot/lock.json" > "$stage/lock.json"
  install -m644 "$stage/lock.json" "$boot/lock.json"
 fi
done
install -m644 "$boot/lock.json" "$output/boot-payload.json"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
for tree in native-profile boot-recipe;do
 archive=$native;[[ $tree != boot-recipe ]] || archive=$boot_archive
 tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$archive" -C "$stage/unpacked" "$tree"
done
awk -v revision="$revision" '
 /^%global senemos_build_release 12209$/ {$0="%global senemos_build_release "revision;changed++}
 /^Requires: uke-kernel-update >= 1[.]8[.]100$/ {$0="Requires: uke-kernel-update >= 1.8.101";updater++}
 /^%changelog$/ {print;print "* Fri Nov 06 2026 Uke contributors - 7.3.1-"revision;print "- Connect the speaker frontend before the protected MFC/RX chain.";print "- Retain complete12209 and all protected223/VI/IMCL and boot-header gates.";print "- Require updater101 for independent matching-array CRC maintenance.";print "";next}
 {print} END {if(changed!=1 || updater!=2)exit 1}
' "$spec" > "$stage/full.spec"
install -m644 "$stage/full.spec" "$spec"
if [[ $mode == check ]];then
 printf '%s  %s\n' 5493807ca28533b0bd0caa497754d99b4d366a852047a1dfb367c46b483830cd "$owner/packaging/native/copr-migration-cohort731.sh" | sha256sum -c --strict -
 awk '/^if \[\[ \$mode == check \]\]; then$/ {copy=1;next} copy && /^fi$/ {exit} copy {print}' "$owner/packaging/native/copr-migration-cohort731.sh" | sed 's| drivers/iio/common/uke-ssc/uke-ssc.o drivers/input/misc/qcom-smp2p-switch.o| sound/soc/qcom/qdsp6/q6apm.o drivers/clk/qcom/camcc-sm7675.o drivers/iio/common/uke-ssc/uke-ssc.o drivers/input/misc/qcom-smp2p-switch.o|' > "$stage/check-packaging.sh"
 test -s "$stage/check-packaging.sh"
 source "$stage/check-packaging.sh"
 sed -i 's/Complete12204/Complete12209/g' "$output/uke-kernel-migration-check.spec"
fi
(cd "$output";sha256sum -c --strict --quiet "$stage/retained")
printf 'Complete12209 retained; protected audio route prepared for planned%s/%s.\n' "$revision" "$mode"

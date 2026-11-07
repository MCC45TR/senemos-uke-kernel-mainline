#!/usr/bin/env bash
# COPR only. Preserve the complete12210 capsule and add a static SET_CFG path.
set -Eeuo pipefail
trap 'printf "Static intent source guard failed at line%s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?Source result directory}")
revision=${2:?Unique unstable revision}
mode=${3:?check or full}
proof=${4:?Check release or admitted build}
[[ $revision == 12211 && ($mode == check || $mode == full) && $proof =~ ^[1-9][0-9]*$ ]]
commit=$(git -C "$owner" rev-parse HEAD)
stage=$(mktemp -d);trap 'find "$stage" -depth -delete' EXIT
[[ $(curl -q -fLsS --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11269366 | jq -er .state) == succeeded ]]
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
curl -q -fLsS --retry 2 --max-time 600 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11269366/senemos-uke-linux-kernel-mainline-unstable-7.3.1-12210.src.rpm -o "$stage/parent.src.rpm"
printf '%s  %s\n' 363b8e5a0b8f2e083d5ca27defc7fdb862b1c96cbff02de5cd0ae7773ae96187 "$stage/parent.src.rpm" | sha256sum -c --strict -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.1-12210 ]]
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
jq -e '.source_commit=="a9590a615547c1a95b58789c3a92a248d8d48122" and .kernel_release=="7.3.1-12210-unstable" and .speaker_protected_route_entry_layer==1 and .speaker_frontend_entry_module==17454 and .speaker_graph_open_failure_scope_layer==1 and .camcc_quarantine_s2idle_layer==1 and .speaker_gain_ceiling==223 and .speaker_protection_graph_admitted and (.speaker_physical_protection_qualified|not)' "$profile/source-composition.json" >/dev/null
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$stage/configs"
assets=(src/audio/0006-gpr-sleepable-protected-command.patch tests/audio-static-intent.c tests/audio-static-intent.sh tests/fixtures/audio-static-intent-original.h docs/STATIC-GPR-INTENT.md manifests/static-gpr-intent-20261106.json)
for tree in "$profile" "$boot";do
 for asset in "${assets[@]}";do install -Dm644 "$owner/$asset" "$tree/$asset";done
 if [[ -f $tree/tests/audio-unmap-response-contract.sh ]];then
  printf '%s  %s\n' 357891aa9a8b25cbafeab79a3b00e014191ffc069e29a33e1d4205b1228109d0 "$tree/tests/audio-unmap-response-contract.sh" | sha256sum -c --strict -
 fi
 install -Dm644 "$owner/tests/audio-unmap-response-contract.sh" "$tree/tests/audio-unmap-response-contract.sh"
 [[ $(grep -Fo uke7.3.1-12210u "$tree/src/audio/uke-audio-card.c" | wc -l) == 2 ]]
 sed "s/uke7[.]3[.]1-12210u/uke7.3.1-${revision}u/g" "$tree/src/audio/uke-audio-card.c" > "$stage/card.c"
 install -m644 "$stage/card.c" "$tree/src/audio/uke-audio-card.c"
done
cat >> "$profile/prepare.sh" <<'CHECK'
# Original cumulative preparation, protected routes and all inherited gates passed.
awk '/^int audioreach_send_cmd_sync\(/{p=1}p{print}p&&/^}/{exit}' "$kernel/sound/soc/qcom/qdsp6/audioreach.c" > "$kernel/native-generated/before-static-intent.h"
awk '/^int audioreach_send_cmd_sync\(/{p=1}p{print}p&&/^}/{exit}' "$profile/tests/fixtures/audio-static-intent-original.h" | cmp - "$kernel/native-generated/before-static-intent.h"
patch -d "$kernel" --dry-run -p1 --fuzz=0 --batch -i "$profile/src/audio/0006-gpr-sleepable-protected-command.patch"
patch -d "$kernel" -p1 --fuzz=0 --batch -i "$profile/src/audio/0006-gpr-sleepable-protected-command.patch"
for intent_cc in gcc clang;do
 for intent_san in 0 1;do CC=$intent_cc SANITIZE=$intent_san bash "$profile/tests/audio-static-intent.sh" "$kernel";done
 CC=$intent_cc bash "$profile/tests/audio-unmap-response-contract.sh" "$kernel"
done
CHECK
cp "$profile/source-composition.json" "$profile/source-composition-before-static-intent.json"
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg source "$commit" --arg revision "$revision" '.+{source_commit:$source,rpm_revision:$revision,kernel_release:("7.3.1-"+$revision+"-unstable"),diagnostic_audio_driver:("uke7_3_1-"+$revision+"u"),static_intent_parent_build:11269366,static_intent_parent_source:"a9590a615547c1a95b58789c3a92a248d8d48122",gpr_static_sleepable_set_cfg_layer:1,gpr_async_nonblocking_preserved:true,protected_parameter_records_unchanged:true,device_installation:false,physical_acceptance:false}' "$profile/source-composition-before-static-intent.json" > "$profile/source-composition.json"
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
 /^%global senemos_build_release 12210$/ {$0="%global senemos_build_release "revision;changed++}
 /^%changelog$/ {print;print "* Fri Nov 06 2026 Uke contributors - 7.3.1-"revision;print "- Negotiate remote intents for synchronous static APM configuration.";print "- Preserve complete12210, protected223 records and asynchronous transport.";print "";next}
 {print} END {if(changed!=1)exit 1}
' "$spec" > "$stage/full.spec"
install -m644 "$stage/full.spec" "$spec"
if [[ $mode == check ]];then
 printf '%s  %s\n' 5493807ca28533b0bd0caa497754d99b4d366a852047a1dfb367c46b483830cd "$owner/packaging/native/copr-migration-cohort731.sh" | sha256sum -c --strict -
 awk '/^if \[\[ \$mode == check \]\]; then$/ {copy=1;next} copy && /^fi$/ {exit} copy {print}' "$owner/packaging/native/copr-migration-cohort731.sh" | sed 's| drivers/iio/common/uke-ssc/uke-ssc.o drivers/input/misc/qcom-smp2p-switch.o| drivers/soc/qcom/apr.o sound/soc/qcom/qdsp6/audioreach.o sound/soc/qcom/qdsp6/q6apm.o drivers/clk/qcom/camcc-sm7675.o drivers/iio/common/uke-ssc/uke-ssc.o drivers/input/misc/qcom-smp2p-switch.o|' > "$stage/check-packaging.sh"
 test -s "$stage/check-packaging.sh"
 source "$stage/check-packaging.sh"
 sed -i 's/Complete12204/Complete12210/g' "$output/uke-kernel-migration-check.spec"
fi
(cd "$output";sha256sum -c --strict --quiet "$stage/retained")
printf 'Complete12210 retained; static SET_CFG intent path prepared for planned%s/%s.\n' "$revision" "$mode"

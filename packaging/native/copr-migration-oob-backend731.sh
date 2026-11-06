#!/usr/bin/env bash
# COPR only. Full mode requires the same-source qualified native receipt.
set -Eeuo pipefail
trap 'printf "OOB backend source guard failed at line%s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
(cd "$owner";jq -r ' .source_assets[]|.sha256+"  "+.path' manifests/protected-oob-backend-20261106.json | sha256sum -c --strict --quiet -)
output=$(realpath -m "${1:?Source result directory}")
revision=${2:?Planned ABI, not a reservation}
mode=${3:?check or full}
proof=${4:?Unique check release or qualified build}
[[ $revision == 12212 && ($mode == check || $mode == full) && $proof =~ ^[1-9][0-9]*$ ]]
commit=$(git -C "$owner" rev-parse HEAD)
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
[[ $(curl -q -fLsS --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11269695 | jq -er .state) == succeeded ]]
if [[ $mode == check ]];then
 [[ $# == 4 && $proof == 24 ]]
 bash "$owner/packaging/native/refuse-published-release.sh" uke-kernel-migration-check "7.3.1-$proof"
else
 [[ $# == 5 && $5 =~ ^[a-f0-9]{64}$ ]]
 curl -q -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$proof" > "$stage/proof.json"
 jq -e '.state=="succeeded" and .source_package.name=="uke-kernel-migration-check" and .source_package.version=="7.3.1-24"' "$stage/proof.json" >/dev/null
 result_url=$(curl -q -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build-chroot/$proof/fedora-rawhide-aarch64" | jq -er .result_url)
 curl -q -fLsS --max-time 90 "${result_url}uke-kernel-migration-check-7.3.1-24.fc46.aarch64.rpm" -o "$stage/proof.rpm"
 printf '%s  %s\n' "$5" "$stage/proof.rpm" | sha256sum -c --strict -
 [[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/proof.rpm") == uke-kernel-migration-check-7.3.1-24.fc46 ]]
 [[ $(rpm2cpio "$stage/proof.rpm" | cpio -i --to-stdout --quiet '*source-commit') == "$commit" ]]
 rpm2cpio "$stage/proof.rpm" | cpio -i --to-stdout --quiet '*source-composition.json' | jq -e '.protected_oob_native_backend_layer==1 and .protected_oob_supplier_readiness_before_probe and .cdsp_dma_admission_check==11270377 and (.protected_oob_native_backend_admitted|not) and (.physical_acceptance|not)' >/dev/null
 bash "$owner/packaging/native/refuse-published-release.sh" senemos-uke-linux-kernel-mainline-unstable "7.3.1-$revision"
fi
[[ ! -e $output || (-d $output && -z $(find "$output" -mindepth 1 -maxdepth 1 -print -quit)) ]]
mkdir -p "$output" "$stage/unpacked"
curl -q -fLsS --retry 2 --max-time 600 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11269695/senemos-uke-linux-kernel-mainline-unstable-7.3.1-12211.src.rpm -o "$stage/parent.src.rpm"
printf '%s  %s\n' b3ba36a2655300a3811f1a3b5071257dd92548a2a7403a104c749ccb7ffd8cdf "$stage/parent.src.rpm" | sha256sum -c --strict -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.1-12211 ]]
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
jq -e '.source_commit=="dba56903ddba878aba8db22d87a9ab130ef1e1db" and .kernel_release=="7.3.1-12211-unstable" and .gpr_static_sleepable_set_cfg_layer==1 and .gpr_async_nonblocking_preserved and .protected_parameter_records_unchanged and .speaker_gain_ceiling==223 and .speaker_protection_graph_admitted and (.speaker_physical_protection_qualified|not)' "$profile/source-composition.json" >/dev/null
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$stage/configs"
assets=(src/audio/uke-fs19xx-oob.h tests/audio-fs19xx-oob.c tests/audio-fs19xx-oob.sh
 tests/audio-fs19xx-oob-native.c docs/PROTECTED-OOB-CONFIG.md
 manifests/protected-oob-core-20261106.json manifests/kernel-package-migration.json
 manifests/kernel-migration-full12211-20261106.json docs/KERNEL-PACKAGE-MIGRATION.md
 docs/STATIC-GPR-INTENT.md tests/cdsp-pogo-config-toolchain731.sh
 tests/cdsp-pogo-toolchain-contract.sh tests/fixtures/cdsp-pogo-config-original.sh
 src/audio/0007-fs19xx-protected-oob.patch
 src/audio/uke-audio-config-memory.c
 src/audio/uke-audio-config-memory.h
 src/audio/uke-audio-config-dt.h
 src/audio/xiaomi,uke-audio-config-memory.yaml
 src/audio/uke-fs19xx-oob-backend.c
 src/audio/uke-fs19xx-oob-backend.h
 src/audio/apply-oob-backend731.sh
 packaging/native/check-oob-runtime731.sh
 packaging/native/check-oob-objects731.sh
 tests/audio-fs19xx-oob-backend.c
 tests/audio-fs19xx-oob-backend.sh
 tests/audio-config-memory.c
 tests/audio-oob-startup.c
 tests/audio-controls-only-oob731.sh
 tests/audio-config-dt.c
 tests/audio-config-dt.sh
 manifests/protected-oob-backend-20261106.json
 src/cdsp/0002-fastrpc-dma-before-session.patch
 src/cdsp/apply-dma-admission.sh
 src/cdsp/fastrpc-cb-probe731-fixed.h
 tests/fixtures/fastrpc-cb-probe731-original.h
 tests/fixtures/fastrpc-cb-dma.c
 tests/fastrpc-cb-dma-contract.sh
 tests/fastrpc-cb-dma-qualify.sh
 packaging/native/copr-cdsp-dma-check.sh
 manifests/cdsp-dma-admission-20261106.json)
for tree in "$profile" "$boot";do
 printf '%s  %s\n' 91eee9eae001c10f6a19414d24fa5c448ca8e46b10f91fa251f15491aaa276d7 "$tree/tests/audio-controls-only-contract.sh" | sha256sum -c --strict -
 for asset in "${assets[@]}";do install -Dm644 "$owner/$asset" "$tree/$asset";done
 printf '%s  %s\n' fd11aad8209533f50fa5b3a6cf90fb16c223d63bf0bfcfd7304c670e0862a2ef "$tree/tests/cdsp-pogo-config-contract.sh" | sha256sum -c --strict -
 install -m644 "$owner/tests/cdsp-pogo-config-toolchain731.sh" "$tree/tests/cdsp-pogo-config-contract.sh"
 [[ $(grep -Fo uke7.3.1-12211u "$tree/src/audio/uke-audio-card.c" | wc -l) == 2 ]]
 sed "s/uke7[.]3[.]1-12211u/uke7.3.1-${revision}u/g" "$tree/src/audio/uke-audio-card.c" > "$stage/card.c"
 install -m644 "$stage/card.c" "$tree/src/audio/uke-audio-card.c"
done
# The new exact postimage guard extends all three active runtime comparisons.
# Historical source, calibration records and all previous semantic tests stay.
(cd "$owner";jq -r '.inputs[]|.sha256+"  "+.path' manifests/cdsp-dma-admission-20261106.json | sha256sum -c --strict --quiet -)
[[ $(curl -q -fLsS --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11270347 | jq -er .state) == succeeded ]]
[[ $(curl -q -fLsS --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11270377 | jq -er .state) == succeeded ]]
for tree in "$profile" "$boot";do
 for checker in packaging/native/check-cumulative-camera731.sh packaging/native/check-speaker-inclusion.sh packaging/native/check-camera-next731.sh;do
  legacy_expected=0
  [[ $checker != packaging/native/check-cumulative-camera731.sh ]] || legacy_expected=1
  awk -v legacy_expected="$legacy_expected" '
   $0=="cmp \"$profile/src/audio/uke-fs19xx-runtime.c\" \"$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c\"" {
    print "bash \"$profile/packaging/native/check-oob-runtime731.sh\" \"$kernel\"";changed++;next
   }
   $0=="if ! cmp -s \"$profile/src/audio/uke-fs19xx-runtime.c\" \"$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c\"; then" {
    print "if ! bash \"$profile/packaging/native/check-oob-runtime731.sh\" \"$kernel\"; then";changed++;next
   }
   index($0,"bash \"$profile/tests/audio-controls-only-contract.sh\"") {sub(/audio-controls-only-contract[.]sh/,"audio-controls-only-oob731.sh");legacy++}
   {print} END {if(changed!=1||legacy!=legacy_expected){print "Unexpected runtime checker/admission fixture transformation counts: "changed"/"legacy > "/dev/stderr";exit 1}}
  ' "$tree/$checker" > "$stage/checker"
  install -m644 "$stage/checker" "$tree/$checker"
 done
done

cat >> "$profile/prepare.sh" <<'CHECK'
# Complete12211 transport/protected routes and all retained gates passed first.
install -m644 "$profile/src/audio/uke-fs19xx-oob.h" "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-oob.h"
install -m644 "$profile/tests/audio-fs19xx-oob-native.c" "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-oob-check.c"
for oob_cc in gcc clang;do
 for oob_san in 0 1;do CC=$oob_cc SANITIZE=$oob_san bash "$profile/tests/audio-fs19xx-oob.sh" "$kernel";done
done
# This bridge is compiled only by the text receipt spec, never linked/shipped.
bash "$profile/src/cdsp/apply-dma-admission.sh" "$kernel"
bash "$profile/tests/fastrpc-cb-dma-qualify.sh" "$kernel/drivers/misc/fastrpc.c"
bash "$profile/src/audio/apply-oob-backend731.sh" "$kernel" "$profile"
CHECK
cp "$profile/source-composition.json" "$profile/source-composition-before-oob-core.json"
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg source "$commit" --arg revision "$revision" --arg mode "$mode" --arg proof "$proof" '.+{source_commit:$source,rpm_revision:$revision,kernel_release:("7.3.1-"+$revision+"-unstable"),diagnostic_audio_driver:("uke7_3_1-"+$revision+"u"),oob_core_parent_build:11269695,oob_core_parent_source:"dba56903ddba878aba8db22d87a9ab130ef1e1db",protected_oob_wire_core_layer:1,protected_oob_native_backend_layer:1,protected_oob_permanent_dma_context:true,protected_oob_independent_response_port:true,protected_oob_parent_core_check:11270347,cdsp_dma_admission_layer:1,cdsp_dma_admission_code_source:"0f5eb8e6d2f2bae951a50d93f029762ba0aec443",cdsp_dma_admission_check:11270377,protected_oob_native_backend_admitted:($mode=="full"),protected_oob_supplier_readiness_before_probe:true,protected_oob_inherited_control_fixture_mock_layer:1,protected_oob_original_control_fixture_sha256:"91eee9eae001c10f6a19414d24fa5c448ca8e46b10f91fa251f15491aaa276d7",protected_oob_native_qualification_build:(if $mode=="full" then ($proof|tonumber) else null end),protected_oob_physical_activation:false,native_llvm_rpm_evr:"23.1.5-1.fc46",historical_config_compiler_identity_model:"23.1.4-1.fc46",historical_config_original_guard_sha256:"fd11aad8209533f50fa5b3a6cf90fb16c223d63bf0bfcfd7304c670e0862a2ef",device_installation:false,physical_acceptance:false}' "$profile/source-composition-before-oob-core.json" > "$profile/source-composition.json"
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
 /^%global senemos_build_release 12211$/ {$0="%global senemos_build_release "revision;changed++}
 /^%description/ && !pinned {print "BuildRequires: clang = 23.1.5-1.fc46";print "BuildRequires: llvm = 23.1.5-1.fc46";print "BuildRequires: lld = 23.1.5-1.fc46";pinned++}
 $0=="bash native-profile/tests/cdsp-pogo-config-contract.sh native-generated/nfc-cdsp-before-reference/.config" {print "bash native-profile/tests/cdsp-pogo-toolchain-contract.sh native-generated/nfc-cdsp-before-reference/.config";guard++}
 {print} END {if(changed!=1||pinned!=1||guard!=2){printf "Unexpected inherited spec counts: release=%d toolchain=%d config_checks=%d\n",changed,pinned,guard > "/dev/stderr";exit 1}}
' "$spec" > "$stage/planned.spec"
install -m644 "$stage/planned.spec" "$spec"
# Full mode repeats all source/native tests and requires actual Image linkage.
awk '
 /^%check$/ {print;print "bash native-profile/packaging/native/check-oob-objects731.sh \"$PWD\" %{_uke_out} linked";checks++;next}
 /^%changelog$/ {print;print "* Fri Nov 06 2026 Uke contributors - 7.3.1-12212";print "- Transport whole protected configuration through dedicated shared memory.";print "- Preserve cumulative features, gain223, private identity and updater101 staging.";print "";history++;next}
 {print} END {if(checks!=1||history!=1)exit 1}
' "$spec" > "$stage/audited-full.spec"
install -m644 "$stage/audited-full.spec" "$spec"
if [[ $mode == check ]];then
# Reuse the complete native-object receipt packaging; no Image or final module.
printf '%s  %s\n' 5493807ca28533b0bd0caa497754d99b4d366a852047a1dfb367c46b483830cd "$owner/packaging/native/copr-migration-cohort731.sh" | sha256sum -c --strict -
awk '/^if \[\[ \$mode == check \]\]; then$/ {copy=1;next} copy && /^fi$/ {exit} copy {print}' "$owner/packaging/native/copr-migration-cohort731.sh" | sed 's| drivers/iio/common/uke-ssc/uke-ssc.o drivers/input/misc/qcom-smp2p-switch.o| drivers/soc/qcom/apr.o sound/soc/qcom/qdsp6/audioreach.o sound/soc/qcom/qdsp6/q6apm.o drivers/clk/qcom/camcc-sm7675.o sound/soc/qcom/qdsp6/uke-fs19xx-oob-check.o sound/soc/qcom/qdsp6/uke-fs19xx-oob-backend.o sound/soc/qcom/qdsp6/snd-q6apm.o drivers/soc/qcom/uke-audio-config-memory.o drivers/misc/fastrpc.o drivers/iio/common/uke-ssc/uke-ssc.o drivers/input/misc/qcom-smp2p-switch.o|' > "$stage/check-packaging.sh"
test -s "$stage/check-packaging.sh"
source "$stage/check-packaging.sh"
awk '
 $0=="bash native-profile/packaging/native/check-migration-cohort731.sh \"$PWD\" %{_uke_out} objects" {print "bash native-profile/packaging/native/check-oob-objects731.sh \"$PWD\" %{_uke_out}";added++}
 {print} END {if(added!=1)exit 1}
' "$output/uke-kernel-migration-check.spec" > "$stage/backend-check.spec"
install -m644 "$stage/backend-check.spec" "$output/uke-kernel-migration-check.spec"
sed -i 's/Complete12204/Complete12211/g' "$output/uke-kernel-migration-check.spec"
fi
(cd "$output";sha256sum -c --strict --quiet "$stage/retained")
printf 'Complete12211 retained; OOB backend/DMA/DT and qualified FastRPC prepared for%s. No target operation or stable promotion.\n' "$mode"

#!/usr/bin/env bash
# COPR only: compose CDSP/pogo, RTC, display and Android networking with NFC repair.
set -Eeuo pipefail
trap 'status=$?; printf "NFC cohort preparation failed at line %s (exit %s)\n" "$LINENO" "$status" >&2; exit "$status"' ERR
export LC_ALL=C
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 2 && $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
output=$(realpath -m "$1")
revision=$2
[[ $revision =~ ^[1-9][0-9]{3,4}$ && $revision -ge 10000 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
bash "$owner/packaging/native/refuse-published-release.sh" senemos-uke-linux-kernel-mainline-unstable "7.3.1-$revision"
for build in 11259919 11259981 11259990 11260104; do
 state=$(curl -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$build" | jq -er .state)
 [[ $state == succeeded || ( $build == 11260104 && $state == running ) ]] || {
  printf 'Required parent %s is %s\n' "$build" "$state" >&2; exit 1;
 }
done
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
mkdir -p "$output" "$stage/base" "$stage/reference" "$stage/hsic" "$stage/network"
download()
{
 local build=$1 project=$2 version=$3 header=$4 payload=$5 destination=$6
 curl -fLsS --retry 2 --max-time 300 --proto '=https' --proto-redir '=https' \
  "https://download.copr.fedorainfracloud.org/results/mcc45tr/$project/srpm-builds/$build/senemos-uke-linux-kernel-mainline-unstable-7.3.1-$version.src.rpm" \
  -o "$destination"
 [[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$destination") == senemos-uke-linux-kernel-mainline-unstable-7.3.1-$version ]]
 [[ $(rpm -qp --qf '%{SHA256HEADER}' "$destination") == "$header" ]]
 [[ $(rpm -qp --qf '%{PAYLOADSHA256}' "$destination") == "$payload" ]]
 rpmkeys --checksig --nosignature --verbose "$destination"
 printf 'Qualified source %s full SRPM SHA-256: ' "$build"
 sha256sum "$destination"
}
download 11259990 uke-linux-unstable:custom:cdsp-pogo-20261104 7603 \
 b9388b0260a1b0ecef0dc8204bc5d611de26d71c701a070dab7d397b9ce484fe \
 dd01f4b3cfc738af3498350d84a1297d9fea6f287647c42832c5e59d3a5f9508 "$stage/base.src.rpm"
download 11259919 uke-linux-unstable 7300 \
 2538f7e4027ca8f926cf2ccd965715a6d080835443d2bafec41b96ccaab6c250 \
 147edc8fae715ba6e8beb958fc6873df8ab60c7439f74831bb58154c56de0d49 "$stage/reference.src.rpm"
download 11259981 uke-linux-unstable 7600 \
 7739f4904aadade290e07c5a6d1a62bc8cc7ffb27388ab9262047109620871c7 \
 f79698295eccf5f91d00ece39102c0120f2b6e338824563284f1b1ac9f04745b "$stage/hsic.src.rpm"
download 11260104 uke-linux-unstable 8200 \
 60077d6548a0928cfd4104616a2a088a3949822bb6f18edd8ae3c8653a00c839 \
 ccfc9efd9b347d83c8067a1b842992f155a78366d10ae2e00f25c507b463b269 "$stage/network.src.rpm"
base_sha=$(sha256sum "$stage/base.src.rpm" | cut -d ' ' -f1)
reference_sha=$(sha256sum "$stage/reference.src.rpm" | cut -d ' ' -f1)
hsic_sha=$(sha256sum "$stage/hsic.src.rpm" | cut -d ' ' -f1)
network_sha=$(sha256sum "$stage/network.src.rpm" | cut -d ' ' -f1)
printf '%s  %s\n' \
 163d3d26bf61e4f27537f760517054fac126b7d06f49a14eb69ab8cb67a3216d "$stage/base.src.rpm" \
 4cc89bc2d5fb99a76a2d4db9b3ec983fd03ad88d4cdbf2c9c7e7bff77edebd03 "$stage/reference.src.rpm" \
 9d91aa697fff83edf361e302b4b0c47d1601daba7a6c1ce8219a058677cf884d "$stage/hsic.src.rpm" \
 7ec21b063bd3d639b3c11e691d41f902081213a14c07e8d079ec6cbc7995fcbc "$stage/network.src.rpm" \
 | sha256sum -c --strict
for role in base reference hsic network; do
 rpm2cpio "$stage/$role.src.rpm" > "$stage/$role.cpio"
 cpio -t --quiet < "$stage/$role.cpio" > "$stage/entries"
 awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/entries"
 if [[ $role == base ]]; then
  (cd "$output"; cpio -idm --quiet --no-absolute-filenames < "$stage/$role.cpio")
  archives=$output
 else
  mkdir "$stage/$role-sources"
  printf 'Reference source members (%s):\n' "$role"
  cat "$stage/entries"
  (cd "$stage/$role-sources"; cpio -idm --quiet --no-absolute-filenames < "$stage/$role.cpio")
  archives=$stage/$role-sources
 fi
 for archive in senemos-native-profile-7.3.1.tar.xz senemos-uke-boot-recipe.tar.xz; do
  tar -tJf "$archives/$archive" > "$stage/entries"
  awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/entries"
  tar -xJf "$archives/$archive" -C "$stage/$role"
 done
 (cd "$stage/$role/native-profile"; sha256sum --check --strict --quiet SHA256SUMS)
 (cd "$stage/$role/boot-recipe"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
done
profile=$stage/base/native-profile
boot=$stage/base/boot-recipe
reference=$stage/reference/native-profile
hsic=$stage/hsic/native-profile
network=$stage/network/native-profile
spec=$output/senemos-uke-linux-kernel-mainline-unstable.spec
# Prove the reported ownership failure before attempting composition changes.
probe=$stage/wakeup-probe
mkdir "$probe"
tar -xJf "$output/linux-7.3.1.tar.xz" --strip-components=1 -C "$probe" \
 linux-7.3.1/include/linux/pm_wakeup.h linux-7.3.1/drivers/base/power/wakeup.c \
 linux-7.3.1/drivers/base/power/wakeirq.c linux-7.3.1/drivers/i2c/i2c-core-base.c \
 linux-7.3.1/drivers/i2c/i2c-core-of.c
for compiler in gcc clang; do
 CC=$compiler bash "$owner/tests/fm19511-wakeup-owner-regression.sh" "$probe"
 CC=$compiler FM19511_WAKEUP_TEST_FLAGS='-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer' \
  bash "$owner/tests/fm19511-wakeup-owner-regression.sh" "$probe"
done
cmp "$boot/lock.json" "$output/boot-payload.json"
jq -e '.kernel_release=="7.3.1-7603-unstable" and
 .source_commit=="599d135814c6871c2dcb0301970236dd4151d6dc" and
 .parent_copr_build==11259638 and .diagnostic_camera_stage==0 and .diagnostic_pstore_panic_layout and
 .cdsp_start_stop_retention and .cdsp_permanent_platform_instance and
 .cdsp_pogo_config_delta==["CONFIG_HID_NANOSIC_UKE=m"] and
 (.front_eeprom_dt_activation|not) and (.camera_capture_graph_activation|not) and
 .nfc_atomic_memory_read and .native_nfc_ir_access_abi==1 and .ir_explicit_word_bits==16' \
 "$profile/source-composition.json" >/dev/null
jq -e '.kernel_release=="7.3.1-7300-unstable" and
 .diagnostic_producer_commit=="00ebf622ca473b9b7a799b2f531b4871ddc70497" and
 .rtc_backend=="pmic-read-only-counter" and (.rtc_secure_offset_boot_activation|not) and
 (.rtc_utc_calendar_qualified|not)' "$reference/source-composition.json" >/dev/null
jq -e '.kernel_release=="7.3.1-7600-unstable" and
 .source_commit=="16f178ed5e4d513b1d9a415c16c181fb9bf35a0e" and
 .parent_copr_build==11259638 and .o82_hsic_software_support and
 .o82_private_color_bundle_version==4 and .o82_color_initial_preset=="" and
 (.o82_color_dma_enabled|not) and (.physical_acceptance|not)' "$hsic/source-composition.json" >/dev/null
jq -e '.kernel_release=="7.3.1-8200-unstable" and
 .waydroid_network_producer_commit=="7ca15872cb06dc6263ac366bc50dec4439149b9a" and
 .waydroid_network_overlay and .waydroid_policy_routing_builtin and .waydroid_legacy_filter_builtin and
 (.waydroid_network_runtime_qualified|not) and .diagnostic_camera_stage==0 and
 .rtc_backend=="pmic-read-only-counter"' "$network/source-composition.json" >/dev/null
base_snapshot=$(jq -er .parent_composition "$profile/source-composition.json")
hsic_snapshot=$(jq -er .parent_composition "$hsic/source-composition.json")
for snapshot in "$base_snapshot" "$hsic_snapshot"; do
 [[ $snapshot =~ ^source-composition-[a-zA-Z0-9_-]+[.]json$ ]]
done
cmp <(jq -S . "$profile/$base_snapshot") <(jq -S . "$hsic/$hsic_snapshot")
hsic_manifest=manifests/o82-hsic-unstable-source-20261104.json
cmp "$hsic/$hsic_manifest" "$owner/manifests/nfc-hsic-reference7600.json"
(cd "$hsic"; jq -r '.imports[]|.sha256+"  "+.path' "$hsic_manifest" | sha256sum -c --strict --quiet -)
(cd "$reference"; sha256sum -c --strict "$owner/manifests/nfc-rtc-reference7300.sha256")
(cd "$profile"; sha256sum -c --strict "$owner/manifests/nfc-rtc-merge-before.sha256")
cmp "$profile/src/nfc/fm19511-uke.c" "$owner/tests/fixtures/fm19511-before-wakeup-owner.c"
printf '%s  %s\n' 076a178ea5eb19702f5190bff1f4805fe3c94e5dc7945061ecdf81d49b25134a \
 "$profile/src/nfc/fm19511-uke.c" | sha256sum -c --strict
find "$output" -maxdepth 1 -type f ! -name "$(basename "$spec")" \
 ! -name senemos-native-profile-7.3.1.tar.xz ! -name senemos-uke-boot-recipe.tar.xz \
 ! -name boot-payload.json -print0 | sort -z | xargs -0 sha256sum > "$stage/sources-retained.sha256"
cat > "$stage/nfc-assets" <<'FILES'
src/nfc/fm19511-uke.c
tests/fm19511-wakeup-owner-regression.sh
tests/fixtures/fm19511-before-wakeup-owner.c
tests/fixtures/fm19511-wakeup-owner-check.c
docs/FM19511-I2C-WAKEUP.md
tests/nfc-cohort-config731.sh
FILES
cat > "$stage/rtc-assets" <<'FILES'
src/boot/uke-rtc.h
patches/rtc/0001-uke-secure-rtc-offset.patch
tests/rtc-secure-contract.sh
tests/rtc-fdt-contract.sh
docs/RTC-COUNTER-GATE.md
FILES
cat > "$stage/network-assets" <<'FILES'
configs/waydroid-network.config
tests/native-firewall-contract.sh
tests/native-firewall-builtins-contract.sh
tests/waydroid-network-built731.sh
FILES
jq -r '.imports[].path' "$hsic/$hsic_manifest" > "$stage/hsic-assets"
while read -r path; do
 [[ $path =~ ^(src/display|patches/display|tests)/[a-zA-Z0-9_,./-]+$ && $path != *..* ]]
 cmp "$hsic/$path" "$stage/hsic/boot-recipe/$path"
done < "$stage/hsic-assets"
cat "$stage/nfc-assets" "$stage/rtc-assets" "$stage/hsic-assets" "$stage/network-assets" > "$stage/overlays"
printf '%s\n' "$hsic_manifest" >> "$stage/overlays"
# Preserve both reviewed input configurations. Final Kconfig checks independently
# resolve the old CDSP input and the Android-network reference on prepared sources.
install -Dm644 "$profile/native.config" "$profile/configs/nfc-cdsp-reference.config"
install -Dm644 "$network/native.config" "$profile/configs/nfc-waydroid-reference.config"
awk -F= '/^CONFIG_/ {print $1} END {print "CONFIG_HID_NANOSIC_UKE"}' \
 "$network/configs/waydroid-network.config" > "$stage/config-keys"
for role in cdsp network; do
 input=$profile/native.config
 [[ $role != network ]] || input=$network/native.config
 awk 'FNR==NR {keys[$0]=1;next}
 /^CONFIG_/ {split($0,a,"=");if(a[1] in keys)next}
 /^# CONFIG_.* is not set$/ {if($2 in keys)next} {print}' \
 "$stage/config-keys" "$input" > "$stage/$role.retained-config"
done
cmp "$stage/cdsp.retained-config" "$stage/network.retained-config"
sed '/^CONFIG_HID_NANOSIC_UKE=/d; /^# CONFIG_HID_NANOSIC_UKE is not set$/d' \
 "$network/native.config" > "$stage/native.config"
printf '%s\n' CONFIG_HID_NANOSIC_UKE=m >> "$stage/native.config"
[[ $(jq -r .native_config_sha256 "$profile/source-composition.json") == "$(sha256sum "$profile/native.config" | cut -d ' ' -f1)" ]]
for tree in "$profile" "$boot"; do
 (cd "$tree"; while read -r path; do
  case $path in SHA256SUMS|source-commit|source-composition.json|lock.json|native.config|packaging/native/native.config|src/boot/uke-abl.c|src/audio/uke-audio-card.c) continue;; esac
  grep -Fxq "$path" "$stage/overlays" || sha256sum "$path"
 done < <(find . -type f -printf '%P\n' | sort)) > "$stage/tree-retained.sha256"
 while read -r hash path; do
  [[ ! -e $tree/$path ]] || printf '%s  %s\n' "$hash" "$tree/$path" | sha256sum -c --strict
 done < "$owner/manifests/nfc-rtc-merge-before.sha256"
 while read -r path; do install -Dm644 "$hsic/$path" "$tree/$path"; done < "$stage/hsic-assets"
 while read -r path; do
  [[ $tree == "$profile" || $path == tests/native-firewall-contract.sh ]] || continue
  install -Dm644 "$network/$path" "$tree/$path"
 done < "$stage/network-assets"
 if [[ $tree == "$profile" ]]; then
  install -m644 "$stage/native.config" "$tree/native.config"
 else
  install -m644 "$stage/native.config" "$tree/packaging/native/native.config"
 fi
 [[ $tree != "$profile" ]] || install -Dm644 "$hsic/$hsic_manifest" "$tree/$hsic_manifest"
 while read -r path; do
  if [[ $tree == "$boot" && $path == docs/RTC-COUNTER-GATE.md ]]; then continue; fi
  install -Dm644 "$reference/$path" "$tree/$path"
 done < "$stage/rtc-assets"
 if [[ -f $tree/src/boot/uke-abl.c ]]; then
  [[ $(grep -Fc 'ret = uke_rtc_secure_offset(output);' "$tree/src/boot/uke-abl.c") == 1 ]]
  sed -i 's/ret = uke_rtc_secure_offset(output);/ret = uke_rtc_counter_only(output);/' "$tree/src/boot/uke-abl.c"
 fi
 path=$tree/src/audio/uke-audio-card.c
 if [[ -f $path ]]; then
  [[ $(grep -Fo 'uke7.3.1-7603u' "$path" | wc -l) == 2 ]]
  audio_release=7.3.1-$revision"u"
  sed -i "s/uke7[.]3[.]1-7603u/uke$audio_release/g" "$path"
 fi
 # Only the profile compiles this driver; preserve absent boot-recipe assets.
 if [[ $tree == "$profile" ]]; then
  while read -r path; do install -Dm644 "$owner/$path" "$tree/$path"; done < "$stage/nfc-assets"
 elif [[ -f $tree/src/nfc/fm19511-uke.c ]]; then
  cmp "$tree/src/nfc/fm19511-uke.c" "$owner/tests/fixtures/fm19511-before-wakeup-owner.c"
  install -m644 "$owner/src/nfc/fm19511-uke.c" "$tree/src/nfc/fm19511-uke.c"
 fi
 (cd "$tree"; sha256sum -c --strict --quiet "$stage/tree-retained.sha256")
done
{
 cat "$stage/rtc-assets" "$stage/hsic-assets"
 printf '%s\n' src/boot/uke-abl.c src/audio/uke-audio-card.c src/nfc/fm19511-uke.c \
  tests/native-firewall-contract.sh packaging/native/native.config
} | while read -r path; do
 test -f "$boot/$path" || continue
 hash=$(sha256sum "$boot/$path" | cut -d ' ' -f1)
 jq --arg path "$path" --arg hash "$hash" '.source_assets |=
  (map(select(.path!=$path))+[{path:$path,sha256:$hash}])' "$boot/lock.json" > "$stage/lock.json"
 install -m644 "$stage/lock.json" "$boot/lock.json"
done
cmp "$profile/native.config" "$boot/packaging/native/native.config"
config_sha=$(sha256sum "$profile/native.config" | cut -d ' ' -f1)
nfc_sha=$(sha256sum "$profile/src/nfc/fm19511-uke.c" | cut -d ' ' -f1)
cp "$profile/source-composition.json" "$profile/source-composition-before-nfc-wakeup.json"
commit=$(git -C "$owner" rev-parse HEAD)
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg commit "$commit" --arg revision "$revision" --arg base "$base_sha" --arg reference "$reference_sha" \
 --arg hsic_sha "$hsic_sha" --arg nfc_sha "$nfc_sha" --arg network_sha "$network_sha" \
 --arg config_sha "$config_sha" --rawfile overlays "$stage/overlays" \
 --slurpfile rtc "$reference/source-composition.json" --slurpfile hsic "$hsic/source-composition.json" '
 del(.qualified_o82_kms_check,.qualified_o82_source_commit,
     .qualified_o82_sixzone_utility_check,.qualified_o82_sixzone_utility_source) +
 ($hsic[0]|with_entries(select(.key|test("^(o82_|historical_o82_|qualified_o82_)")))) + {
 source_commit:$commit,source_mode:"rtc7300-hsic7600-cdsp7603-network8200-with-i2c-owned-nfc-wakeup",
 kernel_release:("7.3.1-"+$revision+"-unstable"),rpm_revision:$revision,
 parent_copr_build:11259990,parent_srpm_sha256:$base,parent_composition:"source-composition-before-nfc-wakeup.json",
 nfc_o82_reference_build:11259981,nfc_o82_reference_source:"16f178ed5e4d513b1d9a415c16c181fb9bf35a0e",
 nfc_o82_reference_srpm_sha256:$hsic_sha,
 nfc_rtc_reference_build:11259919,nfc_rtc_reference_source:"00ebf622ca473b9b7a799b2f531b4871ddc70497",
 nfc_rtc_reference_srpm_sha256:$reference,
 nfc_network_reference_build:11260104,nfc_network_reference_source:"7ca15872cb06dc6263ac366bc50dec4439149b9a",
 nfc_network_reference_srpm_sha256:$network_sha,native_config_sha256:$config_sha,
 waydroid_network_overlay:true,waydroid_policy_routing_builtin:true,waydroid_legacy_filter_builtin:true,
 waydroid_network_runtime_qualified:false,kernel_driver_source_unchanged:false,
 diagnostic_audio_driver:("uke7_3_1-"+$revision+"u"),
 rtc_backend:$rtc[0].rtc_backend,rtc_secure_offset_boot_activation:false,
 rtc_secure_provider_qualified:false,rtc_utc_calendar_qualified:false,
 rtc_initial_calendar_invalid:false,rtc_offset_write_readback:false,
 nfc_wakeup_owner:"i2c-core",nfc_wake_irq_owner:"i2c-core",
 nfc_probe_duplicate_wakeup_registration:false,
 nfc_wakeup_driver_sha256:$nfc_sha,
 nfc_wakeup_before_sha256:"076a178ea5eb19702f5190bff1f4805fe3c94e5dc7945061ecdf81d49b25134a",
 overlays:($overlays|split("\n")|map(select(length>0))|unique),
 package_family:"senemos-uke-linux-kernel-mainline-unstable",kernel_abi_suffix:"-unstable",normal_kernel_promotion:false,
 changed_kernel_files:((.changed_kernel_files+["drivers/misc/fm19511-uke.c",
  "sound/soc/qcom/uke-audio-card.c","drivers/rtc/rtc-pm8xxx.c",
  "arch/arm64/kernel/uke-rtc.h","arch/arm64/kernel/uke-abl.c"])|unique),
 physical_acceptance:false,device_installation:false}' \
 "$profile/source-composition-before-nfc-wakeup.json" > "$profile/source-composition.json"
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
install -m644 "$boot/lock.json" "$output/boot-payload.json"
for tree in native-profile boot-recipe; do
 archive=senemos-native-profile-7.3.1.tar.xz
 [[ $tree != boot-recipe ]] || archive=senemos-uke-boot-recipe.tar.xz
 tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
  -cJf "$output/$archive" -C "$stage/base" "$tree"
done
cat > "$stage/color-checks" <<'CHECKS'
bash native-profile/tests/o82-profile-loader-contract.sh native-profile
bash native-profile/tests/o82-lutbus-contract.sh
bash native-profile/tests/o82-regdma-transport-contract.sh native-profile "$PWD"
bash native-profile/tests/o82-atomic-contract.sh native-profile "$PWD"
bash native-profile/tests/o82-atomic-package-contract.sh "$PWD" %{_uke_out}
CHECKS
: > "$stage/missing-color-checks"
while IFS= read -r command; do
 prefix=$(cut -d ' ' -f1-2 <<< "$command")
 count=$(awk -v command="$prefix" '
  /^%(prep|build|install|check|files|changelog)([[:space:]]|$)/ {active=($0=="%check")}
  active && ($0==command || index($0,command" ")==1) {n++}
  END {print n+0}' "$spec")
 [[ $count == 0 || $count == 1 ]]
 [[ $count == 1 ]] || printf '%s\n' "$command" >> "$stage/missing-color-checks"
done < "$stage/color-checks"
day=$(date -u --date="@$epoch" '+%a %b %d %Y')
awk -v revision="$revision" -v day="$day" -v color="$stage/missing-color-checks" '
 BEGIN {while((getline line < color)>0) extra[++nc]=line;close(color)}
 /^%global senemos_build_release 7603$/ {$0="%global senemos_build_release " revision;n++}
 /^%build$/ {
  print "CC=clang bash native-profile/tests/o82-avr-contract.sh \"$PWD\""
  print "CXX=clang++ bash native-profile/tests/dpu-video-timing-contract.sh \"$PWD\""
  print "CC=clang bash native-profile/tests/msm-retirement-proof-contract.sh \"$PWD\""
  print "CC=clang bash native-profile/tests/dpu-reservation-contract.sh \"$PWD\" \"$PWD/native-generated/dpu-reservation-before56\""
  print "CC=clang bash native-profile/tests/dpu-color-topology-contract.sh \"$PWD/drivers/gpu/drm/msm/disp/dpu1/dpu_crtc.c\""
  print "bash native-profile/tests/o82-profile-loader-contract.sh native-profile"
  print "bash native-profile/tests/o82-lutbus-contract.sh"
  print "bash native-profile/tests/o82-regdma-transport-contract.sh native-profile \"$PWD\""
  print "bash native-profile/tests/o82-atomic-contract.sh native-profile \"$PWD\""
  print
  print "for role in cdsp waydroid; do"
  print "  ref=\"$PWD/native-generated/nfc-$role-reference\""
  print "  mkdir -p \"$ref\""
  print "  cp \"native-profile/configs/nfc-$role-reference.config\" \"$ref/.config\""
  print "  make -s O=\"$ref\" ARCH=arm64 LLVM=1 LLVM_IAS=1 olddefconfig"
  print "done"
  print "CC=clang bash native-profile/tests/fm19511-wakeup-owner-regression.sh \"$PWD\""
  print "CC=clang FM19511_WAKEUP_TEST_FLAGS='\''-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer'\'' bash native-profile/tests/fm19511-wakeup-owner-regression.sh \"$PWD\""
  next
 }
 /^%check$/ {
  checking=1
  print
  print "cmp native-profile/src/nfc/fm19511-uke.c drivers/misc/fm19511-uke.c"
  print "grep -Fx CONFIG_PM_SLEEP=y %{_uke_out}/.config"
  print "test -s %{_uke_out}/drivers/misc/fm19511-uke.o"
  print "llvm-nm -u %{_uke_out}/drivers/misc/fm19511-uke.o > native-generated/fm19511-undefined.txt"
  print "if grep -Eq '\'' (device_wakeup_enable|device_wakeup_disable|dev_pm_set_wake_irq|dev_pm_clear_wake_irq)$'\'' native-generated/fm19511-undefined.txt; then exit 1; fi"
  print "grep -Eq '\'' pm_wakeup_dev_event$'\'' native-generated/fm19511-undefined.txt"
  print "bash native-profile/tests/native-firewall-builtins-contract.sh native-profile/tests/native-firewall-contract.sh native-profile/configs/nfc-cdsp-reference.config"
  print "bash native-profile/tests/waydroid-network-built731.sh %{_uke_out} native-profile/configs/waydroid-network.config"
  print "bash native-profile/tests/nfc-cohort-config731.sh %{_uke_out}/.config native-generated/nfc-waydroid-reference/.config"
  next
 }
 /^bash native-profile\/tests\/cdsp-pogo-config-contract[.]sh / {
  print "bash native-profile/tests/cdsp-pogo-config-contract.sh native-generated/nfc-cdsp-reference/.config";configchecks++;next
 }
 checking && /^%files($|[[:space:]])/ {for(i=1;i<=nc;i++)print extra[i];checking=0}
 /^%changelog$/ {
  print;print "* " day " MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-" revision
  print "- Preserve qualified CDSP/pogo, display color and read-only RTC admission."
  print "- Leave NFC wake source and wake IRQ lifetime with the I2C core."
  print "";next
 }
 {print}
 END {if(n!=1 || configchecks!=1)exit 1}
' "$spec" > "$stage/next.spec"
install -m644 "$stage/next.spec" "$spec"
bash "$owner/packaging/native/date-cohort-changelog.sh" "$spec" "$revision" "$epoch"
sha256sum -c --strict --quiet "$stage/sources-retained.sha256"
bash "$profile/tests/unstable-boot-family731-contract.sh" "$spec"
set +e
parsed=$(rpmspec --target aarch64 --define 'dist %{nil}' -q --srpm --qf '%{VERSION}-%{RELEASE}' "$spec" 2>"$stage/spec-errors")
status=$?
set -e
cat "$stage/spec-errors" >&2
[[ $status == 0 && $parsed == 7.3.1-$revision ]]
if grep -q '^error:' "$stage/spec-errors"; then exit 1; fi
# Source generation may qualify NFC while the independent network build finishes.
# Publish nothing until every referenced native build has actually succeeded.
deadline=$((SECONDS + 1200))
while :; do
 state=$(curl -fLsS --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11260104 | jq -er .state)
 [[ $state != succeeded ]] || break
 [[ $state == running && $SECONDS -lt $deadline ]] || {
  printf 'Network parent not qualified for publication: %s\n' "$state" >&2; exit 1;
 }
 printf 'NFC callback regression passed; waiting for network parent11260104\n'
 sleep 15
done
printf 'Qualified NFC wake ownership cohort %s; CDSP/pogo and RTC reference retained\n' "$revision"
rpmbuild -bs --define 'dist %{nil}' --define "_sourcedir $output" --define "_srcrpmdir $output" "$spec"

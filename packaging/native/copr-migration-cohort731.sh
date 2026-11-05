#!/usr/bin/env bash
# COPR only. Extend the complete12204 SRPM; never reconstruct a sparse kernel.
set -Eeuo pipefail
trap 'rc=$?; printf "Migration cohort preparation failed at line%s/exit%s\n" "$LINENO" "$rc" >&2; exit "$rc"' ERR
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR source result directory}")
revision=${2:?unique unstable revision}
mode=${3:?check or full}
proof=${4:?check release, or qualified check build for full}
[[ $revision =~ ^[1-9][0-9]{4}$ && ($mode == check || $mode == full) && $proof =~ ^[1-9][0-9]*$ ]]
plan=$owner/packaging/native/migration-cohort-inputs731.json
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
commit=$(git -C "$owner" rev-parse HEAD)
for build in $(jq -er '.required_checks[]' "$plan"); do
 [[ $(curl -q -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$build" | jq -er .state) == succeeded ]]
done
if [[ $mode == full ]]; then
 [[ $# == 5 && $5 =~ ^[a-f0-9]{64}$ ]]
 curl -q -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$proof" > "$stage/proof.json"
 jq -e '.state=="succeeded" and .source_package.name=="uke-kernel-migration-check"' "$stage/proof.json" >/dev/null
 curl -q -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build-chroot/$proof/fedora-rawhide-aarch64" > "$stage/chroot.json"
 url=$(jq -er .result_url "$stage/chroot.json")
 evr=$(jq -er .source_package.version "$stage/proof.json")
 curl -q -fLsS --max-time 90 "${url}uke-kernel-migration-check-$evr.fc46.aarch64.rpm" -o "$stage/proof.rpm"
 printf '%s  %s\n' "$5" "$stage/proof.rpm" | sha256sum -c --strict -
 rpm2cpio "$stage/proof.rpm" | cpio -i --to-stdout --quiet '*source-commit' > "$stage/proof.commit"
 [[ $(cat "$stage/proof.commit") == "$commit" ]]
 bash "$owner/packaging/native/refuse-published-release.sh" senemos-uke-linux-kernel-mainline-unstable "7.3.1-$revision"
else
 [[ $# == 4 ]]
 bash "$owner/packaging/native/refuse-published-release.sh" uke-kernel-migration-check "7.3.1-$proof"
fi
[[ ! -e $output || (-d $output && -z $(find "$output" -mindepth 1 -maxdepth 1 -print -quit)) ]]
mkdir -p "$output" "$stage/unpacked"
curl -q -fLsS --retry 2 --max-time 600 --proto '=https' --proto-redir '=https' \
 "$(jq -er .parent.url "$plan")" -o "$stage/parent.src.rpm"
printf '%s  %s\n' "$(jq -er .parent.sha256 "$plan")" "$stage/parent.src.rpm" | sha256sum -c --strict -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.1-12204 ]]
rpmkeys --checksig --nosignature --verbose "$stage/parent.src.rpm"
rpm2cpio "$stage/parent.src.rpm" > "$stage/parent.cpio"
cpio -t --quiet < "$stage/parent.cpio" | awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}'
(cd "$output"; cpio -idm --quiet --no-absolute-filenames < "$stage/parent.cpio")
native=senemos-native-profile-7.3.1.tar.xz
boot_archive=senemos-uke-boot-recipe.tar.xz
spec=$output/senemos-uke-linux-kernel-mainline-unstable.spec
find "$output" -maxdepth 1 -type f ! -name "${spec##*/}" ! -name "$native" \
 ! -name "$boot_archive" ! -name boot-payload.json -print0 | sort -z | xargs -0 sha256sum > "$stage/retained-sources"
for archive in "$native" "$boot_archive"; do tar -xJf "$output/$archive" -C "$stage/unpacked"; done
profile=$stage/unpacked/native-profile
boot=$stage/unpacked/boot-recipe
(cd "$profile"; sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
jq -e '.source_commit=="de1bdf9ab531d772a8c02847c51b01ed4ffcd42f" and .kernel_release=="7.3.1-12204-unstable"' "$profile/source-composition.json" >/dev/null
while IFS=$'\t' read -r role pin; do
 [[ $pin =~ ^[a-f0-9]{40}$ ]]
 git -C "$owner" fetch -q --depth 1 origin "$pin"
 git -C "$owner" worktree add --quiet --detach "$stage/$role" "$pin"
done < <(jq -er '.roles|to_entries[]|[.key,.value]|@tsv' "$plan")
git -C "$owner" fetch -q --depth 1 origin 33a5dc574401b67472e9bea65e5ff7084635f601
# All helpers authenticate their original preimages and retain every peer byte.
bash "$stage/als/packaging/native/overlay-ssc-als731.sh" "$profile" "$boot"
bash "$stage/als/packaging/native/overlay-ssc-rear-als731.sh" "$profile" "$boot"
bash "$stage/audio/packaging/native/overlay-speaker-protected-layer.sh" "$profile" "$(jq -er .roles.audio "$plan")"
bash "$stage/audio/packaging/native/overlay-speaker-protected-spec.sh" "$spec"
for tree in "$profile" "$boot"; do
 printf '%s  %s\n' 7295cad2448f6d4cc814670cefacc413b56a20b39ac36e2c756241be2125fc04 \
  "$tree/src/sensors/uke-ssc-iio.c" | sha256sum -c --strict -
 (cd "$tree"; patch --dry-run -p1 --fuzz=0 --batch -i "$owner/src/sensors/0003-ssc-mount-matrix.patch")
 (cd "$tree"; patch -p1 --fuzz=0 --batch -i "$owner/src/sensors/0003-ssc-mount-matrix.patch")
 printf '%s  %s\n' c7a271fb57d329cdbc31f0d8876af4c4ef95ee16e880137e7fd003a8f45630fd \
  "$tree/src/sensors/uke-ssc-iio.c" | sha256sum -c --strict -
done
own_assets=(src/boot/uke-hardware.h src/boot/bindings/firmware/xiaomi,uke-ssc-sensors.yaml
 tests/ssc-native-host.h tests/hardware-dt.cpp tests/ssc-mount-matrix.c tests/ssc-mount-matrix.sh
 tests/ssc-als-vector-contract.c tests/ssc-als-vector-contract.sh tests/ssc-rear-als-contract.c tests/ssc-rear-als-contract.sh
 packaging/native/check-migration-cohort731.sh packaging/native/prepare-migration-manager731.sh
 packaging/native/check-migration-boot-config731.sh tests/migration-boot-config-boundary731.sh)
for path in "${own_assets[@]}"; do install -Dm644 "$owner/$path" "$profile/$path"; done
for path in configs/kernel-manager/resources.config configs/kernel-manager/resource-dependencies.txt \
 packaging/native/apply-kernel-manager-config.sh tests/kernel-manager-config-contract.sh; do
 install -Dm644 "$stage/manager/$path" "$profile/$path"
done
while read -r path; do install -Dm644 "$stage/hall/$path" "$profile/$path"; done \
 < <(jq -er '.inputs[].path' "$stage/hall/manifests/hall-startup-20261105.json")
# Preserve old full reference configurations; only the actual production input changes.
install -Dm644 "$profile/native.config" "$profile/configs/migration-before-native.config"
printf '%s  %s\n' e0bad377ea2719e00eb2a5b2a3b38fc05d32d23e52cd0f8466905c204c32bc4a \
 "$profile/configs/migration-before-native.config" | sha256sum -c --strict -
mkdir -p "$stage/config-tool/scripts"
tar -xOJf "$output/linux-7.3.1.tar.xz" linux-7.3.1/scripts/config > "$stage/config-tool/scripts/config"
bash "$stage/manager/packaging/native/apply-kernel-manager-config.sh" "$stage/config-tool" \
 "$profile/native.config" "$stage/new-native.config" "$stage/manager/configs/kernel-manager/resources.config"
install -m644 "$stage/new-native.config" "$profile/native.config"
install -m644 "$stage/new-native.config" "$boot/packaging/native/native.config"
native_sha=$(sha256sum "$profile/native.config"); native_sha=${native_sha%% *}
# Extend only the exact expectations changed by the admitted resources/protected layer.
for path in packaging/native/check-cumulative-camera731.sh packaging/native/check-camera-next731.sh; do
 install -Dm644 "$profile/$path" "$profile/history-before-migration/$path"
 [[ $(grep -Fc '.speaker_protection_graph_admitted==false' "$profile/$path") == 1 ]]
 sed 's/\.speaker_protection_graph_admitted==false/.speaker_protection_graph_admitted==true and .speaker_protected_layer_commit=="c2932addf1f9b885a9a559b40d1ce5b7d43fe98b"/' \
  "$profile/$path" > "$stage/checker"
 install -m644 "$stage/checker" "$profile/$path"
done
checker=$profile/packaging/native/check-cumulative-camera731.sh
[[ $(grep -Fc 739882b3a07fc6a701bae81ac6623a4b576871bd4289de3a095acabc20d49d34 "$checker") == 1 ]]
[[ $(grep -Fc e0bad377ea2719e00eb2a5b2a3b38fc05d32d23e52cd0f8466905c204c32bc4a "$checker") == 1 ]]
sed -e "s/739882b3a07fc6a701bae81ac6623a4b576871bd4289de3a095acabc20d49d34/$native_sha/" \
 -e "s/e0bad377ea2719e00eb2a5b2a3b38fc05d32d23e52cd0f8466905c204c32bc4a/$native_sha/" \
 -e 's|"$profile/configs/governor-before-native.config" "$profile/native.config"|"$profile/configs/governor-before-native.config" "$profile/configs/migration-before-native.config"|' \
 -e "/^grep -Fx 'CFLAGS_uke-fs19xx-runtime.o += -DUKE_FS19XX_CONTROLS_ONLY'/s/^grep -Fx /! grep -Fq /" \
 -e '/^! strings .*uke-fs19xx-runtime.o.*grep -F xiaomi,fs19xx-protected/s/^! strings /strings /' \
 "$checker" > "$stage/checker"
install -m644 "$stage/checker" "$checker"
# The actual embedded-initramfs branch must compare the new manager cohort.
# Its old complete reference remains checked during preparation, unchanged.
payload=$profile/src/boot/build-payload.sh
printf '%s  %s\n' f05787c6ba9e256227761d1f0cfd5035705f16693a7cdb3873e30b54cfe4e3e5 "$payload" | sha256sum -c --strict -
install -Dm644 "$payload" "$profile/history-before-migration/src/boot/build-payload.sh"
awk '
 $0=="bash \"$here/../../tests/nfc-cohort-config731.sh\" \"$out/.config\" \"$kernel/native-generated/nfc-waydroid-reference/.config\"" {
  print "bash \"$kernel/native-profile/packaging/native/check-migration-boot-config731.sh\" \"$kernel\" \"$out\"";n++;next
 }
 {print}
 END {if(n!=1)exit 1}
' "$payload" > "$stage/payload"
install -m644 "$stage/payload" "$payload"
cat >> "$profile/prepare.sh" <<'PREP'

# Qualified stationary initial-state sampling; no new wake or GPIO owner.
install -m644 "$kernel/drivers/input/misc/qcom-smp2p-switch.c" "$kernel/native-generated/hall-before-startup.c"
bash "$profile/src/input/apply-smp2p-switch-startup.sh" "$kernel"
PREP
old=uke7.3.1-12204u
new=uke7.3.1-${revision}u
for tree in "$profile" "$boot"; do
 [[ $(grep -Fo "$old" "$tree/src/audio/uke-audio-card.c" | wc -l) == 2 ]]
 sed "s/uke7[.]3[.]1-12204u/$new/g" "$tree/src/audio/uke-audio-card.c" > "$stage/card.c"
 install -m644 "$stage/card.c" "$tree/src/audio/uke-audio-card.c"
done
install -m644 "$profile/source-composition.json" "$profile/source-composition-before-migration.json"
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg commit "$commit" --arg revision "$revision" --arg native_sha "$native_sha" \
 --slurpfile plan "$plan" '.+{source_commit:$commit,kernel_release:("7.3.1-"+$revision+"-unstable"),
 rpm_revision:$revision,migration_parent_build:11263248,migration_parent_source:$plan[0].parent.source_commit,
 kernel_migration_layer:1,ssc_mount_matrix_layer:1,kernel_manager_resources_layer:1,hall_startup_layer:1,
 migration_native_config_sha256:$native_sha,normal_kernel_promotion:false,
 diagnostic_audio_driver:("uke7_3_1-"+$revision+"u"),
 source_mode:(.source_mode+"+native-migration-hall-manager-protected223"),
 migration_required_checks:$plan[0].required_checks,
 migration_deferred_activation:["camera CRM permanent resources and all38 managed clocks","HDR typed data integration and physical qualification"],
 device_installation:false,physical_acceptance:false}' \
 "$profile/source-composition-before-migration.json" > "$profile/source-composition.json"
# Synchronize every already-declared boot input from the augmented profile.
while IFS= read -r path; do
 case $path in packaging/native/prepare.sh) continue;; packaging/native/native.config) continue;; esac
 [[ ! -f $profile/$path ]] || install -m644 "$profile/$path" "$boot/$path"
done < <(jq -er '.source_assets[].path' "$boot/lock.json")
# Carry new transitive source assets too; the old bootstrap preparation stays historical.
while IFS= read -r path; do
 path=${path#./}
 case $path in packaging/native/prepare.sh|packaging/native/native.config) continue;; esac
 install -Dm644 "$profile/$path" "$boot/$path"
done < <(cd "$profile"; find src tests configs packaging -type f | LC_ALL=C sort)
install -m644 "$profile/prepare.sh" "$boot/packaging/native/cumulative-prepare.sh"
for tree in "$profile" "$boot"; do
 (cd "$tree"; find . -type f ! -name SHA256SUMS ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$stage/tree.sha256"
 if [[ $tree == "$profile" ]]; then
  (cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
 else
  jq -Rn '[inputs|capture("^(?<sha256>[a-f0-9]{64})  [.]?/?(?<path>.*)$")]|map({path,sha256})' \
   < "$stage/tree.sha256" > "$stage/assets.json"
  jq --slurpfile assets "$stage/assets.json" '.source_assets=$assets[0] |
   .cumulative_native_preparation="packaging/native/cumulative-prepare.sh" |
   .historical_native_preparation="packaging/native/prepare.sh"' "$boot/lock.json" > "$stage/lock.json"
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
 /^%global senemos_build_release 12204$/ {$0="%global senemos_build_release "revision;r++}
 /^Requires: uke-kernel-update >= 1[.]8[.](90|38)$/ {$0="Requires: uke-kernel-update >= 1.8.97";u++}
 /^export ARCH=arm64 LLVM=1 LLVM_IAS=1$/ {
  print "bash native-profile/packaging/native/check-migration-cohort731.sh \"$PWD\" %{_uke_out} prepared"
  print "bash native-profile/packaging/native/prepare-migration-manager731.sh \"$PWD\" %{_uke_out}";h++
 }
 /^bash native-profile\/tests\/nfc-cohort-config731.sh / {
  sub(/native-generated\/nfc-waydroid-reference/,"native-generated/migration-manager-linked-waydroid");f++
 }
 /^%check$/ {print;print "bash native-profile/tests/migration-boot-config-boundary731.sh \"$PWD\" %{_uke_out}";print "bash native-profile/packaging/native/check-migration-cohort731.sh \"$PWD\" %{_uke_out} linked";next}
 /^%changelog$/ {
  print;print "* Thu Nov 05 2026 Uke contributors - 7.3.1-"revision
  print "- Retain complete12204 and all qualified native sensor, Hall, manager and protected223 additions."
  print "- Preserve camera/HDR admission, automatic staging and persistent local preferences."
  print "";next
 }
 {print}
 END {if(r!=1||u!=2||h!=1||f!=1)exit 1}
' "$spec" > "$stage/full.spec"
install -m644 "$stage/full.spec" "$spec"
bash "$owner/tests/unstable-boot-family731-contract.sh" "$spec"
if [[ $mode == check ]]; then
 check_spec=$output/uke-kernel-migration-check.spec
 awk -v release="$proof" '
  /^%description/ {exit}
  /^Name:/ {$0="Name: uke-kernel-migration-check"}
  /^Release:/ {$0="Release: "release"%{?dist}"}
  /^(Requires|Provides|Recommends|Conflicts|Obsoletes)(\([^)]*\))?:/ {next}
  {print}
 ' "$spec" > "$check_spec"
 cat >> "$check_spec" <<'SPEC'
%description
Complete cumulative source preparation and actual native objects for the next
unstable Uke kernel. Text evidence only; no Image, final module or target operation.
SPEC
 awk '/^%prep$/ {emit=1} /^%build$/ {exit} emit{print}' "$spec" >> "$check_spec"
 awk '/^%build$/ {emit=1} /^bash boot-recipe\/src\/boot\/build-payload.sh / {exit} emit{print}' "$spec" >> "$check_spec"
 cat >> "$check_spec" <<'SPEC'
make O=%{_uke_out} ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-%{senemos_build_release}-unstable KCFLAGS=-Werror -j4 \
 drivers/iio/common/uke-ssc/uke-ssc.o drivers/input/misc/qcom-smp2p-switch.o \
 sound/soc/codecs/fs19xx.o sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o arch/arm64/kernel/uke-abl.o
bash native-profile/packaging/native/check-migration-cohort731.sh "$PWD" %{_uke_out} objects
bash native-profile/tests/migration-boot-config-boundary731.sh "$PWD" %{_uke_out}
%install
install -d %{buildroot}%{_docdir}/%{name}
install -m644 native-profile/source-commit native-profile/source-composition.json \
 native-profile/configs/kernel-manager/resources.config %{buildroot}%{_docdir}/%{name}/
printf 'Complete12204 and qualified SSC/matrix/Hall/manager/protected223 prep, closed config comparisons and actual AArch64 objects pass; no Image, module or physical acceptance.\n' \
 > %{buildroot}%{_docdir}/%{name}/checks.txt
%check
test ! -e %{_uke_out}/arch/arm64/boot/Image
test -z "$(find %{_uke_out} -type f -name '*.ko' -print -quit)"
%files
%license COPYING
%{_docdir}/%{name}
SPEC
 cat >> "$check_spec" <<SPEC
%changelog
* Thu Nov 05 2026 Uke contributors - 7.3.1-$proof
- Check complete cumulative preparation, exact retained config histories and native objects.
SPEC
 unlink "$spec"
fi
sha256sum -c --strict --quiet "$stage/retained-sources"
for role in audio manager hall als; do git -C "$owner" worktree remove --force "$stage/$role"; done
printf 'Complete12204 migration %s source prepared for planned ABI7.3.1-%s-unstable; all original gates retained or narrowly extended\n' "$mode" "$revision"

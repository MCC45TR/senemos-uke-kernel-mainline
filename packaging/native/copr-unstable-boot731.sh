#!/usr/bin/env bash
# COPR only: retain the withdrawn 6000 input in an isolated diagnostic family.
set -Eeuo pipefail
export LC_ALL=C
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
output=$(realpath -m "${1:?COPR source output}")
revision=${2:?Fresh diagnostic revision}
camera_stage=${3:?Camera admission stage: 0 or 1}
[[ $revision =~ ^[1-9][0-9]{3,4}$ && $revision -ge 7001 ]]
[[ $camera_stage == 0 || $camera_stage == 1 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
mkdir -p "$output" "$stage/unpacked"
curl -fLsS --retry 2 --proto '=https' --proto-redir '=https' \
 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11252822/senemos-uke-linux-kernel-mainline-7.3.1-6000.src.rpm \
 -o "$stage/parent.src.rpm"
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/parent.src.rpm") == senemos-uke-linux-kernel-mainline-7.3.1-6000 ]]
[[ $(rpm -qp --qf '%{SHA256HEADER}' "$stage/parent.src.rpm") == 1b4b01c5fcf780bb13154807eefd68cae642cb5151b1105ca0622d62ad3a939c ]]
[[ $(rpm -qp --qf '%{PAYLOADSHA256}' "$stage/parent.src.rpm") == c1b853aa669b511dc370499eb93c65d297fbc289c634a155b56b13b62a26d4c3 ]]
rpmkeys --checksig --nosignature --verbose "$stage/parent.src.rpm"
parent_sha=$(sha256sum "$stage/parent.src.rpm"); parent_sha=${parent_sha%% *}
rpm2cpio "$stage/parent.src.rpm" > "$stage/parent.cpio"
cpio -t --quiet < "$stage/parent.cpio" > "$stage/entries"
awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/entries"
(cd "$output"; cpio -idm --quiet --no-absolute-filenames < "$stage/parent.cpio")
for archive in senemos-native-profile-7.3.1.tar.xz senemos-uke-boot-recipe.tar.xz; do
 tar -tJf "$output/$archive" > "$stage/entries"
 awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/entries"
 tar -xJf "$output/$archive" -C "$stage/unpacked"
done
profile=$stage/unpacked/native-profile
boot=$stage/unpacked/boot-recipe
(cd "$profile"; sha256sum --check --strict --quiet SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
cmp "$boot/lock.json" "$output/boot-payload.json"
[[ $(cat "$profile/source-commit") == bf1f6634bafc214219de1c48b3fc72a181485343 ]]
jq -e '.kernel_release=="7.3.1-6000" and .front_geni_dt_activation and .front_eeprom_dt_activation and (.physical_acceptance|not)' "$profile/source-composition.json" >/dev/null

# Gate only the two new boot conversions. Keep the driver, object fixtures,
# effective configuration and all other 6000 features unchanged for bisection.
cp "$profile/src/boot/uke-abl.c" "$stage/abl-before.c"
awk -v stage="$camera_stage" '
 /ret = uke_camcc_controller_graph\(output\);/ {
  print "\tif (" stage " >= 1) {"; print; getline; print; getline; print; print "\t}"; cam++; next
 }
 /ret = uke_front_eeprom_graph\(output\);/ {
  print "\tif (0) { /* EEPROM activation awaits an isolated controller boot. */";
  print; getline; print; getline; print; print "\t}"; front++; next
 }
 {print}
 END {if(cam!=1 || front!=1)exit 1}
' "$stage/abl-before.c" > "$profile/src/boot/uke-abl.c"
if [[ -f $boot/src/boot/uke-abl.c ]]; then
 cmp "$stage/abl-before.c" "$boot/src/boot/uke-abl.c"
 cp "$profile/src/boot/uke-abl.c" "$boot/src/boot/uke-abl.c"
fi

# The updater admits this family only when the Image ABI ends in -unstable.
for tree in "$profile" "$boot"; do
 for path in src/boot/build-payload.sh src/boot/make-initramfs-base.sh; do
  [[ $(grep -Fc '(-kvm)?' "$tree/$path") == 1 ]]
  sed -i 's/(-kvm)?/(-kvm|-unstable)?/' "$tree/$path"
  bash -n "$tree/$path"
 done
done
# These existing object/link checks accept only the original numeric ABI.
# Extend their namespace admission while retaining every object assertion.
for path in tests/camss-sm7675-module731-object.sh tests/camcc-controller-linked731-check.sh \
 tests/camss-sm7675-phy-object.sh tests/camss-sm7675-linked731-check.sh \
 tests/camcc-native-object.sh tests/msm-kms-alternate-build.sh; do
 for tree in "$profile" "$boot"; do
  test -f "$tree/$path" || continue
  sed -i '/^\[\[ \$release =~ /s/\$ \]\]/(-unstable)?$ ]]/' "$tree/$path"
  bash -n "$tree/$path"
 done
done
for path in src/boot/uke-abl.c src/boot/build-payload.sh src/boot/make-initramfs-base.sh \
 tests/camss-sm7675-module731-object.sh tests/camcc-controller-linked731-check.sh \
 tests/camss-sm7675-phy-object.sh tests/camss-sm7675-linked731-check.sh \
 tests/camcc-native-object.sh tests/msm-kms-alternate-build.sh; do
 test -f "$boot/$path" || continue
 digest=$(sha256sum "$boot/$path"); digest=${digest%% *}
 jq --arg path "$path" --arg digest "$digest" \
  '.source_assets |= (map(select(.path!=$path)) + [{path:$path,sha256:$digest}])' \
  "$boot/lock.json" > "$stage/lock.json"
 mv "$stage/lock.json" "$boot/lock.json"
done
cp "$boot/lock.json" "$output/boot-payload.json"
cp "$profile/source-composition.json" "$profile/source-composition-withdrawn6000.json"
producer=$(git -C "$owner" rev-parse HEAD)
jq --arg revision "$revision" --arg producer "$producer" --arg parent "$parent_sha" --argjson stage "$camera_stage" \
 '. + {kernel_release:("7.3.1-"+$revision+"-unstable"),rpm_revision:$revision,
 source_mode:"withdrawn6000-with-isolated-boot-admission-bisection",
 diagnostic_producer_commit:$producer,diagnostic_parent_srpm_sha256:$parent,
 diagnostic_parent_build:11252822,diagnostic_camera_stage:$stage,
 camcc_boot_fdt_activation:($stage==1),camera_dt_activation:($stage==1),
 front_geni_dt_activation:false,front_eeprom_dt_activation:false,
 camera_sensor_dt_activation:false,camera_capture_graph_activation:false,
 device_installation:false,physical_acceptance:false,
 diagnostic_scope:"Source bisection only; both calibrated cameras and rear focus remain required"}' \
 "$profile/source-composition-withdrawn6000.json" > "$profile/source-composition.json"
install -Dm644 "$owner/tests/unstable-boot-family731-contract.sh" "$profile/tests/unstable-boot-family731-contract.sh"
install -Dm644 "$owner/docs/UNSTABLE-BOOT-TRIALS.md" "$profile/docs/UNSTABLE-BOOT-TRIALS.md"
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
for tree in native-profile boot-recipe; do
 archive=senemos-native-profile-7.3.1.tar.xz
 [[ $tree != boot-recipe ]] || archive=senemos-uke-boot-recipe.tar.xz
 tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$archive" -C "$stage/unpacked" "$tree"
done

old_spec=$output/senemos-uke-linux-kernel-mainline.spec
spec=$output/senemos-uke-linux-kernel-mainline-unstable.spec
day=$(date -u --date="@$epoch" '+%a %b %d %Y')
awk -v revision="$revision" -v day="$day" '
 /^Name: senemos-uke-linux-kernel-mainline$/ {$0=$0 "-unstable"; names++}
 /^%global senemos_build_release 6000$/ {$0="%global senemos_build_release " revision; releases++}
 /^%global krel / {$0=$0 "-unstable"; abis++}
 /^%posttrans boot / {drop=1; hooks++; next}
 drop && /^%files$/ {drop=0}
 drop {next}
 /^%check$/ {print; print "bash native-profile/tests/unstable-boot-family731-contract.sh %{_specdir}/senemos-uke-linux-kernel-mainline-unstable.spec %{buildroot} %{krel}"; next}
 /^%changelog$/ {
  print; print "* " day " MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-" revision
  print "- Isolate camera boot admission in an explicitly selected unstable family."
  print "- Preserve the accepted mainline profile and matching rollback modules."
  print ""; next
 }
 /grep -aqF '\''uke-front-calibration'\''/ {
  print "if " $0 "; then echo '\''Front EEPROM must remain inactive in this bisection stage'\'' >&2; exit 1; fi"; next
 }
 {
  gsub(/LOCALVERSION=-%\{senemos_build_release\}/,"LOCALVERSION=-%{senemos_build_release}-unstable")
  gsub(/\/senemos\/default-boot.img/,"/senemos/unstable-default-boot.img")
  gsub(/uke\/singleboot.json/,"uke/unstable-singleboot.json")
  gsub(/automatic_kernel_activation==true/,"automatic_kernel_activation==false")
  gsub(/"automatic_kernel_activation": true/,"\"automatic_kernel_activation\": false")
  print
 }
 END {if(names!=1 || releases!=1 || abis!=1 || hooks!=1)exit 1}
' "$old_spec" > "$spec"
rm "$old_spec"
bash "$owner/packaging/native/date-cohort-changelog.sh" "$spec" "$revision" "$epoch"
bash "$owner/tests/unstable-boot-family731-contract.sh" "$spec"
printf 'Prepared isolated diagnostic %s: camera stage %s; no automatic activation\n' "$revision" "$camera_stage"

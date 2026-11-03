#!/usr/bin/env bash
# COPR only: retain the qualified 1301 kernel and replace only NFC/IR sources.
set -Eeuo pipefail
export LC_ALL=C
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR result directory}")
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
bash "$owner/packaging/native/refuse-published-release.sh" senemos-uke-linux-kernel-mainline 7.3.1-1401
parent_hash=83b76251f124193609cb2da1f04a1f3100287875534bf1f8504e0ffa87f76d4b
curl -fLsS --retry 2 --max-time 300 --proto '=https' --proto-redir '=https' \
    https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11251200/senemos-uke-linux-kernel-mainline-7.3.1-1301.src.rpm -o "$stage/base.src.rpm"
printf '%s  %s\n' "$parent_hash" "$stage/base.src.rpm" | sha256sum -c -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/base.src.rpm") == senemos-uke-linux-kernel-mainline-7.3.1-1301 ]]
rpm2cpio "$stage/base.src.rpm" > "$stage/base.cpio"
cpio -t --quiet < "$stage/base.cpio" > "$stage/entries"
awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/entries"
mkdir -p "$output" "$stage/unpacked"
(cd "$output"; cpio -idm --quiet --no-absolute-filenames < "$stage/base.cpio")
spec=$output/senemos-uke-linux-kernel-mainline.spec
printf '%s  %s\n' 1df9eadd11608c2ad99a1728af12fcc5ddc20d7e8bf412c8b87bce72010bae6f "$spec" | sha256sum -c -
archive=senemos-native-profile-7.3.1.tar.xz
boot_archive=senemos-uke-boot-recipe.tar.xz
find "$output" -maxdepth 1 -type f ! -name "${spec##*/}" ! -name "$archive" \
    ! -name "$boot_archive" ! -name boot-payload.json \
    -print0 | sort -z | xargs -0 sha256sum > "$stage/retained-sources.sha256"
tar -tJf "$output/$archive" > "$stage/entries"
awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/entries"
tar -xJf "$output/$archive" -C "$stage/unpacked"
tar -tJf "$output/$boot_archive" > "$stage/entries"
awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/entries"
tar -xJf "$output/$boot_archive" -C "$stage/unpacked"
profile=$stage/unpacked/native-profile
boot=$stage/unpacked/boot-recipe
[[ $(cat "$profile/source-commit") == 1c77e13fe0efd77053add9df9ebc7ae484fdbd48 ]]
(cd "$profile"; sha256sum --check --strict --quiet SHA256SUMS)
cmp "$profile/native.config" "$boot/packaging/native/native.config"
cmp "$output/boot-payload.json" "$boot/lock.json"
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c -
    find . -type f ! -path './lock.json' ! -path './packaging/native/native.config' \
        -print0 | sort -z | xargs -0 sha256sum > "$stage/retained-boot.sha256")
overlays=(src/nfc/fm19511-uke.c src/nfc/fm19511-uapi.h src/nfc/fm,fm19511.yaml
    src/nfc/prepare-source.sh src/nfc/README.md src/infrared/ir-spi-uke.c
    src/boot/sm7675-uke-usb2.dtso tests/fm19511-contract.sh
    tests/fm19511-pm-contract.sh tests/ir-spi-contract.sh)
printf '%s\n' "${overlays[@]}" > "$stage/overlays"
(cd "$profile"
    while IFS= read -r path; do
        [[ $path == SHA256SUMS || $path == source-commit || $path == source-composition.json || $path == native.config ]] && continue
        grep -Fxq "$path" "$stage/overlays" && continue
        sha256sum "$path"
    done < <(find . -type f -printf '%P\n' | sort)
) > "$stage/retained-profile.sha256"
for path in "${overlays[@]}"; do
    install -Dm644 "$owner/$path" "$profile/$path"
done
awk '
 FNR==NR {if(/^CONFIG_/) {split($0,a,"="); setting[a[1]]=$0} next}
 {
  key=$0; sub(/^# /,"",key); sub(/[= ].*$/,"",key)
  if(key in setting) {print setting[key]; delete setting[key]} else print
 }
 END {for(key in setting) print setting[key]}
' "$owner/configs/nfc-ir.config" "$profile/native.config" > "$stage/native.config"
install -m644 "$stage/native.config" "$profile/native.config"
install -m644 "$stage/native.config" "$boot/packaging/native/native.config"
config_hash=$(sha256sum "$stage/native.config"); config_hash=${config_hash%% *}
jq --arg hash "$config_hash" '(.source_assets[]|select(.path=="packaging/native/native.config")|.sha256)=$hash' \
    "$boot/lock.json" > "$stage/lock.json"
install -m644 "$stage/lock.json" "$boot/lock.json"
install -m644 "$stage/lock.json" "$output/boot-payload.json"
cp "$profile/source-composition.json" "$profile/source-composition-before1401.json"
commit=$(git -C "$owner" rev-parse HEAD)
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg commit "$commit" --arg parent_hash "$parent_hash" \
    --slurpfile overlays <(jq -R -s 'split("\n")|map(select(length>0))' "$stage/overlays") '. + {
    source_commit:$commit,source_mode:"retained1301-with-native-nfc-ir-v2",
    parent_copr_build:11251200,parent_srpm_sha256:$parent_hash,
    parent_composition:"source-composition-before1401.json",kernel_release:"7.3.1-1401",rpm_revision:"1401",
    nfc_role:"type2-tag",nfc_reader:false,nfc_eeprom_write:false,
    nfc_atomic_memory_read:true,nfc_raw_irq_status:true,nfc_system_wakeup:true,
    ir_role:"transmitter",ir_receive:false,ir_explicit_word_bits:16,
    overlays:$overlays[0],kernel_driver_source_unchanged:false,
    automatic_policy_unchanged:true,physical_acceptance:false
}' "$profile/source-composition-before1401.json" > "$profile/source-composition.json"
(cd "$profile"; sha256sum -c "$stage/retained-profile.sha256"
    find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
    -cJf "$output/$archive" -C "$stage/unpacked" native-profile
(cd "$boot"; sha256sum -c "$stage/retained-boot.sha256"
    jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c -)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
    -cJf "$output/$boot_archive" -C "$stage/unpacked" boot-recipe
[[ $(grep -Fxc '%global senemos_build_release 1301' "$spec") == 1 ]]
[[ $(grep -Fxc 'uke_build_start=$SECONDS' "$spec") == 1 ]]
awk '
 /^%global senemos_build_release 1301$/ {$0="%global senemos_build_release 1401"}
 /^Name:[[:space:]]/ {print; print "Provides: uke-kernel(nfc-ir-v2) = 1"; next}
 /^uke_build_start=\$SECONDS$/ {
  print
  print "CC=clang CFLAGS='' bash native-profile/tests/fm19511-contract.sh"
  print "CC=clang CFLAGS='' bash native-profile/tests/fm19511-pm-contract.sh"
  print "CC=clang CFLAGS='' bash native-profile/tests/ir-spi-contract.sh drivers/media/rc/ir-spi.c"
  next
 }
 /^%check$/ {
  print
  print "test -s %{_uke_out}/drivers/misc/fm19511-uke.o"
  print "test -s %{_uke_out}/drivers/media/rc/ir-spi.o"
  print "test -n \"$(find %{buildroot}/usr/lib/modules/%{krel} -type f -name '\''fm19511-uke.ko*'\'' -print -quit)\""
  print "test -n \"$(find %{buildroot}/usr/lib/modules/%{krel} -type f -name '\''ir-spi.ko*'\'' -print -quit)\""
  next
 }
 /^%changelog$/ {
  print
  print "* Tue Nov 03 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-1401"
  print "- Add read-only tag memory, raw RF event reporting and system wake support."
  print "- Bound IR frames and use explicit SPI words with validated carrier and duty."
  print ""
  next
 }
 {print}
' "$spec" > "$stage/next.spec"
mv "$stage/next.spec" "$spec"
sha256sum -c "$stage/retained-sources.sha256"
[[ $(rpmspec --target aarch64 --define 'dist %{nil}' -q --srpm --qf '%{VERSION}-%{RELEASE}' "$spec") == 7.3.1-1401 ]]
rpmbuild -bs --define "_sourcedir $output" --define "_srcrpmdir $output" "$spec"

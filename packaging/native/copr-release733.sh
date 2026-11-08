#!/usr/bin/bash
# One source-qualified cumulative candidate; no independent full-kernel queue.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?Source result directory}")
mode=${3:?check or full}
[[ $mode == check || $mode == full ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
manifest=$owner/manifests/release-delivery-20261108.json
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
bash "$owner/packaging/native/copr-dual-light-delivery733.sh" "$@"
version=$(jq -er .upstream.version "$owner/manifests/cumulative-release.json")
native=senemos-native-profile-$version.tar.xz
boot_archive=senemos-uke-boot-recipe.tar.xz
tar -xJf "$output/$native" -C "$work"
tar -xJf "$output/$boot_archive" -C "$work"
profile=$work/native-profile
boot=$work/boot-recipe
for tree in "$profile" "$boot"; do
 while IFS= read -r file;do install -Dm644 "$owner/$file" "$tree/$file";done < <(jq -r '.payload_assets[]' "$manifest")
 install -Dm644 "$manifest" "$tree/manifests/${manifest##*/}"
done
# A pinned failed spec exercises the exact transformation without another full
# kernel. No source/regression result is inferred from this text-only fixture.
curl -qfsSL --retry 2 --max-time 40 --max-filesize 1048576 \
 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11286962/senemos-uke-linux-kernel-mainline-unstable.spec > "$work/actual-full.spec"
bash "$owner/tests/lean-full-spec.sh" "$owner" "$work/actual-full.spec"
install -Dm644 "$work/actual-full.spec" "$profile/tests/fixtures/lean-full-parent.spec"
if [[ $mode == full ]];then
 spec=$output/senemos-uke-linux-kernel-mainline-unstable.spec
 bash "$owner/packaging/native/rewrite-lean-full733.sh" "$spec"
else
 spec=$output/uke-kernel-migration-check.spec
 awk '
  /^make .* sound\/soc\/qcom\/uke-audio-card.o$/ {
   print "bash native-profile/src/audio/apply-speaker-display733.sh \"$PWD\""
   print "bash native-profile/tests/speaker-display-route.sh native-profile"
   print;card++;next
  }
  $0=="%install" {
   print "make O=%{_uke_out} ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-%{senemos_build_release}-unstable -j4 sound/soc/codecs/wcd939x.o"
   print "bash native-profile/packaging/native/check-shipping-audio733.sh \"$PWD\" %{_uke_out} objects"
   print "bash native-profile/tests/lean-full-spec.sh native-profile native-profile/tests/fixtures/lean-full-parent.spec"
   final++
  }
  {print}END{if(card!=1||final!=1)exit 1}
 ' "$spec" > "$work/spec"
 install -m644 "$work/spec" "$spec"
fi
cp "$profile/source-composition.json" "$work/parent-composition.json"
jq --arg mode "$mode" --arg proof "$4" '.+{
 speaker_display_card_control:1,speaker_display_card_rollback:true,
 speaker_display_fault_on_failed_rollback:true,speaker_display_raw_sensor_policy:false,
 speaker_display_old_codec_controls_retained:true,speaker_display_physical_accepted:false,
 lean_full_delivery:1,lean_full_source_qualification_required:true,
 lean_full_production_checks_retained:true,lean_full_target_seconds:1200,
 release_delivery_native_admitted:($mode=="full"),
 release_delivery_qualification_build:(if $mode=="full" then ($proof|tonumber) else null end),
 full_build_duration_qualified:false,physical_acceptance:false}' \
 "$work/parent-composition.json" > "$profile/source-composition.json"
bash "$owner/packaging/native/stage-avr-transaction733.sh" "$profile" "$boot" "$spec" "$mode" "${@:4}"
(cd "$profile";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot";find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$work/boot-assets"
jq -Rn '[inputs|capture("^(?<sha256>[a-f0-9]{64})  [.]?/?(?<path>.*)$")]|map({path,sha256})' < "$work/boot-assets" > "$work/assets.json"
jq --slurpfile assets "$work/assets.json" '.source_assets=$assets[0]' "$boot/lock.json" > "$work/lock.json"
install -m644 "$work/lock.json" "$boot/lock.json"
install -m644 "$boot/lock.json" "$output/boot-payload.json"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$native" -C "$work" native-profile
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$boot_archive" -C "$work" boot-recipe
printf 'Cumulative release delivery prepared:%s; native speaker control and lean full stages, same-source proof and unchanged payload scope; physical/timing acceptance separate.\n' "$mode"

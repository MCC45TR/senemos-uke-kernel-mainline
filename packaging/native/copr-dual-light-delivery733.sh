#!/usr/bin/bash
# COPR only. Extend the cumulative recipe with qualified native dual-light code.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
manifest=$owner/manifests/dual-light-delivery-20261108.json
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
output=$(realpath -m "${1:?Source result directory}")
mode=${3:?check or full}
[[ $mode == check || $mode == full ]]
tuple=$(bash "$owner/scripts/kernel-release.sh" json "$owner/manifests/cumulative-release.json")
version=$(jq -er .version <<< "$tuple")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
if [[ $mode == full ]]; then
  [[ $# == 5 && $4 =~ ^[1-9][0-9]*$ && $5 =~ ^[a-f0-9]{64}$ ]]
  curl -qfsSL --retry 2 --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$4" > "$work/proof-api.json"
  jq -e --arg evr "$(jq -er .source_check_evr <<< "$tuple")" '.state=="succeeded" and .source_package.name=="uke-kernel-migration-check" and .source_package.version==$evr' "$work/proof-api.json" >/dev/null
  url=$(curl -qfsSL --retry 2 --max-time 45 "https://copr.fedorainfracloud.org/api_3/build-chroot/$4/fedora-rawhide-aarch64" | jq -er .result_url)
  curl -qfsSL --retry 2 --max-time 90 "${url}uke-kernel-migration-check-$(jq -er .source_check_evr <<< "$tuple").fc46.aarch64.rpm" -o "$work/proof.rpm"
  printf '%s  %s\n' "$5" "$work/proof.rpm" | sha256sum -c --strict --quiet -
  [[ $(rpm2cpio "$work/proof.rpm" | cpio -i --to-stdout --quiet '*source-commit') == "$(git -C "$owner" rev-parse HEAD)" ]]
  rpm2cpio "$work/proof.rpm" | cpio -i --to-stdout --quiet '*source-composition.json' > "$work/proof-composition.json"
  jq -e '.dual_light_endpoint_layer==1 and .dual_light_binding_checks_layer==1 and .dual_light_delivery_layer==1 and .dual_light_delivery_helper_rehearsal_required and (.dual_light_delivery_native_admitted|not) and (.dual_light_endpoint_native_admitted|not) and .speaker_gain_ceiling==223 and (.physical_acceptance|not)' "$work/proof-composition.json" >/dev/null
  # The original complete audio/Hall/memory full entry independently verifies
  # every older qualification field against this same source-bound receipt.
  bash "$owner/packaging/native/copr-hall-initial733.sh" "$@"
else
  [[ $# == 4 ]]
  bash "$owner/packaging/native/copr-dual-light-endpoint733.sh" "$@"
fi
native=senemos-native-profile-$version.tar.xz
boot_archive=senemos-uke-boot-recipe.tar.xz
tar -xJf "$output/$native" -C "$work"
tar -xJf "$output/$boot_archive" -C "$work"
profile=$work/native-profile
boot=$work/boot-recipe
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$work/configs.sha256"
curl -qfsSL --retry 2 --max-time 45 --max-filesize 1048576 \
 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11285130/senemos-uke-linux-kernel-mainline-unstable.spec \
 -o "$work/full5.spec"
printf '%s  %s\n' 62812a75886d65fb24d7a33fcecbc717d5616fbd733fa6cbe99a03db107547c9 "$work/full5.spec" | sha256sum -c --strict --quiet -
for tree in "$profile" "$boot"; do
  for layer in dual-light-events ssc-stream-owners dual-light-endpoint dual-light-delivery; do
    source=$owner/manifests/$layer-20261108.json
    while IFS= read -r file; do install -Dm644 "$owner/$file" "$tree/$file"; done < <(jq -r '.payload_assets[]' "$source")
    install -Dm644 "$source" "$tree/manifests/${source##*/}"
  done
  install -Dm644 "$work/full5.spec" "$tree/tests/fixtures/dual-light-full5.spec"
done
history=$profile/history-before-dual-light-delivery
[[ ! -e $history ]]
mkdir "$history"
for name in check-migration-cohort731.sh check-cumulative-camera731.sh; do
  cp "$profile/packaging/native/$name" "$history/$name"
  awk '
    $0=="profile=$kernel/native-profile" {
      print;print "dual_light_legacy=$(bash \"$profile/packaging/native/dual-light-legacy-view733.sh\" \"$kernel\")";init++;next
    }
    $0=="cmp \"$profile/src/sensors/uke-ssc-iio.c\" \"$kernel/drivers/iio/common/uke-ssc/uke-ssc-iio.c\"" {
      print "cmp \"$profile/src/sensors/uke-ssc-iio.c\" \"$dual_light_legacy/drivers/iio/common/uke-ssc/uke-ssc-iio.c\"";comparison++;next
    }
    {print}END{if(init!=1||comparison!=1)exit 1}
  ' "$history/$name" > "$profile/packaging/native/$name"
done
cp "$profile/packaging/native/check-hall-initial733.sh" "$history/check-hall-initial733.sh"
awk '
 $0=="profile=$kernel/native-profile" {
   print;print "dual_light_parent_cohort=$(bash \"$profile/packaging/native/dual-light-parent-checker733.sh\" \"$kernel\" check-migration-cohort731.sh)";init++;next
 }
 {if(sub(/"\$profile\/packaging\/native\/check-migration-cohort731.sh"/,"\"$dual_light_parent_cohort\""))paths++;print}
 END{if(init!=1||paths!=1)exit 1}
' "$history/check-hall-initial733.sh" > "$profile/packaging/native/check-hall-initial733.sh"
(cd "$history";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
cp "$profile/source-composition.json" "$profile/source-composition-before-dual-light-delivery.json"
if [[ $mode == full ]]; then
  jq --slurpfile proof "$work/proof-composition.json" --argjson build "$4" '
    reduce ($proof[0]|to_entries[]) as $field (.;
      if (has($field.key)|not) and ($field.key|test("^(dual_light_|ssc_shared_stream_)"))
      then .[$field.key]=$field.value else . end) |
    .+{dual_light_event_reducer_only:false,dual_light_runtime_integrated:true,
      ssc_shared_stream_combined_endpoint:true,ssc_shared_stream_hall_subscription:true,
      ssc_shared_stream_native_admitted:true,dual_light_endpoint_native_admitted:true,
      dual_light_binding_schema_qualified:true,dual_light_endpoint_qualification_build:$build,
      dual_light_delivery_layer:1,dual_light_delivery_full_recipe:true,
      dual_light_delivery_helper_rehearsal_required:true,
      dual_light_delivery_native_admitted:true,dual_light_delivery_qualification_build:$build,
      dual_light_delivery_physical_accepted:false,device_installation:false,physical_acceptance:false}
  ' "$profile/source-composition-before-dual-light-delivery.json" > "$work/composition.json"
  spec=$output/senemos-uke-linux-kernel-mainline-unstable.spec
  bash "$owner/packaging/native/rewrite-dual-light-full-spec733.sh" "$spec"
else
  jq '.+{dual_light_delivery_layer:1,dual_light_delivery_full_recipe:false,
    dual_light_delivery_helper_rehearsal_required:true,dual_light_delivery_native_admitted:false,
    dual_light_delivery_qualification_build:null,dual_light_delivery_physical_accepted:false}' \
    "$profile/source-composition-before-dual-light-delivery.json" > "$work/composition.json"
  spec=$output/uke-kernel-migration-check.spec
  awk '
    $0=="bash native-profile/packaging/native/check-dual-light-binding733.sh \"$PWD\" prepared" {print;print "bash native-profile/packaging/native/check-dual-light-delivery733.sh \"$PWD\" %{_uke_out} prepared";p++;next}
    $0=="bash native-profile/packaging/native/check-dual-light-binding733.sh \"$PWD\" objects" {print;print "bash native-profile/packaging/native/check-dual-light-delivery733.sh \"$PWD\" %{_uke_out} objects";o++;next}
    {print}END{if(p!=1||o!=1)exit 1}
  ' "$spec" > "$work/check.spec"
  install -m644 "$work/check.spec" "$spec"
fi
install -m644 "$work/composition.json" "$profile/source-composition.json"
bash "$owner/tests/dual-light-delivery-spec.sh" "$owner" "$work/full5.spec"
sha256sum -c --strict --quiet "$work/configs.sha256"
(cd "$profile";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot";find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$work/assets.sha256"
jq -Rn '[inputs|capture("^(?<sha256>[a-f0-9]{64})  [.]?/?(?<path>.*)$")]|map({path,sha256})' < "$work/assets.sha256" > "$work/assets.json"
jq --slurpfile assets "$work/assets.json" '.source_assets=$assets[0]' "$boot/lock.json" > "$work/lock.json"
install -m644 "$work/lock.json" "$boot/lock.json"
install -m644 "$boot/lock.json" "$output/boot-payload.json"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$native" -C "$work" native-profile
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$boot_archive" -C "$work" boot-recipe
printf 'Cumulative dual-light delivery recipe prepared:%s; exact native/boot assets, legacy checks, protected223, config and A/B policy retained.\n' "$mode"

#!/usr/bin/bash
# COPR-only production preparation and actual compiled/linked postimage checks.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 3 ]]
kernel=$(realpath "${1:?Prepared cumulative kernel}")
out=$(realpath -m "${2:?Native output}")
phase=${3:?prepared, objects or linked}
[[ $phase == prepared || $phase == objects || $phase == linked ]]
profile=$kernel/native-profile
manifest=$profile/manifests/dual-light-delivery-20261108.json
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
paths=(drivers/iio/common/uke-ssc/uke-ssc-iio.c arch/arm64/kernel/uke-abl-native.h
 Documentation/devicetree/bindings/firmware/xiaomi,uke-ssc-sensors.yaml
 drivers/iio/common/uke-ssc/Kconfig)
for layer in dual-light-events ssc-stream-owners dual-light-endpoint dual-light-delivery; do
  source=$profile/manifests/$layer-20261108.json
  while IFS= read -r file; do
    cmp "$profile/$file" "$kernel/boot-recipe/$file"
  done < <(jq -r '.payload_assets[]' "$source")
  cmp "$source" "$kernel/boot-recipe/manifests/${source##*/}"
done
if [[ $phase == prepared ]]; then
  # Only the SSC comparison is redirected. Every other line/byte of each
  # qualified parent checker must be retained, including its linked checks.
  for name in check-migration-cohort731.sh check-cumulative-camera731.sh; do
    original=$profile/history-before-dual-light-delivery/$name
    awk '
      /^dual_light_legacy=\$\(bash / {removed++;next}
      {if(sub(/"\$dual_light_legacy\/drivers\/iio\/common\/uke-ssc\/uke-ssc-iio.c"/,"\"$kernel/drivers/iio/common/uke-ssc/uke-ssc-iio.c\""))restored++;print}
      END{if(removed!=1||restored!=1)exit 1}
    ' "$profile/packaging/native/$name" | cmp - "$original"
  done
  bash "$profile/tests/dual-light-delivery-spec.sh" "$profile" "$profile/tests/fixtures/dual-light-full5.spec"
  bash "$profile/tests/dual-light-delivery-source.sh" "$kernel"
  printf 'Dual-light delivery prepared: both archives, unchanged historical checker bodies and actual production helper qualification passed; full linked image/physical gates separate.\n'
  exit 0
fi
fixture=$kernel/native-generated/dual-light-delivery-fixture
for file in "${paths[@]}"; do cmp "$kernel/$file" "$fixture/$file"; done
for pair in "src/sensors/uke-ssc-dual-light.h:drivers/iio/common/uke-ssc/uke-ssc-dual-light.h" \
 "src/boot/uke-dual-light.h:arch/arm64/kernel/uke-dual-light.h"; do
  cmp "$profile/${pair%%:*}" "$kernel/${pair#*:}"
done
if [[ $phase == objects ]]; then
  # Source-only legacy layers prepare the same postimages in stages. Record
  # the independently checked four-file inverse only after exact equality.
  history=$kernel/native-generated/before-dual-light
  [[ ! -e $history ]]
  for file in "${paths[@]}"; do
    install -Dm644 "$fixture/native-generated/before-dual-light/$file" "$history/$file"
  done
  install -m644 "$fixture/native-generated/before-dual-light/SHA256SUMS" "$history/SHA256SUMS"
fi
legacy=$(bash "$profile/packaging/native/dual-light-legacy-view733.sh" "$kernel")
for file in "${paths[@]}"; do cmp "$legacy/$file" "$fixture/native-generated/before-dual-light/$file"; done
release=$(jq -er .kernel_release "$profile/source-composition.json")
[[ $(cat "$out/include/config/kernel.release") == "$release" ]]
grep -Fx CONFIG_INPUT=y "$out/.config"
sha256sum "$out/.config" "$out/include/config/kernel.release" "$out/include/generated/utsrelease.h" > "$work/identities.sha256"
object=$out/drivers/iio/common/uke-ssc/uke-ssc-iio.o
llvm-readelf -h "$object" | grep -E 'Machine:.*AArch64'
llvm-readelf -h "$out/arch/arm64/kernel/uke-abl.o" | grep -E 'Machine:.*AArch64'
llvm-nm -u "$object" > "$work/imports"
for symbol in input_register_handler input_unregister_handler input_register_handle input_unregister_handle input_open_device input_close_device __iio_device_register iio_device_unregister; do
  grep -E " U $symbol$" "$work/imports"
done
! grep -Eq ' U (hrtimer_start|mod_timer|queue_delayed_work_on|input_grab_device)$' "$work/imports"
llvm-nm --defined-only "$object" > "$work/callbacks"
for callback in read_raw buffer_enable buffer_disable lid_event lid_start lid_match lid_connect lid_disconnect; do
  grep -E " [Tt] ssc_dual_$callback$" "$work/callbacks"
done
strings "$out/arch/arm64/kernel/uke-abl.o" | grep -Fx lid-switch
if [[ $phase == linked ]]; then
  test -s "$out/arch/arm64/boot/Image"
  module=drivers/iio/common/uke-ssc/uke-ssc.ko
  test -s "$out/$module"
  [[ $(modinfo -F vermagic "$out/$module") == "$release "* ]]
  signed=$out/boot-modules/lib/modules/$release/kernel/$module.zst
  test -s "$signed"
  [[ -n $(modinfo -F signer "$signed") && $(modinfo -F vermagic "$signed") == "$release "* ]]
  llvm-nm -u "$out/$module" > "$work/module-imports"
  for symbol in input_register_handler input_unregister_handler __iio_device_register iio_device_unregister; do
    grep -E " U $symbol$" "$work/module-imports"
  done
fi
sha256sum -c --strict --quiet "$work/identities.sha256"
printf 'Actual cumulative dual-light production postimages, authenticated inverse, input/IIO callbacks and early DT passed:%s; full module signing checked only for linked, physical acceptance separate.\n' "$phase"

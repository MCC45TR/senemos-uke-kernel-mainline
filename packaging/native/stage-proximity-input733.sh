#!/usr/bin/bash
# Add qualified native endpoints to both cumulative delivery archives.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 4 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
profile=$(realpath "${1:?Native profile}")
boot=$(realpath "${2:?Boot recipe}")
spec=$(realpath "${3:?Cumulative spec}")
mode=${4:?check or full}
[[ $mode == check || $mode == full ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
for name in ssc-proximity-input rproc-crash-count; do
 manifest=$owner/manifests/$name-20261109.json
 (cd "$owner"; jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
 for tree in "$profile" "$boot"; do
  while IFS= read -r file; do install -Dm644 "$owner/$file" "$tree/$file"; done < <(jq -r '.payload_assets[]' "$manifest")
  install -Dm644 "$manifest" "$tree/manifests/${manifest##*/}"
 done
done
if [[ $mode == full ]]; then
 bash "$owner/packaging/native/rewrite-proximity-full-spec733.sh" "$spec"
else
 awk '
  $0=="%install" {
   print "bash native-profile/tests/proximity-delivery-spec.sh native-profile native-profile/tests/fixtures/proximity-full9.spec"
   print "bash native-profile/src/sensors/apply-proximity-input733.sh \"$PWD\""
   print "bash native-profile/packaging/native/check-proximity-input733.sh \"$PWD\" %{_uke_out} source"
   print "make O=%{_uke_out} ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-%{senemos_build_release}-unstable KCFLAGS=-Werror W=1 -j4 drivers/iio/common/uke-ssc/uke-ssc.o"
   print "bash native-profile/packaging/native/check-proximity-input733.sh \"$PWD\" %{_uke_out} objects"
   print "bash native-profile/src/health/apply-rproc-count733.sh \"$PWD\""
   print "bash native-profile/packaging/native/check-rproc-count733.sh \"$PWD\" %{_uke_out} source"
   print "make O=%{_uke_out} ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-%{senemos_build_release}-unstable KCFLAGS=-Werror W=1 -j4 drivers/remoteproc/remoteproc_sysfs.o"
   print "bash native-profile/packaging/native/check-rproc-count733.sh \"$PWD\" %{_uke_out} objects"
   n++
  }
  {print}
  END {if(n!=1)exit 1}
 ' "$spec" > "$work/spec"
 install -m644 "$work/spec" "$spec"
fi
jq --arg mode "$mode" '.+{
 ssc_proximity_input_layer:1,ssc_proximity_raw_iio_unchanged:true,
 ssc_proximity_shared_per_suid_demand:true,ssc_proximity_no_timer:true,
 ssc_proximity_native_admitted:($mode=="full"),ssc_proximity_physical_accepted:false,
 original_sensor_proxy_retired:false,
 rproc_crash_count_layer:1,rproc_crash_count_read_only:true,
 rproc_crash_count_no_firmware_query:true,rproc_crash_worker_unchanged:true,
 rproc_crash_count_native_admitted:($mode=="full"),rproc_crash_count_physical_accepted:false,
 proximity_delivery_layer:1,proximity_delivery_both_archives:true,
 proximity_delivery_authenticated_legacy_inverse:true,
 proximity_delivery_git_context_independent:true,
 critical_crash_count_control_required:true,proximity_delivery_linked_accepted:false}' \
 "$profile/source-composition.json" > "$work/composition"
install -m644 "$work/composition" "$profile/source-composition.json"

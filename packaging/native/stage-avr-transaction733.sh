#!/usr/bin/bash
# Add one late cumulative layer; caller owns archive hashing and packing.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
profile=$(realpath "${1:?Native profile}")
boot=$(realpath "${2:?Boot recipe}")
spec=$(realpath "${3:?Cumulative spec}")
mode=${4:?check or full}
[[ $mode == check || $mode == full ]]
manifest=$owner/manifests/avr-transaction-20261108.json
(cd "$owner"; jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
if [[ $mode == full ]]; then
 [[ $# == 6 && $5 =~ ^[1-9][0-9]*$ && $6 =~ ^[a-f0-9]{64}$ ]]
 url=$(curl -qfsSL --max-time 45 "https://copr.fedorainfracloud.org/api_3/build-chroot/$5/fedora-rawhide-aarch64" | jq -er .result_url)
 evr=$(bash "$owner/scripts/kernel-release.sh" json "$owner/manifests/cumulative-release.json" | jq -er .source_check_evr)
 curl -qfsSL --max-time 90 "${url}uke-kernel-migration-check-$evr.fc46.aarch64.rpm" -o "$work/proof.rpm"
 printf '%s  %s\n' "$6" "$work/proof.rpm" | sha256sum -c --strict --quiet -
 rpm2cpio "$work/proof.rpm" | cpio -i --to-stdout --quiet '*source-composition.json' > "$work/proof.json"
 jq -e '.avr_transaction_layer==1 and .avr_transaction_sourcecheck_required and .avr_transaction_keeps_atomic_quarantine and (.avr_transaction_full_modeset_rollback|not) and (.avr_transaction_physical_accepted|not)' "$work/proof.json" >/dev/null
 grep -Fx '# UKE_LEAN_FULL_RECIPE' "$spec"
fi
for tree in "$profile" "$boot"; do
 while IFS= read -r file; do install -Dm644 "$owner/$file" "$tree/$file"; done < <(jq -r '.payload_assets[]' "$manifest")
 install -Dm644 "$manifest" "$tree/manifests/${manifest##*/}"
done
awk -v mode="$mode" '
 mode=="check" && $0=="%build" {
  print;print "bash native-profile/tests/o82-avr-early733.sh \"$PWD\" test";early++;next
 }
 mode=="full" && /^bash native-profile\/src\/audio\/apply-speaker-display733.sh / {
  print;print "bash native-profile/src/display/apply-avr-transaction733.sh \"$PWD\""
  print "bash native-profile/packaging/native/check-avr-transaction733.sh \"$PWD\" %{_uke_out} source";apply++;next
 }
 mode=="full" && /^bash native-profile\/packaging\/native\/check-shipping-audio733.sh .* linked$/ {
  print;print "bash native-profile/packaging/native/check-avr-transaction733.sh \"$PWD\" %{_uke_out} linked";linked++;next
 }
 mode=="check" && $0=="%install" {
  print "bash native-profile/src/display/apply-avr-transaction733.sh \"$PWD\""
  print "bash native-profile/packaging/native/check-avr-transaction733.sh \"$PWD\" %{_uke_out} source"
  print "bash native-profile/tests/o82-avr-early733.sh \"$PWD\" verify"
  print "make O=%{_uke_out} ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-%{senemos_build_release}-unstable -j4 drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.o drivers/gpu/drm/msm/disp/dpu1/dpu_hw_intf.o"
  print "bash native-profile/packaging/native/check-avr-transaction733.sh \"$PWD\" %{_uke_out} objects";apply++
 }
 {print}
 END{if(apply!=1||linked!=(mode=="full"?1:0)||early!=(mode=="check"?1:0))exit 1}
' "$spec" > "$work/spec"
install -m644 "$work/spec" "$spec"
jq --arg mode "$mode" '.+{
 avr_transaction_layer:1,avr_transaction_sourcecheck_required:true,
 avr_transaction_keeps_atomic_quarantine:true,avr_transaction_full_modeset_rollback:false,
 avr_transaction_physical_accepted:false,
 avr_transaction_native_admitted:($mode=="full")}' "$profile/source-composition.json" > "$work/composition"
install -m644 "$work/composition" "$profile/source-composition.json"
printf 'Cumulative dual-INTF transaction staged:%s; existing gates retained, no new package/config/DT change.\n' "$mode"

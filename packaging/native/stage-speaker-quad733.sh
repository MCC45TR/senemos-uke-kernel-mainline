#!/usr/bin/bash
# Add the hardware quad layer to the one cumulative source/full recipe.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
profile=$(realpath "${1:?Native profile}")
boot=$(realpath "${2:?Boot recipe}")
spec=$(realpath "${3:?Cumulative spec}")
mode=${4:?check or full}
[[ $mode == check || $mode == full ]]
manifest=$owner/manifests/speaker-quad-20261108.json
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
# The full entry independently admits a successful exact-source quad receipt.
# A prepared recipe or fixture source alone does not grant native acceptance.
if [[ $mode == full ]];then
 jq -e '.full_recipe_prepared' "$manifest" >/dev/null
fi
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
for tree in "$profile" "$boot";do
 while IFS= read -r file;do install -Dm644 "$owner/$file" "$tree/$file";done < <(jq -r '.payload_assets[]' "$manifest")
 install -Dm644 "$manifest" "$tree/manifests/${manifest##*/}"
done
awk -v mode="$mode" '
 mode=="check" && $0=="%build" {print;print "bash native-profile/tests/speaker-quad-route.sh";early++;next}
 mode=="check" && $0=="%install" {
  print "bash native-profile/src/audio/apply-speaker-quad733.sh \"$PWD\""
  print "bash native-profile/packaging/native/check-speaker-quad733.sh \"$PWD\" %{_uke_out} source"
  print "make O=%{_uke_out} ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-%{senemos_build_release}-unstable -j4 sound/soc/qcom/qdsp6/q6apm-lpass-dais.o sound/soc/qcom/uke-audio-card.o"
  print "bash native-profile/packaging/native/check-speaker-quad733.sh \"$PWD\" %{_uke_out} objects";apply++
 }
 mode=="full" && /^bash native-profile\/packaging\/native\/check-avr-transaction733.sh .* source$/ {
  print;print "bash native-profile/src/audio/apply-speaker-quad733.sh \"$PWD\""
  print "bash native-profile/packaging/native/check-speaker-quad733.sh \"$PWD\" %{_uke_out} source";apply++;next
 }
 mode=="full" && /^bash native-profile\/packaging\/native\/check-avr-transaction733.sh .* linked$/ {
  print;print "bash native-profile/packaging/native/check-speaker-quad733.sh \"$PWD\" %{_uke_out} linked";linked++;next
 }
 {print}
 END{if(apply!=1||early!=(mode=="check"?1:0)||linked!=(mode=="full"?1:0))exit 1}
' "$spec" > "$work/spec"
install -m644 "$work/spec" "$spec"
jq --arg mode "$mode" '.+{
 speaker_quad_layer:1,speaker_quad_mfc_only:true,
 speaker_quad_physical_protection_map_unchanged:true,
 speaker_quad_graph_lifetime_mutex:true,speaker_quad_rollback_fault:true,
 speaker_quad_new_daemon:false,speaker_quad_native_admitted:($mode=="full"),
 speaker_quad_live_firmware_accepted:false,speaker_quad_physical_accepted:false}' \
 "$profile/source-composition.json" > "$work/composition"
install -m644 "$work/composition" "$profile/source-composition.json"
printf 'Quad speaker program routing staged:%s; source/native/firmware/physical acceptance remain separate.\n' "$mode"

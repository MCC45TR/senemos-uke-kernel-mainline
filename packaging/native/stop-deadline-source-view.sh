#!/usr/bin/env bash
# Sourced by retained checks: admit new bytes before selecting exact old views.
uke_stop_root=$(realpath "${1:?Prepared cumulative kernel}")
uke_stop_codec_view=$uke_stop_root/sound/soc/codecs/fs19xx.c
uke_stop_runtime_view=$uke_stop_root/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c
if [[ -e $uke_stop_root/native-generated/runtime-before-enable-readback.c ]];then
 uke_stop_runtime_view=$(bash "$uke_stop_root/native-profile/packaging/native/speaker-readback-source-view.sh" "$uke_stop_root")
fi
uke_stop_muted_view=$uke_stop_root/sound/soc/codecs/uke-fs19xx-muted-stop.h
if [[ -e $uke_stop_root/native-generated/codec-before-stop-deadline.c ]];then
 for uke_stop_before in codec-before-stop-deadline.c runtime-before-stop-deadline.c muted-before-stop-deadline.h;do
  [[ -f $uke_stop_root/native-generated/$uke_stop_before && ! -L $uke_stop_root/native-generated/$uke_stop_before ]]
 done
 printf '%s  %s\n' \
  7259901dd2d2121d816e7084142ae55fcfe5838a3f5e70affbe42e8dbd55b319 "$uke_stop_codec_view" \
  2db81985157213fbe61d9d58bd997784264fcee05d34f96f9d4fe1474e92205f "$uke_stop_runtime_view" \
  3aad113fa488771192f549e09dbaf118ff86fac70dbf7ad939589fa8d10191f7 "$uke_stop_muted_view" \
  d8a9e70f14fd854e3333352199abc0fb5fe8d632c1bf298b25d01d931cc494cb "$uke_stop_root/native-generated/codec-before-stop-deadline.c" \
  d9bf78985dd1de6db50daddce2c544d2b88496b085f821bcfdab86a44c4da157 "$uke_stop_root/native-generated/runtime-before-stop-deadline.c" \
  aac729f7c7c893cf69048da8c21c8c0cdf078dd9563ddf0a594c63323a004955 "$uke_stop_root/native-generated/muted-before-stop-deadline.h" | sha256sum -c --strict --quiet -
 jq -e '.muted_stop_deadline_layer==1 and .muted_stop_deadline_ms==6000 and
  .muted_stop_all_readbacks_before_mode1 and .muted_stop_faults_retained and
  .muted_stop_startup_poll_budget_unchanged and .speaker_gain_ceiling==223 and
  (.physical_acceptance|not)' "$uke_stop_root/native-profile/source-composition.json" >/dev/null
 uke_stop_codec_view=$uke_stop_root/native-generated/codec-before-stop-deadline.c
 uke_stop_runtime_view=$uke_stop_root/native-generated/runtime-before-stop-deadline.c
 uke_stop_muted_view=$uke_stop_root/native-generated/muted-before-stop-deadline.h
fi

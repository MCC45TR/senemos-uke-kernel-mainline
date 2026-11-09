#!/usr/bin/bash
# COPR cumulative delivery only; callbacks were qualified by source65/67.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Cumulative kernel}")
out=$(realpath -m "${2:?Production output}")
phase=${3:?source, verify, linked or install}
[[ $phase == source || $phase == verify || $phase == linked || $phase == install ]]
profile=$kernel/native-profile
work=$kernel/native-generated/surround-full733
core=$kernel/sound/soc/qcom/qdsp6
if [[ $phase == source ]];then
 [[ ! -e $work ]]
 mkdir -p "$work/quad-before" "$work/inverse/sound/soc/codecs" "$work/inverse/sound/soc/qcom/qdsp6"
 for name in q6apm-lpass-dais.c q6apm-dai.c audioreach.c uke-speaker-quad.h uke-speaker-quad-lpass.h uke-speaker-quad-wire.h uke-speaker-quad-apm.h uke-speaker-quad-transport.h;do
  cp "$core/$name" "$work/quad-before/$name"
 done
 cp "$kernel/sound/soc/codecs/fs19xx.c" "$work/codec-before.c"
 cp "$kernel/sound/soc/codecs/uke-fs19xx-muted-stop.h" "$work/muted-before.h"
 printf '%s  %s\n' 7259901dd2d2121d816e7084142ae55fcfe5838a3f5e70affbe42e8dbd55b319 "$work/codec-before.c" \
  3aad113fa488771192f549e09dbaf118ff86fac70dbf7ad939589fa8d10191f7 "$work/muted-before.h" | sha256sum -c --strict --quiet -
 for patch in src/audio/0030-audioreach-surround-channel-map.patch src/audio/0031-fs19xx-freezable-health.patch;do
  git -C "$kernel" apply --check --whitespace=error "$profile/$patch"
  git -C "$kernel" apply --whitespace=error "$profile/$patch"
 done
 # The entire old files, not just six expected lines, must be recovered.
 cp "$kernel/sound/soc/codecs/fs19xx.c" "$work/inverse/sound/soc/codecs/"
 cp "$kernel/sound/soc/codecs/uke-fs19xx-muted-stop.h" "$work/inverse/sound/soc/codecs/"
 cp "$core/audioreach.c" "$work/inverse/sound/soc/qcom/qdsp6/"
 git -C "$work/inverse" init -q
 for patch in src/audio/0031-fs19xx-freezable-health.patch src/audio/0030-audioreach-surround-channel-map.patch;do
  git -C "$work/inverse" apply -R --whitespace=error "$profile/$patch"
 done
 cmp "$work/codec-before.c" "$work/inverse/sound/soc/codecs/fs19xx.c"
 cmp "$work/muted-before.h" "$work/inverse/sound/soc/codecs/uke-fs19xx-muted-stop.h"
 cmp "$work/quad-before/audioreach.c" "$work/inverse/sound/soc/qcom/qdsp6/audioreach.c"
 [[ $(grep -Fc 'mod_delayed_work(system_freezable_wq, &fs19xx->unmute_work,' "$kernel/sound/soc/codecs/fs19xx.c") == 5 ]]
 [[ $(grep -Fc 'mod_delayed_work(system_freezable_wq, &fs19xx->unmute_work,' "$kernel/sound/soc/codecs/uke-fs19xx-muted-stop.h") == 1 ]]
 bash "$profile/src/audio/apply-speaker-surround733.sh" "$kernel"
 awk '$0!="\tunsigned int uke_quad_inputs;"{print}' "$core/q6apm-lpass-dais.c" | cmp - "$work/quad-before/q6apm-lpass-dais.c"
 awk '
  $0=="#include \"uke-speaker-surround-fe.h\"" {skip=1;next}
  skip {if($0!="")exit 1;skip=0;next}
  $0=="\tret = uke_surround_fe_open(substream, graph_id);" {call=3;next}
  call {call--;next}
  $0=="\treturn uke_surround_fe_chmap(pcm, graph_id);" {print "\treturn 0;";next}
  {print}END{if(skip||call)exit 1}
 ' "$core/q6apm-dai.c" | cmp - "$work/quad-before/q6apm-dai.c"
 cmp "$profile/src/audio/uke-speaker-surround-lpass.h" "$core/uke-speaker-quad-lpass.h"
 bash "$profile/src/audio/prepare-surround-profiles733.sh" "$kernel"
 cp "$kernel/native-generated/surround-profiles733/topology.conf" "$kernel/native-generated/POCO-Pad-X1.conf"
 alsatplg -c "$kernel/native-generated/POCO-Pad-X1.conf" -o "$kernel/native-generated/POCO-Pad-X1-tplg.bin"
 paths=(sound/soc/codecs/fs19xx.c sound/soc/codecs/uke-fs19xx-muted-stop.h)
 for name in q6apm-lpass-dais.c q6apm-dai.c audioreach.c uke-speaker-quad-lpass.h uke-speaker-surround-fe.h uke-speaker-surround-stream.h;do paths+=(sound/soc/qcom/qdsp6/$name);done
 paths+=(native-generated/POCO-Pad-X1.conf native-generated/POCO-Pad-X1-tplg.bin)
 (cd "$kernel";sha256sum "${paths[@]}") > "$work/applied.sha256"
 (cd "$work";sha256sum codec-before.c muted-before.h quad-before/*) > "$work/legacy.sha256"
 printf 'Full surround source: complete map/freezer/FE inverses and protected topology retained; four physical outputs and gain223.\n'
 exit 0
fi
(cd "$kernel";sha256sum -c --strict --quiet "$work/applied.sha256")
(cd "$work";sha256sum -c --strict --quiet "$work/legacy.sha256")
[[ $phase != verify ]] || exit 0
if [[ $phase == install ]];then
 destination=${4:?Existing RPM buildroot}
 driver=$(bash "$profile/scripts/kernel-release.sh" json "$profile/manifests/cumulative-release.json" | jq -er .audio_driver)
 ucm=$destination/usr/share/alsa/ucm2/Qualcomm/$driver
 [[ -s $ucm/Speaker-HiFi.conf && -s $ucm/POCO-Pad-X1.conf ]]
 for name in POCO-Pad-X1 Speaker-Surround51 Speaker-Surround71;do
  sed "s/@UKE_AUDIO_DRIVER@/$driver/g" "$kernel/native-generated/surround-profiles733/ucm/$name.conf" > "$ucm/$name.conf"
  chmod 644 "$ucm/$name.conf"
 done
 release=$(jq -er .kernel_release "$profile/source-composition.json")
 rule=$destination/usr/share/wireplumber/wireplumber.conf.d/95-uke-microphone-array-$release.conf
 cp "$rule" "$work/scoped-microphone-before.json"
 jq '."monitor.alsa.rules"[].matches[] |= if ."node.name"=="alsa_input.platform-sound-uke.HiFi__Mic__source" then ."node.name"="~alsa_input[.]platform-sound-uke[.].*__Mic__source" else . end' "$rule" > "$work/scoped-microphone-surround.json"
 jq '."monitor.alsa.rules"[].matches[] |= if ."node.name"=="~alsa_input[.]platform-sound-uke[.].*__Mic__source" then ."node.name"="alsa_input.platform-sound-uke.HiFi__Mic__source" else . end' "$work/scoped-microphone-surround.json" | jq -S . > "$work/scoped-inverse.json"
 jq -S . "$work/scoped-microphone-before.json" > "$work/scoped-original.json"
 cmp "$work/scoped-inverse.json" "$work/scoped-original.json"
 install -m644 "$work/scoped-microphone-surround.json" "$rule"
 sed "s/@UKE_AUDIO_DRIVER@/$driver/g" "$profile/src/audio/desktop/array-ucm2/Speaker-HiFi.conf" | cmp - "$ucm/Speaker-HiFi.conf"
 cmp "$profile/src/audio/desktop/wireplumber/80-uke-microphone-array.conf" "$destination/usr/share/wireplumber/wireplumber.conf.d/80-uke-microphone-array.conf"
 printf 'Full surround package: two original UCM verbs and version-scoped capture merge installed; quad/global rules and old-kernel directories retained.\n'
 exit 0
fi
for name in sound/soc/codecs/fs19xx sound/soc/qcom/qdsp6/q6apm-dai sound/soc/qcom/qdsp6/q6apm-lpass-dais sound/soc/qcom/qdsp6/snd-q6apm;do
 llvm-readelf -h "$out/$name.o" | grep -F AArch64
 llvm-nm "$out/$name.o" > "$work/${name##*/}.symbols"
done
grep -E '[[:space:]]U[[:space:]]+system_freezable_wq$' "$work/fs19xx.symbols"
! grep -E '[[:space:]]U[[:space:]]+system_percpu_wq$' "$work/fs19xx.symbols"
grep -E '[[:space:]]U[[:space:]]+snd_pcm_add_chmap_ctls$' "$work/q6apm-dai.symbols"
for symbol in audioreach_uke_quad_matrix audioreach_uke_surround_matrix;do
 grep -E "[[:space:]]U[[:space:]]+$symbol$" "$work/q6apm-lpass-dais.symbols"
 grep -E "[[:space:]]T[[:space:]]+$symbol$" "$work/snd-q6apm.symbols"
 grep -E "[[:space:]]$symbol[[:space:]]" "$out/Module.symvers"
 llvm-nm "$out/sound/soc/qcom/qdsp6/snd-q6apm.ko" | grep -E "[[:space:]]T[[:space:]]+$symbol$"
done
for module in sound/soc/codecs/snd-soc-fs19xx sound/soc/qcom/qdsp6/snd-q6apm sound/soc/qcom/qdsp6/q6apm-dai sound/soc/qcom/qdsp6/q6apm-lpass-dais;do
 [[ $(modinfo -F vermagic "$out/$module.ko") == "$(cat "$out/include/config/kernel.release") "* ]]
done
printf 'Full surround linked: real protected MFC exports, FE channel controls and freezable codec resolve; no firmware or physical acceptance.\n'

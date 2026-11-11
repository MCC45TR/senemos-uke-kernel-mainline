#!/usr/bin/bash
# COPR source-only profile preparation. Never invoked by a target runtime.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
profile=$kernel/native-profile
work=$kernel/native-generated/surround-profiles733
topology=$kernel/native-generated/POCO-Pad-X1.conf
ucm=$profile/src/audio/desktop/array-ucm2
[[ ! -e $work && -s $topology && -s $ucm/Speaker-HiFi.conf && -s $ucm/POCO-Pad-X1.conf ]]
mkdir -p "$work/ucm"
cp "$topology" "$work/topology-before.conf"
awk '
 /^SectionPCMCapabilities[.]"MultiMedia2 Playback"/ {caps=1;found++}
 caps&&$1=="channels_min" {if($2!="\"4\"")exit 1;min++}
 caps&&$1=="channels_max" {if($2!="\"4\"")exit 1;print "    channels_max \"8\"";max++;next}
 caps&&/^}/ {caps=0}
 {print}
 END{if(found!=1||min!=1||max!=1||caps)exit 1}
' "$topology" > "$work/topology.conf"
# Retain the complete protected graph and all other FE/BE capabilities.
awk '
 /^SectionPCMCapabilities[.]"MultiMedia2 Playback"/ {caps=1}
 caps&&$1=="channels_max" {if($2!="\"8\"")exit 1;print "    channels_max \"4\"";n++;next}
 caps&&/^}/ {caps=0}
 {print}
 END{if(n!=1)exit 1}
' "$work/topology.conf" | cmp - "$topology"
for channels in 6 8;do
 [[ $channels == 6 ]] && name=51 || name=71
 awk -v channels="$channels" '
  $0=="\t\tPlaybackChannels 4" {print "\t\tPlaybackChannels "channels;count++;next}
  $0=="\t\tPlaybackPCM \"uke_speakers:${CardId}\"" {print "\t\tPlaybackPCM \"hw:${CardId},1\"";pcm++;next}
  {print}
  END{if(count!=1||pcm!=1)exit 1}
 ' "$ucm/Speaker-HiFi.conf" > "$work/ucm/Speaker-Surround$name.conf"
done
cp "$ucm/POCO-Pad-X1.conf" "$work/ucm/POCO-Pad-X1.conf"
cat >> "$work/ucm/POCO-Pad-X1.conf" <<'UCM'

# Six/eight program channels are rendered to four protected physical outputs.
SectionUseCase."HiFiSurround51" {
 File "/Qualcomm/@UKE_AUDIO_DRIVER@/Speaker-Surround51.conf"
 Comment "5.1 input to four internal speakers through ADSP"
}
SectionUseCase."HiFiSurround71" {
 File "/Qualcomm/@UKE_AUDIO_DRIVER@/Speaker-Surround71.conf"
 Comment "7.1 input to four internal speakers through ADSP"
}
UCM
# Capture keeps physical AUX identities under both new verbs. Delivery folds
# this into the existing kernel-version-scoped rule; the global rule stays.
jq '."monitor.alsa.rules"[].matches[] |= if ."node.name"=="alsa_input.platform-sound-uke.HiFi__Mic__source" then
 ."node.name"="~alsa_input[.]platform-sound-uke[.].*__Mic__source" else . end' \
 "$profile/src/audio/desktop/wireplumber/80-uke-microphone-array.conf" > "$work/microphone-rules.conf"
# This is a staged tree. Delivery must preserve the old verb and use the
# existing version-specific UCM installation path, without altering old kernels.
printf 'Protected topology and original UCM surround profiles staged; no installed file, gain or runtime state changed.\n'

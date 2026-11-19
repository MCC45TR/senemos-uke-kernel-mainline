#!/usr/bin/bash
set -Eeuo pipefail
[[ $# == 3 ]]
spec=$1 root=$2 release=$3
family=senemos-uke-linux-kernel-mainline
[[ $release == 7.4.5-senemos ]]
evr=$(rpmspec --target aarch64 -q --srpm --qf '%{VERSION}-%{RELEASE}' "$spec")
names=$(rpmspec --target aarch64 -q --qf '%{NAME}\n' "$spec")
[[ $names == "$(printf '%s\n' "$family" "$family-core" "$family-singleboot")" ]]
parsed=$(rpmspec --target aarch64 --parse "$spec")
grep -Fxq "Provides: kernel-uname-r($release)" <<< "$parsed"
grep -Fxq 'Provides: uke-kernel(merged-layout-v1) = 1' <<< "$parsed"
grep -Fxq 'Requires: uke-control >= 2.17.0-47' <<< "$parsed"
for alias in modules dtbs boot; do
    grep -Fxq "Requires: $family-$alias = $evr" <<< "$parsed"
    grep -Fxq "Provides: $family-$alias = $evr" <<< "$parsed"
done
if grep -Eq "^Conflicts: $family(-core|-singleboot)?$|^Obsoletes:|^%(pre|post|preun|postun|pretrans|posttrans|trigger[a-z]*)($|[[:space:]])" <<< "$parsed"; then
    exit 1
fi
identity=$root/usr/share/senemos/uke/$release
bundle=$root/usr/lib/senemos/kernel-updates/$release
[[ $(readlink "$root/usr/lib/senemos/default-boot.img") == "kernel-updates/$release/userdata.img" ]]
[[ -s $root/usr/lib/modules/$release/vmlinuz && -s $bundle/linux.img && -s $bundle/userdata.img ]]
grep -Fxq "kernel_release=$release" "$bundle/manifest"
jq -e --arg release "$release" --arg name "$family-singleboot" '
    .kernel_release==$release and .package==$name and .automatic_kernel_activation==false
' "$root/usr/share/senemos/uke/singleboot.json" >/dev/null
jq -e --arg release "$release" --arg source "$(< "$identity/source-commit")" --arg family "$family" '
    .kernel_release==$release and .source_commit==$source and .upstream_version=="7.3.5" and
    .publication.family==$family and .publication.parent_copr_build==11360422 and
    .publication.source_kernel_release==("7.3.5-"+.rpm_revision+"-unstable") and .speaker_gain_ceiling==223
' "$identity/source-composition.json" >/dev/null
audio_release=${evr%.fc46}u
driver=uke${audio_release//./_}
[[ ${#driver} -lt 16 ]]
[[ -d $root/usr/share/alsa/ucm2/Qualcomm/$driver && -d $root/usr/share/alsa/ucm2/conf.d/$driver ]]
topology=$root/usr/lib/firmware/$release/qcom/uke$audio_release/POCO-Pad-X1-tplg.bin
[[ -L $topology && -r $topology ]]
grep -Fq "kernel:$release" "$root/usr/share/wireplumber/wireplumber.conf.d/95-uke-microphone-array-$release.conf"
printf 'Normal merged family, runtime ABI, boot pairing and audio identity passed\n'

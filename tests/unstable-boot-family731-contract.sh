#!/usr/bin/env bash
# RPM metadata and installed paths only. Does not compile or access hardware.
set -Eeuo pipefail
spec=${1:?Diagnostic spec}
diagnostics=$(mktemp)
trap 'rm -f "$diagnostics"' EXIT
query() {
 rpmspec --target aarch64 "$@" "$spec" 2> "$diagnostics"
 cat "$diagnostics" >&2
 if grep -q '^error:' "$diagnostics"; then return 1; fi
}
expected=senemos-uke-linux-kernel-mainline-unstable
[[ $(query -q --srpm --qf '%{NAME}') == "$expected" ]]
names=$(query -q --qf '%{NAME}\n')
[[ $names == "$expected"$'\n'"$expected-core"$'\n'"$expected-modules"$'\n'"$expected-dtbs"$'\n'"$expected-boot"$'\n'"$expected-singleboot" ]]
parsed=$(query --parse)
grep -Eq '^Provides: kernel-uname-r\(7[.]3[.]1-[1-9][0-9]*-unstable\)$' <<< "$parsed"
kernel_release=$(sed -n 's/^Provides: kernel-uname-r(\([^)]*\))$/\1/p' <<< "$parsed")
audio_release=${kernel_release%-unstable}u
audio_driver=uke${audio_release//./_}
[[ ${#audio_driver} -lt 16 ]]
grep -Fq "/qcom/uke$audio_release/POCO-Pad-X1-tplg.bin" <<< "$parsed"
grep -Fq "/usr/share/alsa/ucm2/Qualcomm/$audio_driver/" <<< "$parsed"
grep -Fq '"automatic_kernel_activation": false' <<< "$parsed"
if grep -E '^Obsoletes:|^Conflicts:|^%(pre|post|preun|postun|pretrans|posttrans|trigger[a-z]*)($|[[:space:]])' <<< "$parsed"; then
 echo 'Diagnostic RPMs must coexist without activation scriptlets' >&2; exit 1
fi
if grep -E '/senemos/default-boot[.]img|uke/singleboot[.]json' <<< "$parsed"; then
 echo 'Diagnostic family must not own the accepted profile selection' >&2; exit 1
fi
if [[ $# == 3 ]]; then
 root=$2 release=$3
 [[ $(readlink "$root/usr/lib/senemos/unstable-default-boot.img") == "kernel-updates/$release/userdata.img" ]]
 [[ ! -e $root/usr/lib/senemos/default-boot.img && ! -e $root/usr/share/senemos/uke/singleboot.json ]]
 jq -e --arg release "$release" '.kernel_release==$release and .automatic_kernel_activation==false' "$root/usr/share/senemos/uke/unstable-singleboot.json" >/dev/null
 [[ -f $root/usr/lib/modules/$release/vmlinuz ]]
 audio_release=${release%-unstable}u
 driver=uke${audio_release//./_}
 [[ ${#driver} -lt 16 ]]
 [[ -d $root/usr/share/alsa/ucm2/Qualcomm/$driver && -d $root/usr/share/alsa/ucm2/conf.d/$driver ]]
 topology=$root/usr/lib/firmware/$release/qcom/uke$audio_release/POCO-Pad-X1-tplg.bin
 [[ -L $topology && -r $topology ]]
 grep -Fq "kernel:$release" "$root/usr/share/wireplumber/wireplumber.conf.d/95-uke-microphone-array-$release.conf"
fi
printf 'Isolated unstable family, unique Image ABI and explicit trial selection passed\n'

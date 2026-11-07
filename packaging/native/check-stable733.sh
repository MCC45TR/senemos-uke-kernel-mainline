#!/usr/bin/env bash
# COPR only. Actual upstream tuple, cumulative source and affected native objects.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative source}")
out=$(realpath "${2:?Native output}")
phase=${3:-objects}
[[ $phase == objects || $phase == linked ]]
profile=$kernel/native-profile
bash "$profile/packaging/native/check-vrr-api731.sh" "$kernel" "$out" "$phase"
awk '$1=="VERSION"{v=$3}$1=="PATCHLEVEL"{p=$3}$1=="SUBLEVEL"{s=$3}
 END{if(v"."p"."s!="7.3.3")exit 1}' "$kernel/Makefile"
[[ $(make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-1-unstable kernelrelease) == 7.3.3-1-unstable ]]
jq -e '.upstream_version=="7.3.3" and .upstream_commit=="d50d994bffa3c7c6db2d8bc4c5f0c55e3f46b0cd" and .upstream_sha256=="79c66dde66cd96877fcde8f7d36aec946b1f423d2b97b5a7b1751b75c764f3d1" and .upstream_stable_cumulative_layer==1 and .upstream_stable_parent_build==11282652 and .kernel_release=="7.3.3-1-unstable" and .rpm_revision=="1" and .speaker_gain_ceiling==223 and (.physical_acceptance|not)' "$profile/source-composition.json" >/dev/null
jq -S 'del(.source_commit,.rpm_revision,.kernel_release,.diagnostic_audio_driver,.upstream_version,.upstream_commit,.upstream_sha256)' "$profile/manifests/kernel-migration-full12217-20261107.json" > "$out/stable733-parent-fields.json"
jq --slurpfile parent "$out/stable733-parent-fields.json" -e '
 . as $next | $parent[0] as $old | ($old|length)==460 and
 all($old|to_entries[]; $next[.key]==.value)' "$profile/source-composition.json" >/dev/null
for path in drivers/base/core.o drivers/base/dd.o drivers/gpu/drm/msm/msm_gem_shrinker.o drivers/usb/core/driver.o drivers/usb/core/message.o sound/core/control.o;do
 llvm-readelf -h "$out/$path" | grep -E 'Machine:.*AArch64'
done
printf 'Actual Linux7.3.3 tuple,460 retained parent feature fields and six changed upstream native objects passed:%s; physical acceptance separate.\n' "$phase"

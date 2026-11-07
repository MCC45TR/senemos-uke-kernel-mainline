#!/usr/bin/env bash
# COPR only. Actual upstream tuple, cumulative source and affected native objects.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative source}")
out=$(realpath "${2:?Native output}")
phase=${3:-objects}
[[ $phase == objects || $phase == linked ]]
profile=$kernel/native-profile
tuple=$(bash "$profile/scripts/kernel-release.sh" json "$profile/manifests/cumulative-release.json")
version=$(jq -er .version <<< "$tuple")
localversion=$(jq -er .localversion <<< "$tuple")
release=$(jq -er .kernel_release <<< "$tuple")
bash "$profile/packaging/native/check-vrr-api731.sh" "$kernel" "$out" "$phase"
awk -v expected="$version" '$1=="VERSION"{v=$3}$1=="PATCHLEVEL"{p=$3}$1=="SUBLEVEL"{s=$3}
 END{if(v"."p"."s!=expected)exit 1}' "$kernel/Makefile"
[[ $(make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION="$localversion" kernelrelease) == "$release" ]]
jq -e --argjson tuple "$tuple" '.upstream_version==$tuple.version and .upstream_commit==$tuple.upstream.commit and .upstream_sha256==$tuple.upstream.source_sha256 and .upstream_stable_cumulative_layer==1 and .upstream_stable_parent_build==11282652 and .kernel_release==$tuple.kernel_release and .rpm_revision==($tuple.release|tostring) and .speaker_gain_ceiling==223 and (.physical_acceptance|not)' "$profile/source-composition.json" >/dev/null
jq -S 'del(.source_commit,.rpm_revision,.kernel_release,.diagnostic_audio_driver,.upstream_version,.upstream_commit,.upstream_sha256)' "$profile/manifests/kernel-migration-full12217-20261107.json" > "$out/stable733-parent-fields.json"
jq --slurpfile parent "$out/stable733-parent-fields.json" -e '
 . as $next | $parent[0] as $old | ($old|length)==460 and
 all($old|to_entries[]; $next[.key]==.value)' "$profile/source-composition.json" >/dev/null
for path in drivers/firmware/arm_scmi/uke-cpucp-observe.o drivers/nvmem/core.o drivers/base/core.o drivers/base/dd.o drivers/gpu/drm/msm/msm_gem_shrinker.o drivers/usb/core/driver.o drivers/usb/core/message.o sound/core/control.o;do
 llvm-readelf -h "$out/$path" | grep -E 'Machine:.*AArch64'
done
printf 'Actual Linux%s tuple,460 retained parent feature fields and eight upstream and compiled-ABI observer native objects passed:%s; physical acceptance separate.\n' "$version" "$phase"

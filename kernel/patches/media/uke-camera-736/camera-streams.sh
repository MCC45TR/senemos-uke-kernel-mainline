#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -Eeuo pipefail
export LC_ALL=C
[[ $# -ge 4 && $1 == run ]]
tree=$(realpath -e -- "$2")
out=$3
shift 3
assets=$(cd -- "$(dirname -- "$0")" && pwd -P)
groups=(sensors/rear-stream sensors/front-stream receiver/stream-graph)
scripts=(prepare-rear-stream.sh prepare-front-stream.sh prepare-stream-graph.sh)
config=$tree/boot-recipe/packaging/native/native.config

(cd "$assets"; sha256sum -c --strict --quiet SHA256SUMS)
[[ -f $config && ! -L $config ]]
[[ $(grep -Fxc CONFIG_VIDEO_OV08D10=m "$config") == 1 ]]
[[ $(grep -Fxc CONFIG_VIDEO_OV13B10=m "$config") == 1 ]]
backup=$(mktemp --tmpdir="$tree" .uke-sensor-config.XXXXXXXX)
cp -p -- "$config" "$backup"
applied=0
restore_camera_source() {
    local status=$?
    trap - EXIT
    cp -p -- "$backup" "$config" || status=44
    rm -f -- "$backup"
    while ((applied)); do
        applied=$((applied - 1))
        bash "$assets/${groups[applied]}/${scripts[applied]}" restore "$tree" || status=44
    done
    exit "$status"
}
trap restore_camera_source EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
for index in "${!groups[@]}"; do
    bash "$assets/${groups[index]}/${scripts[index]}" prepare "$tree"
    applied=$((applied + 1))
done
sed -i -e 's/^CONFIG_VIDEO_OV08D10=m$/CONFIG_VIDEO_OV08D10=y/' \
    -e 's/^CONFIG_VIDEO_OV13B10=m$/CONFIG_VIDEO_OV13B10=y/' "$config"
"$@"

out=$(realpath -e -- "$out")
for setting in VIDEO_OV08D10 VIDEO_OV13B10 VIDEO_QCOM_CAMSS SM_CAMCC_7675; do
    grep -Fx "CONFIG_$setting=y" "$out/.config"
done
grep -Fx CONFIG_I2C_QCOM_CCI=m "$out/.config"
result=$out/uke-camera-streams
mkdir -p "$result"
objects=(arch/arm64/kernel/uke-abl.o drivers/media/i2c/ov13b10.o drivers/media/i2c/ov08d10.o)
for object in "${objects[@]}"; do
    llvm-readelf -h "$out/$object" | grep -E 'Machine:[[:space:]]+AArch64'
done
strings "$out/${objects[0]}" > "$result/boot-strings"
for marker in port@1 port@4 xiaomi,uke-ov13b10 xiaomi,uke-ov08d10; do
    grep -Fx "$marker" "$result/boot-strings"
done
llvm-nm "$out/vmlinux" > "$result/linked-symbols"
grep -E ' [tT] ov13b10_uke_shutdown$' "$result/linked-symbols"
grep -E ' [tT] ov08d10_uke_shutdown$' "$result/linked-symbols"
(cd "$out"; sha256sum "${objects[@]}") > "$result/objects.sha256"
(cd "$tree"; sha256sum -c --strict --quiet "$assets/final-stream-source.sha256")
install -m644 "$assets/final-stream-source.sha256" "$result/source.sha256"

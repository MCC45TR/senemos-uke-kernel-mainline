#!/usr/bin/bash
# COPR only: preserve the complete admitted parent before adding MST depth.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
out=$(realpath "${2:?Existing native output}")
profile=$kernel/native-profile
work=$kernel/native-generated/mst-depth733
[[ ! -e $work ]]
mkdir -p "$work/before"
files=(drivers/gpu/drm/msm/dp/dp_mst_drm.c drivers/gpu/drm/msm/dp/dp_display.c \
 drivers/gpu/drm/msm/msm_drv.h drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c)
for file in "${files[@]}";do install -Dm644 "$kernel/$file" "$work/before/$file";done
printf '%s  %s\n' 29a0481cae114bb5c2a15426af20717d2fa176b0ad9982bd1601c9ac43a60145 \
 "$kernel/drivers/gpu/drm/msm/dp/dp_mst_drm.c" | sha256sum -c --strict --quiet -
patch=$profile/src/display/0001-uke-mst-stream-depth733.patch
git -C "$kernel" apply --check --whitespace=error "$patch"
git -C "$kernel" apply --whitespace=error "$patch"
ulimit -c 0
for compiler in gcc clang;do
 for mode in 0 1;do
  CC=$compiler SANITIZE=$mode bash "$profile/tests/dp-mst-depth733.sh" "$kernel"
  printf 'Actual MST stream depth callbacks passed:%s/sanitize%s; no physical multisink acceptance.\n' "$compiler" "$mode"
 done
done
# A fixed 24-bpp publication must fail the real two-depth callback fixture.
sed 's/to_mst_state(conn_state)->bpp = bpp;/to_mst_state(conn_state)->bpp = 24;/' \
 "$kernel/drivers/gpu/drm/msm/dp/dp_mst_drm.c" > "$work/wrong-bpp.c"
status=0
CC=gcc SANITIZE=0 MST_DEPTH_SOURCE="$work/wrong-bpp.c" \
 bash "$profile/tests/dp-mst-depth733.sh" "$kernel" > "$work/negative.log" 2>&1 || status=$?
[[ $status == 134 ]]
grep -F 'to_mst_state(cs)->bpp==30' "$work/negative.log"
printf 'Fixed eight-bit MST publication refused by actual callbacks/status134.\n'
# Invert the entire four translation units, including other workstreams edits.
mkdir "$work/inverse"
git -C "$work/inverse" init -q
for file in "${files[@]}";do install -Dm644 "$kernel/$file" "$work/inverse/$file";done
git -C "$work/inverse" apply -R --whitespace=error "$patch"
for file in "${files[@]}";do cmp "$work/before/$file" "$work/inverse/$file";done
release=$(jq -er .full_release "$profile/manifests/cumulative-release.json")
objects=(drivers/gpu/drm/msm/dp/dp_mst_drm.o drivers/gpu/drm/msm/dp/dp_display.o \
 drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.o)
for file in "${objects[@]}";do rm -f -- "$out/$file";done
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 \
 LOCALVERSION="-$release-unstable" KCFLAGS=-Werror W=1 -j4 "${objects[@]}"
for file in "${objects[@]}";do llvm-readelf -h "$out/$file" | grep -F AArch64;done
llvm-nm "$out/drivers/gpu/drm/msm/dp/dp_mst_drm.o" | grep -E '[[:space:]]T[[:space:]]+msm_dp_mst_output_bpc$'
for file in drivers/gpu/drm/msm/dp/dp_display.o drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.o;do
 llvm-nm "$out/$file" | grep -E '[[:space:]]U[[:space:]]+msm_dp_mst_output_bpc$'
done
printf 'Actual AArch64 MST/DP/DPU depth objects, whole-source inverse and retained parent gates passed; full linkage and physical multisink acceptance remain separate.\n'

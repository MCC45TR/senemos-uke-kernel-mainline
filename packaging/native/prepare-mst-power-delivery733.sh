#!/usr/bin/bash
# Full-build source application and linked proof; native callbacks are qualified57.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Cumulative kernel}")
out=$(realpath -m "${2:?Production output}")
phase=${3:?source or linked}
[[ $phase == source || $phase == linked ]]
profile=$kernel/native-profile
work=$kernel/native-generated/mst-power-delivery733
files=(drivers/soc/qcom/uke-platform-profile.c drivers/gpu/drm/msm/dp/dp_mst_drm.c \
 drivers/gpu/drm/msm/dp/dp_display.c drivers/gpu/drm/msm/msm_drv.h \
 drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c)
if [[ $phase == source ]];then
 [[ ! -e $work ]]
 mkdir -p "$work/before"
 for file in "${files[@]}";do install -Dm644 "$kernel/$file" "$work/before/$file";done
 before=$(jq -er .driver_before_sha256 "$profile/manifests/platform-profile-response-20261109.json")
 after=$(jq -er .driver_after_sha256 "$profile/manifests/platform-profile-response-20261109.json")
 printf '%s  %s\n' "$before" "$kernel/${files[0]}" \
  29a0481cae114bb5c2a15426af20717d2fa176b0ad9982bd1601c9ac43a60145 "$kernel/${files[1]}" | sha256sum -c --strict --quiet -
 for patch in src/power/0001-uke-saver-allow-cpu-bursts.patch src/display/0001-uke-mst-stream-depth733.patch;do
  git -C "$kernel" apply --check --whitespace=error "$profile/$patch"
  git -C "$kernel" apply --whitespace=error "$profile/$patch"
 done
 printf '%s  %s\n' "$after" "$kernel/${files[0]}" | sha256sum -c --strict --quiet -
 (cd "$kernel";sha256sum "${files[@]}") > "$work/applied.sha256"
 # Whole-source inverse, independent of the prepared kernel nested Git context.
 mkdir "$work/inverse"
 git -C "$work/inverse" init -q
 for file in "${files[@]}";do install -Dm644 "$kernel/$file" "$work/inverse/$file";done
 for patch in src/display/0001-uke-mst-stream-depth733.patch src/power/0001-uke-saver-allow-cpu-bursts.patch;do
  git -C "$work/inverse" apply -R --whitespace=error "$profile/$patch"
 done
 for file in "${files[@]}";do cmp "$work/before/$file" "$work/inverse/$file";done
 printf 'Full MST/power source: two qualified patches applied; five whole-source inverses passed.\n'
 exit 0
fi
(cd "$kernel";sha256sum -c --strict --quiet "$work/applied.sha256")
for object in drivers/soc/qcom/uke-platform-profile.o drivers/gpu/drm/msm/dp/dp_mst_drm.o \
 drivers/gpu/drm/msm/dp/dp_display.o drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.o;do
 llvm-readelf -h "$out/$object" | grep -F AArch64
done
llvm-nm "$out/drivers/gpu/drm/msm/dp/dp_mst_drm.o" | grep -E '[[:space:]]T[[:space:]]+msm_dp_mst_output_bpc$'
for object in dp/dp_display.o disp/dpu1/dpu_encoder.o;do
 llvm-nm "$out/drivers/gpu/drm/msm/$object" | grep -E '[[:space:]]U[[:space:]]+msm_dp_mst_output_bpc$'
done
llvm-nm "$out/drivers/gpu/drm/msm/msm.ko" > "$work/msm-linked-symbols.txt"
grep -E '[[:space:]]T[[:space:]]+msm_dp_mst_output_bpc$' "$work/msm-linked-symbols.txt"
if grep -E '[[:space:]]U[[:space:]]+msm_dp_mst_output_bpc$' "$work/msm-linked-symbols.txt";then exit 1;fi
llvm-nm "$out/vmlinux" | awk '$NF=="uke_profile_set"{found=1}END{exit !found}'
[[ $(modinfo -F vermagic "$out/drivers/gpu/drm/msm/msm.ko") == "$(cat "$out/include/config/kernel.release") "* ]]
# Crypto56 is separately qualified. This candidate preserves the exact existing
# production config; no volume or encrypted-boot capability is silently claimed.
cmp "$profile/native.config" "$kernel/boot-recipe/packaging/native/native.config"
grep -Fx '# CONFIG_DM_CRYPT is not set' "$out/.config"
grep -Fx '# CONFIG_FS_ENCRYPTION is not set' "$out/.config"
printf 'Full MST/power linked: actual ARM64 DP/DPU accessor resolves in msm.ko and saver provider in vmlinux; production config retained.\n'

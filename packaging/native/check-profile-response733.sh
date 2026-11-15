#!/usr/bin/bash
# COPR-only source experiment; no delivered kernel or hardware setting changes.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
out=$(realpath "${2:?Existing native output}")
profile=$kernel/native-profile
manifest=$profile/manifests/platform-profile-response-20261109.json
driver=drivers/soc/qcom/uke-platform-profile.c
before=$(jq -er .driver_before_sha256 "$manifest")
after=$(jq -er .driver_after_sha256 "$manifest")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
ulimit -c 0
printf '%s  %s\n' "$before" "$kernel/$driver" | sha256sum -c --strict --quiet -
cp "$kernel/$driver" "$work/before.c"
git -C "$kernel" apply --check --whitespace=error "$profile/src/power/0001-uke-saver-allow-cpu-bursts.patch"
git -C "$kernel" apply --whitespace=error "$profile/src/power/0001-uke-saver-allow-cpu-bursts.patch"
printf '%s  %s\n' "$after" "$kernel/$driver" | sha256sum -c --strict --quiet -
for cc in gcc clang;do
 for sanitize in 0 1;do
  CC=$cc SANITIZE=$sanitize bash "$profile/tests/platform-profile-response.sh" "$kernel/$driver"
  printf 'Responsive saver actual callbacks passed:%s/sanitize%s; no energy or physical acceptance.\n' "$cc" "$sanitize"
 done
done
for cc in gcc clang;do
 status=0
 CC=$cc SANITIZE=0 bash "$profile/tests/platform-profile-response.sh" "$work/before.c" > "$work/$cc-negative.log" 2>&1 || status=$?
 [[ $status == 134 ]]
 grep -F 'profile.cpu[i].max_value==FREQ_QOS_MAX_DEFAULT_VALUE' "$work/$cc-negative.log"
 printf 'Original minimum-frequency ceiling refused by actual responsive-saver fixture:%s/status134.\n' "$cc"
done
# Require recompilation of this exact new source, never the earlier object.
rm -f -- "$out/drivers/soc/qcom/uke-platform-profile.o"
release=$(jq -er .full_release "$profile/manifests/cumulative-release.json")
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION="-$release-unstable" KCFLAGS=-Werror W=1 -j4 drivers/soc/qcom/uke-platform-profile.o
llvm-readelf -h "$out/drivers/soc/qcom/uke-platform-profile.o" | grep -F AArch64
llvm-nm "$out/drivers/soc/qcom/uke-platform-profile.o" | awk '$3=="uke_profile_set"{found=1}END{if(!found)exit 1}'
printf '%s  %s\n' "$after" "$kernel/$driver" | sha256sum -c --strict --quiet -
printf 'Responsive saver actual AArch64 provider object passed; source experiment only, full delivery and power/latency acceptance pending.\n'

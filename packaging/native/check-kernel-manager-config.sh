#!/usr/bin/env bash
# COPR only, after the unchanged postfreeze cumulative check has passed.
set -Eeuo pipefail
trap 'status=$?; printf "Manager feature check failed at line %s: %s (status %s)\n" "$LINENO" "$BASH_COMMAND" "$status" >&2; exit "$status"' ERR
test ! -e /etc/senemos/kernel-update.conf
[[ $(uname -m) == aarch64 ]]
kernel=$(realpath "${1:?prepared cumulative kernel}")
prior=$(realpath "${2:?qualified baseline output}")
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
fragment=$owner/configs/kernel-manager/resources.config
output=$prior-manager
[[ ! -e $output ]]
for role in native cdsp waydroid; do
 before=$prior/.config
 [[ $role == native ]] || before=$kernel/native-generated/nfc-$role-reference/.config
 after=$output
 [[ $role == native ]] || after=$kernel/native-generated/manager-$role-reference
 bash "$owner/packaging/native/apply-kernel-manager-config.sh" "$kernel" "$before" "$after/.config" "$fragment"
 (cd "$kernel"; make -s O="$after" ARCH=arm64 LLVM=1 LLVM_IAS=1 olddefconfig)
 bash "$owner/tests/kernel-manager-config-contract.sh" "$before" "$after/.config" "$fragment"
 sha256sum "$before" "$after/.config"
done
bash "$kernel/native-profile/tests/nfc-cohort-config731.sh" "$output/.config" "$kernel/native-generated/manager-waydroid-reference/.config"
bash "$kernel/native-profile/tests/kernel-hardening-config-contract.sh" "$output/.config"
release=$(jq -er .kernel_release "$kernel/native-profile/source-composition.json")
objects=(kernel/sched/fair.o kernel/sched/core.o drivers/cpuidle/governors/teo.o \
 drivers/block/zram/zram_drv.o mm/zsmalloc.o mm/vmscan.o mm/damon/sysfs.o \
 block/blk-throttle.o block/blk-iolatency.o block/blk-iocost.o \
 drivers/thermal/thermal_core.o net/ipv4/tcp_bbr.o net/sched/sch_fq_codel.o net/sched/sch_fq.o)
make -C "$kernel" O="$output" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION="-${release#7.3.1-}" -j4 prepare modules_prepare
make -C "$kernel" O="$output" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION="-${release#7.3.1-}" KCFLAGS=-Werror -j4 "${objects[@]}"
for object in "${objects[@]}"; do
 test -s "$output/$object"
 llvm-readelf -h "$output/$object" | grep -E 'Machine:.*AArch64'
 sha256sum "$output/$object"
done
test ! -e "$output/arch/arm64/boot/Image"
test -z "$(find "$output" -type f -name '*.ko' -print -quit)"
printf '%s\n' 'PASS: manager features over the complete qualified post12203 union; three independent full config retention checks; unchanged full NFC/hardening gates;14 AArch64 objects' \
 'Scope: source/config/REL objects only; no full kernel, modules link, new release, installation, policy activation, suspend or physical acceptance'

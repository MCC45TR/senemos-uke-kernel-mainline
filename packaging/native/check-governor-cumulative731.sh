#!/usr/bin/env bash
# COPR only: complete cumulative Kconfig retention and four real governor objects.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $(uname -m) == aarch64 ]]
kernel=$(realpath "${1:?Prepared cumulative kernel}")
output=$(realpath -m "${2:?Object output directory}")
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
profile=$kernel/native-profile
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
export ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-12202-unstable
bash "$owner/packaging/native/overlay-governor-options731.sh" "$profile" "$kernel/boot-recipe"
bash "$profile/packaging/native/check-cumulative-camera731.sh" "$kernel" "$output" prepared
resolve()
{
    mkdir -p "$2"
    install -m644 "$1" "$2/.config"
    # Object-only check: normalize the same empty initramfs for every input.
    bash "$kernel/scripts/config" --file "$2/.config" --set-str INITRAMFS_SOURCE ''
    make -s -C "$kernel" O="$2" olddefconfig
}
resolve "$profile/native.config" "$output"
resolve "$profile/configs/governor-before-native.config" "$stage/baseline"
bash "$owner/tests/governor-config-contract.sh" "$stage/baseline/.config" "$output/.config"
for role in cdsp waydroid; do
    resolve "$profile/configs/nfc-$role-reference.config" "$stage/$role"
done
bash "$profile/tests/cdsp-pogo-config-contract.sh" "$stage/cdsp/.config"
# The original full comparator is unchanged: its only exclusion remains pogo HID.
bash "$profile/tests/nfc-cohort-config731.sh" "$output/.config" "$stage/waydroid/.config"
bash "$profile/tests/kernel-hardening-config-contract.sh" "$output/.config"
objects=(drivers/cpufreq/cpufreq_powersave.o drivers/cpufreq/cpufreq_conservative.o \
    drivers/devfreq/governor_performance.o drivers/devfreq/governor_powersave.o)
make -C "$kernel" O="$output" KCFLAGS=-Werror -j4 prepare modules_prepare "${objects[@]}"
for object in "${objects[@]}"; do
    test -s "$output/$object"
    llvm-readelf -h "$output/$object" | grep -E 'Machine:.*AArch64'
done
test ! -e "$output/arch/arm64/boot/Image"
test -z "$(find "$output" -type f -name '*.ko' -print -quit)"
sha256sum "$profile/native.config" "$output/.config" "$stage/baseline/.config" "$stage/waydroid/.config"
printf '%s\n' 'PASS: complete cumulative source preparation and native hardening gates; exact four-option effective config delta; unchanged full NFC comparator; four AArch64 governor objects with -Werror' \
    'Scope: source/config/object evidence only; no Image, final module, kernel reservation, install, boot or physical governor qualification'

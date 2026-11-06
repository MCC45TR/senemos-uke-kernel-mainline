#!/usr/bin/env bash
# COPR only: complete cumulative Kconfig retention and four real governor objects.
set -Eeuo pipefail
trap 'status=$?; printf "Governor cumulative check failed at line %s: %s (status %s)\n" "$LINENO" "$BASH_COMMAND" "$status" >&2; exit "$status"' ERR
test ! -e /etc/senemos/kernel-update.conf
[[ $(uname -m) == aarch64 ]]
kernel=$(realpath "${1:?Prepared cumulative kernel}")
output=$(realpath -m "${2:?Object output directory}")
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
profile=$kernel/native-profile
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
release=$(jq -er .kernel_release "$profile/source-composition.json")
[[ $release =~ ^7[.]3[.]1-[0-9]+-unstable$ ]]
localversion=-${release#7.3.1-}
bash "$owner/packaging/native/overlay-governor-options731.sh" "$profile" "$kernel/boot-recipe"
bash "$profile/packaging/native/check-cumulative-camera731.sh" "$kernel" "$output" prepared
resolve()
{
    mkdir -p "$2"
    install -m644 "$1" "$2/.config"
    # Match the production reference snapshot; object targets do not embed it.
    bash "$kernel/scripts/config" --file "$2/.config" --set-str INITRAMFS_SOURCE "$output/boot-initramfs.cpio.gz"
    install -m644 "$2/.config" "$2/input.config"
    (cd "$kernel"; make -s O="$2" ARCH=arm64 LLVM=1 LLVM_IAS=1 olddefconfig)
    grep -E '^CONFIG_(CC_VERSION_TEXT|CC_IS_CLANG|CC_IS_GCC|CLANG_VERSION|GCC_VERSION|PAHOLE_VERSION|INITRAMFS_SOURCE)=' "$2/.config"
}
references=$kernel/native-generated
# Match the actual successful factory's first config, location and call order.
resolve "$profile/configs/governor-before-nfc-cdsp.config" "$references/nfc-cdsp-reference"
old_snapshot_status=0
bash "$profile/tests/cdsp-pogo-config-contract.sh" "$references/nfc-cdsp-reference/.config" || old_snapshot_status=$?
install -m644 "$references/nfc-cdsp-reference/.config" "$stage/production-original.config"
printf 'Original CDSP snapshot status in production reference location: %s\n' "$old_snapshot_status"
resolve "$profile/configs/governor-before-nfc-cdsp.config" "$references/nfc-cdsp-before-reference"
diff -u "$stage/production-original.config" "$references/nfc-cdsp-before-reference/.config"
for role in cdsp waydroid; do
    resolve "$profile/configs/nfc-$role-reference.config" "$references/nfc-$role-reference"
done
bash "$owner/tests/governor-config-contract.sh" "$references/nfc-cdsp-before-reference/.config" "$references/nfc-cdsp-reference/.config"
resolve "$profile/native.config" "$output"
resolve "$profile/configs/governor-before-native.config" "$stage/baseline"
bash "$owner/tests/governor-config-contract.sh" "$stage/baseline/.config" "$output/.config"
# The original full comparator is unchanged: its only exclusion remains pogo HID.
bash "$profile/tests/nfc-cohort-config731.sh" "$output/.config" "$references/nfc-waydroid-reference/.config"
bash "$profile/tests/kernel-hardening-config-contract.sh" "$output/.config"
objects=(drivers/cpufreq/cpufreq_powersave.o drivers/cpufreq/cpufreq_conservative.o \
    drivers/devfreq/governor_performance.o drivers/devfreq/governor_powersave.o)
make -C "$kernel" O="$output" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION="$localversion" -j4 prepare modules_prepare
make -C "$kernel" O="$output" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION="$localversion" KCFLAGS=-Werror -j4 "${objects[@]}"
for object in "${objects[@]}"; do
    test -s "$output/$object"
    llvm-readelf -h "$output/$object" | grep -E 'Machine:.*AArch64'
done
test ! -e "$output/arch/arm64/boot/Image"
test -z "$(find "$output" -type f -name '*.ko' -print -quit)"
sha256sum "$profile/native.config" "$output/.config" "$stage/baseline/.config" \
    "$references/nfc-cdsp-before-reference/.config" "$references/nfc-cdsp-reference/.config" "$references/nfc-waydroid-reference/.config"
if [[ $old_snapshot_status != 0 ]]; then
    printf '%s\n' 'FAIL: historical snapshot remains mandatory; completed object/comparison diagnostics do not qualify this layer' >&2
    exit "$old_snapshot_status"
fi
printf '%s\n' 'PASS: complete cumulative source preparation and native hardening gates; exact four-option effective config delta; unchanged full NFC comparator; four AArch64 governor objects with -Werror' \
    'Scope: source/config/object evidence only; no Image, final module, kernel reservation, install, boot or physical governor qualification'

#!/usr/bin/env bash
# COPR only: execute the actual post-initramfs boot branch without an Image.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?prepared kernel}")
production=$(realpath "${2:?production output}")
profile=$kernel/native-profile
payload=$kernel/boot-recipe/src/boot/build-payload.sh
stage=$(mktemp -d "$kernel/native-generated/migration-boundary.XXXXXX")
trap 'find "$stage" -depth -delete' EXIT
mkdir "$stage/out"
cp "$production/.config" "$stage/out/.config"
awk '
 /^bash "\$kernel\/scripts\/config" --file "\$out\/\.config" --set-str INITRAMFS_SOURCE "\$out\/boot-initramfs\.cpio\.gz"$/ {emit=1}
 emit && /^make .* Image$/ {exit}
 emit {print;n++}
 END {if(n!=5)exit 1}
' "$payload" > "$stage/actual-boot-branch.sh"
(
 out=$stage/out
 here=${payload%/*}
 release=$(jq -er .kernel_release "$profile/source-composition.json")
 localversion=-${release#*-}
 export ARCH=arm64 LLVM=1 LLVM_IAS=1
 source "$stage/actual-boot-branch.sh"
)
# The historical reference must still reject the new manager composition,
# with the same explicit initramfs context on both sides.
cp "$kernel/native-generated/nfc-waydroid-reference/.config" "$stage/old-reference"
bash "$kernel/scripts/config" --file "$stage/old-reference" --set-str INITRAMFS_SOURCE "$stage/out/boot-initramfs.cpio.gz"
if bash "$profile/tests/nfc-cohort-config731.sh" "$stage/out/.config" "$stage/old-reference" > "$stage/old-refusal" 2>&1; then
 echo 'Historical manager omission was not detected' >&2; exit 1
fi
# An unrelated config mutation must be refused by the actual replacement gate.
cp "$stage/out/.config" "$stage/good.config"
[[ $(grep -c '^CONFIG_NR_CPUS=' "$stage/out/.config") == 1 ]]
! grep -Fxq CONFIG_NR_CPUS=4095 "$stage/out/.config"
sed -i 's/^CONFIG_NR_CPUS=.*/CONFIG_NR_CPUS=4095/' "$stage/out/.config"
if bash "$profile/packaging/native/check-migration-boot-config731.sh" "$kernel" "$stage/out" > "$stage/mutant-refusal" 2>&1; then
 echo 'Unrelated config mutation was admitted' >&2; exit 1
fi
cp "$stage/good.config" "$stage/out/.config"
bash "$profile/packaging/native/check-migration-boot-config731.sh" "$kernel" "$stage/out"
test ! -e "$stage/out/arch/arm64/boot/Image"
printf 'Actual boot config branch passes; historical omission and unrelated mutation both refuse; no Image built\n'

#!/usr/bin/bash
# COPR-only small object preflight before the full Image; production output is separate.
set -Eeuo pipefail
[[ $# == 1 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1");profile=$kernel/native-profile
bash "$profile/tests/audio-identity734.sh" "$profile"
out=$(mktemp -d "$kernel/native-generated/audio-identity734.XXXXXXXX")
trap 'find "$out" -depth -delete' EXIT
cp "$profile/native.config" "$out/.config"
bash "$profile/src/livepatch/configure734.sh" "$kernel" "$out/.config" "$profile"
bash "$kernel/scripts/config" --file "$out/.config" --set-str INITRAMFS_SOURCE ''
tuple=$(bash "$profile/scripts/kernel-release.sh" json "$profile/manifests/cumulative-release.json")
localversion=$(jq -er .localversion <<< "$tuple")
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION="$localversion" olddefconfig prepare modules_prepare
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION="$localversion" KCFLAGS=-Werror -j2 sound/soc/qcom/uke-audio-card.o
bash "$profile/tests/audio-identity734.sh" "$profile" "$out/sound/soc/qcom/uke-audio-card.o"
[[ ! -e $out/arch/arm64/boot/Image ]]
printf 'Small native audio object preflight passed before the full Image; no production object/config was reused or changed.\n'

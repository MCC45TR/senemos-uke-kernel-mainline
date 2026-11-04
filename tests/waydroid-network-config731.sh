#!/usr/bin/env bash
# COPR only: independently derive the network delta from the pinned parent.
set -Eeuo pipefail
[[ $# == 7 ]]
kernel=$(realpath "$1")
output=$(realpath "$2")
localversion=$3
reference=$(realpath "$4")
fragment=$(realpath "$5")
phase=$6
parent_hash=$7
[[ $phase == initial || $phase == final ]]
[[ $parent_hash =~ ^[0-9a-f]{64}$ ]]
test ! -e /etc/senemos/kernel-update.conf
export ARCH=arm64 LLVM=1
state=$output/waydroid-config-reference
if [[ $phase == initial ]]; then
 [[ ! -e $state ]]
 mkdir -p "$state/parent" "$state/expected-final" "$state/expected-initial"
 # Retain the complete parent assertion, including its final initramfs path.
 cp "$reference" "$state/parent/.config"
 bash "$kernel/scripts/config" --file "$state/parent/.config" \
  --set-str INITRAMFS_SOURCE "$output/boot-initramfs.cpio.gz"
 make -C "$kernel" O="$state/parent" LOCALVERSION="$localversion" olddefconfig
 printf '%s  %s\n' "$parent_hash" "$state/parent/.config" | sha256sum -c --strict -
 # scripts/config is independent of the source factory's awk overlay. Start
 # from the raw parent so Kconfig resolves every new dependency itself.
 cp "$reference" "$state/expected-final/.config"
 count=0
 while IFS= read -r setting; do
  [[ $setting == CONFIG_*=y ]] || continue
  symbol=${setting#CONFIG_}; symbol=${symbol%=y}
  [[ $symbol =~ ^[A-Z0-9_]+$ ]]
  bash "$kernel/scripts/config" --file "$state/expected-final/.config" --enable "$symbol"
  count=$((count+1))
 done < "$fragment"
 [[ $count -gt 30 ]]
 bash "$kernel/scripts/config" --file "$state/expected-final/.config" \
  --set-str INITRAMFS_SOURCE "$output/boot-initramfs.cpio.gz"
 cp "$state/expected-final/.config" "$state/expected-initial/.config"
 bash "$kernel/scripts/config" --file "$state/expected-initial/.config" --set-str INITRAMFS_SOURCE ''
 make -C "$kernel" O="$state/expected-final" LOCALVERSION="$localversion" olddefconfig
 make -C "$kernel" O="$state/expected-initial" LOCALVERSION="$localversion" olddefconfig
fi
printf '%s  %s\n' "$parent_hash" "$state/parent/.config" | sha256sum -c --strict -
cmp "$state/expected-$phase/.config" "$output/.config" || {
 diff -u "$state/expected-$phase/.config" "$output/.config" >&2 || true
 exit 1
}
printf 'Pinned parent and independently derived %s network configuration pass\n' "$phase"

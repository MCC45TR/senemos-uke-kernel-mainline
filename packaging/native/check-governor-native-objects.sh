#!/usr/bin/env bash
# COPR-only upstream API/object check, not a full cumulative kernel build.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $(uname -m) == aarch64 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
manifest=$owner/manifests/native-linux-7.3.1.json
archive=$owner/referances/releases/linux-7.3.1.tar.xz
mkdir -p "${archive%/*}"
curl --fail --location --silent --show-error --retry 3 --proto '=https' --proto-redir '=https' \
    "$(jq -er '.source_url' "$manifest")" -o "$archive"
printf '%s  %s\n' "$(jq -er '.source_sha256' "$manifest")" "$archive" | sha256sum -c -
tar -xJf "$archive" -C "$stage"
kernel=$stage/linux-7.3.1
make -s -C "$kernel" O="$stage/out" ARCH=arm64 defconfig
"$kernel/scripts/config" --file "$stage/out/.config" -d RUST -d DEBUG_INFO_BTF \
    -e CPU_FREQ -d CPU_FREQ_DEFAULT_GOV_PERFORMANCE -e CPU_FREQ_DEFAULT_GOV_SCHEDUTIL -e CPU_FREQ_GOV_POWERSAVE \
    -e CPU_FREQ_GOV_CONSERVATIVE -e PM_DEVFREQ -e DEVFREQ_GOV_PERFORMANCE -e DEVFREQ_GOV_POWERSAVE
make -s -C "$kernel" O="$stage/out" ARCH=arm64 olddefconfig
for symbol in CPU_FREQ_DEFAULT_GOV_SCHEDUTIL CPU_FREQ_GOV_POWERSAVE CPU_FREQ_GOV_CONSERVATIVE \
    DEVFREQ_GOV_PERFORMANCE DEVFREQ_GOV_POWERSAVE; do
    grep -Fx "CONFIG_${symbol}=y" "$stage/out/.config"
done
make -s -C "$kernel" O="$stage/out" ARCH=arm64 -j4 prepare
objects=(drivers/cpufreq/cpufreq_powersave.o drivers/cpufreq/cpufreq_conservative.o \
    drivers/devfreq/governor_performance.o drivers/devfreq/governor_powersave.o)
make -C "$kernel" O="$stage/out" ARCH=arm64 KCFLAGS=-Werror -j4 "${objects[@]}"
for object in "${objects[@]}"; do
    test -s "$stage/out/$object"
    readelf -h "$stage/out/$object" | grep -Eq 'Machine:.*AArch64'
done
printf '%s\n' 'PASS: four stock governors compile with -Werror against pinned Linux 7.3.1 AArch64 headers' \
    'Scope: upstream arm64 defconfig API/object check; cumulative config resolution, linkage, boot and physical governor selection pending'

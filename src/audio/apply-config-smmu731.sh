#!/usr/bin/env bash
# COPR only, after inherited complete13 %prep (including CDSP qualification).
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared complete12213 kernel}")
profile=$(realpath "${2:?Cumulative native profile}")
[[ $profile == "$kernel/native-profile" ]]
actual=$kernel/drivers/iommu/arm/arm-smmu/arm-smmu-qcom.c
helper=$kernel/drivers/iommu/arm/arm-smmu/uke-audio-config-smmu.c
before=$kernel/native-generated/smmu-before-audio-config.c
test -f "$kernel/native-generated/uke-oob-composed-layer"
test ! -e "$helper";test ! -e "$before"
printf '%s  %s\n' 4ff6bd3c30fa30f949f7f6c11a02f9e11abb687f15afa67d61bfb4c5731c499e "$actual" | sha256sum -c --strict -
cp "$actual" "$before"
patch -d "$kernel" --dry-run --batch --fuzz=0 -p1 -i "$profile/src/audio/0009-uke-audio-config-smmu.patch"
patch -d "$kernel" --batch --fuzz=0 -p1 -i "$profile/src/audio/0009-uke-audio-config-smmu.patch"
printf '%s  %s\n' ebebdc288110bc5eac1ab4f19e9ea8f48f6585650fdcba340e8cf47a0339cde3 "$actual" | sha256sum -c --strict -
install -m644 "$profile/src/audio/uke-audio-config-smmu.c" "$helper"
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
mkdir -p "$work/drivers/iommu/arm/arm-smmu"
cp "$actual" "$work/drivers/iommu/arm/arm-smmu/arm-smmu-qcom.c"
patch -R -d "$work" --batch --fuzz=0 -p1 -i "$profile/src/audio/0009-uke-audio-config-smmu.patch"
cmp "$work/drivers/iommu/arm/arm-smmu/arm-smmu-qcom.c" "$before"
for cc in gcc clang;do for san in 0 1;do
 CC=$cc SANITIZE=$san bash "$profile/tests/audio-config-smmu.sh" "$kernel"
done;done
printf 'Exact permanent audio supplier SMMU delta and actual allocator controls pass; physical DMA/audio remain unqualified.\n'

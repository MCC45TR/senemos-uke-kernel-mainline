#!/usr/bin/bash
# Source-only regression for RPM's build -> install -> check execution order.
set -Eeuo pipefail
[[ $# == 1 ]]
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
bash "$owner/packaging/native/fold-camera-full7347.sh" "$1" "$work/full7.spec"
awk '
 /^%build$/{phase="build"}
 /^%install$/{phase="install"}
 /^%check$/{phase="check"}
 /^# UKE_CAMERA_FULL7347_LINKED_BEGIN$/{if(phase!="build")exit 1;linked++}
 /^# UKE_CAMERA_FULL7347_INSTALL_BEGIN$/{if(phase!="install")exit 1;installs++}
 /^# UKE_CAMERA_FULL7347_CHECK_BEGIN$/{if(phase!="check")exit 1;checks++}
 END{if(linked!=1||installs!=1||checks!=1)exit 1}
' "$work/full7.spec"
kernel=$work/kernel;out=$work/out
mkdir -p "$kernel/camera-rom-report734-result" "$kernel/camera-full7347/camera-rom-report734" "$out/drivers/clk/qcom" "$out/arch/arm64/boot"
printf 'cached reporter source\n' > "$kernel/source.h"
for target in drivers/clk/qcom/camcc-sm7675.o arch/arm64/boot/Image vmlinux;do
 printf 'Uke camera ROM refusal: filesystem fixture only\n' > "$out/$target"
done
(cd "$kernel";sha256sum source.h) > "$kernel/camera-rom-report734-result/source.sha256"
for name in parent-source.sha256 current-source.sha256 native-objects.sha256 reporter-results.txt composition-results.txt qualification.json;do
 printf 'filesystem phase fixture\n' > "$kernel/camera-rom-report734-result/$name"
done
printf '{}\n' > "$work/contract.json"
printf 'source\n' > "$kernel/camera-full7347/camera-rom-report734/source-commit"
printf 'manifest\n' > "$kernel/camera-full7347/camera-rom-report734/SHA256SUMS"
for block in LINKED INSTALL CHECK;do
 awk -v begin="# UKE_CAMERA_FULL7347_${block}_BEGIN" -v end="# UKE_CAMERA_FULL7347_${block}_END" '
  $0==begin{copy=1;next}$0==end{copy=0;next}copy{print}
 ' "$work/full7.spec" |
 sed -e "s|%{_uke_out}|$out|g" -e "s|%{buildroot}|$work/buildroot|g" -e 's|%{krel}|7.3.4-7-unstable|g' -e "s|%{SOURCE220}|$work/contract.json|g" > "$work/$block.sh"
 [[ -s $work/$block.sh ]]
 ! grep -q '%{' "$work/$block.sh"
done
# Reproduce the observed failure when the installation runs before sealing.
if (cd "$kernel";bash -e "$work/INSTALL.sh") > "$work/before.log" 2>&1;then exit 1;fi
grep -Fq 'full-linked.sha256' "$work/before.log"
for phase in LINKED INSTALL CHECK;do (cd "$kernel";bash -e "$work/$phase.sh");done
support=$work/buildroot/usr/share/senemos/uke/7.3.4-7-unstable/build-support/camera-rom-report734
cmp "$support/full-linked.sha256" "$kernel/camera-rom-report734-result/full-linked.sha256"
cp "$out/arch/arm64/boot/Image" "$work/image.before"
printf 'changed\n' >> "$out/arch/arm64/boot/Image"
if (cd "$kernel";bash -e "$work/CHECK.sh") > "$work/image-refusal.log" 2>&1;then exit 1;fi
cp "$work/image.before" "$out/arch/arm64/boot/Image"
printf 'changed\n' >> "$kernel/source.h"
if (cd "$kernel";bash -e "$work/INSTALL.sh") > "$work/source-refusal.log" 2>&1;then exit 1;fi
printf 'PASS: full7 actual RPM blocks: build/install/check, missing-seal reproduction and image/source tamper refusal; no compilation or hardware\n'

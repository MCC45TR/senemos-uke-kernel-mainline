#!/usr/bin/bash
# Execute actual RPM blocks and ledger inverses; no C compilation or hardware.
set -Eeuo pipefail
[[ $# == 1 ]]
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
bash "$owner/packaging/native/fold-camera-full73410.sh" "$1" "$work/full10.spec"
awk '
 /^%build$/{phase="build"}/^%install$/{phase="install"}/^%check$/{phase="check"}
 /^# UKE_CAMERA_FULL73410_BUILD_BEGIN$/{if(phase!="build")exit 1;b++}
 /^# UKE_CAMERA_FULL73410_LINKED_BEGIN$/{if(phase!="build")exit 1;l++}
 /^# UKE_CAMERA_FULL73410_CHECK_BEGIN$/{if(phase!="check")exit 1;c++}
 /^# UKE_CAMERA_FULL73410_INSTALL_BEGIN$/{if(phase!="install")exit 1;i++}
 END{if(b!=1||l!=1||c!=1||i!=1)exit 1}
' "$work/full10.spec"
kernel=$work/kernel;out=$work/out
mkdir -p "$kernel/camera-full73410-result" "$kernel/camera-full7349-result" "$out/arch/arm64/boot" "$out/arch/arm64/kernel"
printf 'source fixture\n' > "$kernel/source.h"
(cd "$kernel";sha256sum source.h) > "$kernel/camera-full73410-result/source.sha256"
printf 'uke-front-calibration: fixture\n' > "$out/arch/arm64/boot/Image"
printf 'object fixture\n' > "$out/arch/arm64/kernel/uke-abl.o"
(cd "$out";sha256sum arch/arm64/boot/Image arch/arm64/kernel/uke-abl.o) > "$kernel/camera-full7349-result/full-linked.sha256"
for name in front-stage734 front-observed734;do
 mkdir "$kernel/$name-result"
 for file in results.txt source.sha256 native-objects.sha256 disabled-results.txt profile.sha256;do printf 'fixture\n' > "$kernel/$name-result/$file";done
done
printf '{"compiler_modes":4,"actual_arm64_objects":1,"readonly_helper_unchanged":true,"real_interconnect_tag_converter":true,"physical_camera_accepted":false}\n' > "$kernel/front-stage734-result/qualification.json"
printf '{"compiler_modes":4,"board_predicate_projection":true,"phandles_remapped":true,"contains_unit_data":false,"contains_eeprom_contents":false,"physical_camera_accepted":false}\n' > "$kernel/front-observed734-result/qualification.json"
mkdir -p "$kernel/camera-full73410/front-stage734/src/camera/front-stage734"
cp "$owner/src/camera/front-stage734/"{pre.sha256,post.sha256,late-stage.patch} "$kernel/camera-full73410/front-stage734/src/camera/front-stage734/"
printf '{}\n' > "$work/contract.json"
for block in LINKED INSTALL CHECK;do
 awk -v begin="# UKE_CAMERA_FULL73410_${block}_BEGIN" -v end="# UKE_CAMERA_FULL73410_${block}_END" '$0==begin{copy=1;next}$0==end{copy=0;next}copy{print}' "$work/full10.spec" |
 sed -e "s|%{_uke_out}|$out|g" -e "s|%{buildroot}|$work/buildroot|g" -e 's|%{krel}|7.3.4-10-unstable|g' -e "s|%{SOURCE229}|$work/contract.json|g" > "$work/$block.sh"
 [[ -s $work/$block.sh ]]
 ! grep -q '%{' "$work/$block.sh"
done
if (cd "$kernel";bash -e "$work/INSTALL.sh") > "$work/missing.log" 2>&1;then exit 1;fi
grep -Fq full-linked.sha256 "$work/missing.log"
for block in LINKED INSTALL CHECK;do (cd "$kernel";bash -e "$work/$block.sh");done
printf 'changed object\n' >> "$out/arch/arm64/kernel/uke-abl.o"
if (cd "$kernel";bash -e "$work/CHECK.sh") > "$work/object.log" 2>&1;then exit 1;fi
printf 'changed source\n' >> "$kernel/source.h"
if (cd "$kernel";bash -e "$work/INSTALL.sh") > "$work/source.log" 2>&1;then exit 1;fi
root=$work/ledgers;file=arch/arm64/kernel/uke-abl.c
mkdir -p "$root/$(dirname "$file")" "$root/front-stage734-result/fixed/before/$(dirname "$file")" "$root/super-root734-result" "$root/camera-full7349-result" "$root/front-stage734-result"
printf 'before\n' > "$root/front-stage734-result/fixed/before/$file"
(cd "$root/front-stage734-result/fixed/before";sha256sum "$file") > "$root/super-root734-result/source.sha256"
cp "$root/super-root734-result/source.sha256" "$root/camera-full7349-result/source.sha256"
for n in {0..9};do printf 'retained %s\n' "$n" > "$root/source$n.h";(cd "$root";sha256sum "source$n.h") >> "$root/camera-full7349-result/source.sha256";done
printf 'after\n' > "$root/$file"
(cd "$root";sha256sum "$file") > "$root/front-stage734-result/source.sha256"
for n in {10..12};do printf 'header %s\n' "$n" > "$root/source$n.h";(cd "$root";sha256sum "source$n.h") >> "$root/front-stage734-result/source.sha256";done
cp -a "$root" "$work/bad-inverse"
printf 'changed\n' >> "$work/bad-inverse/front-stage734-result/fixed/before/$file"
if bash "$owner/packaging/native/seal-camera-full73410.sh" "$work/bad-inverse" > "$work/inverse.log" 2>&1;then exit 1;fi
bash "$owner/packaging/native/seal-camera-full73410.sh" "$root"
[[ $(wc -l < "$root/camera-full73410-result/source.sha256") == 14 ]]
if bash "$owner/packaging/native/seal-camera-full73410.sh" "$root" > "$work/repeat.log" 2>&1;then exit 1;fi
printf 'PASS: full10 RPM phase placement, actual linked/install/check blocks, missing seal, object/source/inverse tamper, repeated-seal refusal and both complete ledger inverses\n'

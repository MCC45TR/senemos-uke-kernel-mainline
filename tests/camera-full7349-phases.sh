#!/usr/bin/bash
# PC/COPR text and RPM-phase fixtures; no compilation or device operations.
set -Eeuo pipefail
[[ $# == 1 ]]
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
bash "$owner/packaging/native/fold-camera-full7349.sh" "$1" "$work/full9.spec"
awk '
 /^%build$/{phase="build"}/^%install$/{phase="install"}/^%check$/{phase="check"}
 /^# UKE_CAMERA_FULL7349_BUILD_BEGIN$/{if(phase!="build")exit 1;builds++}
 /^# UKE_CAMERA_FULL7349_LINKED_BEGIN$/{if(phase!="build")exit 1;links++}
 /^# UKE_CAMERA_FULL7349_CHECK_BEGIN$/{if(phase!="check")exit 1;checks++}
 /^# UKE_CAMERA_FULL7349_INSTALL_BEGIN$/{if(phase!="install")exit 1;installs++}
 END{if(builds!=1||links!=1||checks!=1||installs!=1)exit 1}
' "$work/full9.spec"
kernel=$work/kernel;out=$work/out
mkdir -p "$kernel/camera-full7349-result" "$out/arch/arm64/boot" "$out/arch/arm64/kernel" "$out/drivers/clk/qcom" "$out/drivers/media/platform/qcom/camss" "$work/bin"
printf 'phase fixture\n' > "$kernel/source.h"
(cd "$kernel";sha256sum source.h) > "$kernel/camera-full7349-result/source.sha256"
for name in arch/arm64/kernel/uke-abl.o drivers/clk/qcom/camcc-sm7675.o arch/arm64/boot/Image vmlinux;do printf 'uke-front-calibration: phase fixture\n' > "$out/$name";done
for name in camss camss-csiphy camss-vfe-gen3 camss-csid camss-csid-gen3;do printf 'object phase fixture\n' > "$out/drivers/media/platform/qcom/camss/$name.o";done
printf '#!/usr/bin/bash\nprintf "00000000 T qcom_sm7675_camcc_status\\n"\n' > "$work/bin/llvm-nm"
chmod 700 "$work/bin/llvm-nm"
export PATH="$work/bin:$PATH"
for name in camss-lite734 phy-power734 csid-irq734 csid-stream734 front-eeprom734;do
 mkdir -p "$kernel/$name-result"
 for file in source.sha256 native-objects.sha256 results.txt;do printf 'phase fixture\n' > "$kernel/$name-result/$file";done
 printf '{"compiler_modes":4,"readonly_eeprom_only":true,"controller_then_quarantine_then_front":true,"physical_camera_accepted":false}\n' > "$kernel/$name-result/qualification.json"
done
mkdir -p "$kernel/camera-full7349/src/camera/front-eeprom734"
for file in pre.sha256 post.sha256 activation.patch;do cp "$owner/src/camera/front-eeprom734/$file" "$kernel/camera-full7349/src/camera/front-eeprom734/";done
printf '{}\n' > "$work/contract.json"
for block in LINKED INSTALL CHECK;do
 awk -v begin="# UKE_CAMERA_FULL7349_${block}_BEGIN" -v end="# UKE_CAMERA_FULL7349_${block}_END" '$0==begin{copy=1;next}$0==end{copy=0;next}copy{print}' "$work/full9.spec" |
 sed -e "s|%{_uke_out}|$out|g" -e "s|%{buildroot}|$work/buildroot|g" -e 's|%{krel}|7.3.4-9-unstable|g' -e "s|%{SOURCE226}|$work/contract.json|g" > "$work/$block.sh"
 [[ -s $work/$block.sh ]]
 ! grep -q '%{' "$work/$block.sh"
done
if (cd "$kernel";bash -e "$work/INSTALL.sh") > "$work/missing-seal.log" 2>&1;then exit 1;fi
grep -Fq full-linked.sha256 "$work/missing-seal.log"
for phase in LINKED INSTALL CHECK;do (cd "$kernel";bash -e "$work/$phase.sh");done
printf 'changed\n' >> "$out/arch/arm64/kernel/uke-abl.o"
if (cd "$kernel";bash -e "$work/CHECK.sh") > "$work/object-refusal.log" 2>&1;then exit 1;fi
printf 'changed\n' >> "$kernel/source.h"
if (cd "$kernel";bash -e "$work/INSTALL.sh") > "$work/source-refusal.log" 2>&1;then exit 1;fi

root=$work/ledgers
mkdir -p "$root/camera-owner734-result" "$root/super-root734-result"
printf 'unchanged owner guard\n' > "$root/guard.h"
(cd "$root";sha256sum guard.h) > "$root/camera-owner734-result/retained.sha256"
for tuple in 'camera-owner734-result drivers/clk/qcom/camcc-sm7675.c phy-power734-result' 'super-root734-result arch/arm64/kernel/uke-abl.c front-eeprom734-result';do
 read -r ledger file result <<< "$tuple"
 mkdir -p "$root/$result/inverse/$(dirname "$file")" "$root/$(dirname "$file")"
 printf 'original %s\n' "$file" > "$root/$result/inverse/$file"
 (cd "$root/$result/inverse";sha256sum "$file") > "$root/$ledger/source.sha256"
 printf 'current %s\n' "$file" > "$root/$file"
 (cd "$root";sha256sum "$file") > "$root/$result/source.sha256"
done
for name in camss-lite csid-irq csid-stream;do
 mkdir -p "$root/$name"'734-result'
 printf 'current %s\n' "$name" > "$root/$name.h"
 (cd "$root";sha256sum "$name.h") > "$root/$name"'734-result/source.sha256'
done
cp -a "$root" "$work/bad-inverse"
printf 'changed inverse\n' >> "$work/bad-inverse/phy-power734-result/inverse/drivers/clk/qcom/camcc-sm7675.c"
if bash "$owner/packaging/native/seal-camera-full7349.sh" "$work/bad-inverse" > "$work/inverse-refusal.log" 2>&1;then exit 1;fi
bash "$owner/packaging/native/seal-camera-full7349.sh" "$root"
[[ $(wc -l < "$root/camera-full7349-result/source.sha256") == 5 ]]
if bash "$owner/packaging/native/seal-camera-full7349.sh" "$root" > "$work/repeat-refusal.log" 2>&1;then exit 1;fi
printf 'PASS: full9 actual RPM phases, missing seal, object/source/inverse tamper, repeat refusal and two complete ledger inverses; no compilation or hardware\n'

#!/usr/bin/bash
# Source-only checks of actual full8 RPM blocks and exact ledger updates.
set -Eeuo pipefail
[[ $# == 1 ]]
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
bash "$owner/packaging/native/fold-camera-full7348.sh" "$1" "$work/full8.spec"
awk '
 /^%build$/{phase="build"}/^%install$/{phase="install"}/^%check$/{phase="check"}
 /^# UKE_CAMERA_FULL7348_LINKED_BEGIN$/{if(phase!="build")exit 1;linked++}
 /^# UKE_CAMERA_FULL7348_INSTALL_BEGIN$/{if(phase!="install")exit 1;installs++}
 /^# UKE_CAMERA_FULL7348_CHECK_BEGIN$/{if(phase!="check")exit 1;checks++}
 END{if(linked!=1||installs!=1||checks!=1)exit 1}
' "$work/full8.spec"
kernel=$work/kernel;out=$work/out
mkdir -p "$kernel/camera-native7348-result" "$out/drivers/clk/qcom" "$out/arch/arm64/boot"
printf 'source fixture\n' > "$kernel/source.h"
(cd "$kernel";sha256sum source.h) > "$kernel/camera-native7348-result/source.sha256"
printf '{}\n' > "$work/contract.json"
for target in drivers/clk/qcom/camcc-sm7675.o arch/arm64/boot/Image vmlinux;do printf 'crm-native-plls: filesystem phase fixture\n' > "$out/$target";done
for name in odd parent;do
 mkdir -p "$kernel/camera-$name"'734-result' "$kernel/camera-full7348/camera-$name"'734'
 for file in source.sha256 native-objects.sha256 results.txt qualification.json;do printf 'fixture\n' > "$kernel/camera-$name"'734-result/'"$file";done
 for file in source-commit SHA256SUMS;do printf 'fixture\n' > "$kernel/camera-full7348/camera-$name"'734/'"$file";done
done
printf 'fixture\n' > "$kernel/camera-parent734-result/passive-results.txt"
for block in LINKED INSTALL CHECK;do
 awk -v begin="# UKE_CAMERA_FULL7348_${block}_BEGIN" -v end="# UKE_CAMERA_FULL7348_${block}_END" '$0==begin{copy=1;next}$0==end{copy=0;next}copy{print}' "$work/full8.spec" |
 sed -e "s|%{_uke_out}|$out|g" -e "s|%{buildroot}|$work/buildroot|g" -e 's|%{krel}|7.3.4-8-unstable|g' -e "s|%{SOURCE223}|$work/contract.json|g" > "$work/$block.sh"
 [[ -s $work/$block.sh ]]
 if grep -q '%{' "$work/$block.sh";then exit 1;fi
done
if (cd "$kernel";bash -e "$work/INSTALL.sh") > "$work/before.log" 2>&1;then exit 1;fi
grep -Fq full-linked.sha256 "$work/before.log"
for phase in LINKED INSTALL CHECK;do (cd "$kernel";bash -e "$work/$phase.sh");done
cp "$out/arch/arm64/boot/Image" "$work/image.before"
printf 'changed\n' >> "$out/arch/arm64/boot/Image"
if (cd "$kernel";bash -e "$work/CHECK.sh") > "$work/image-refusal.log" 2>&1;then exit 1;fi
cp "$work/image.before" "$out/arch/arm64/boot/Image"
printf 'changed\n' >> "$kernel/source.h"
if (cd "$kernel";bash -e "$work/INSTALL.sh") > "$work/source-refusal.log" 2>&1;then exit 1;fi

root=$work/ledger
mkdir -p "$root/drivers/clk/qcom/provider" "$root/camera-owner734-result" "$root/camera-rom-report734-result"
: > "$root/camera-owner734-result/source.sha256"
for name in crm-rom crm-native crm-passive handoff registration;do
 layer=parent;[[ $name != crm-rom ]] || layer=odd
 path=drivers/clk/qcom/provider/camcc-sm7675-$name.h
 for dir in before inverse;do mkdir -p "$root/camera-${layer}734-result/$dir/$(dirname "$path")";printf 'old %s\n' "$name" > "$root/camera-${layer}734-result/$dir/$path";done
 printf 'new %s\n' "$name" > "$root/$path"
 (cd "$root";sha256sum "$path") >> "$root/camera-${layer}734-result/source.sha256"
 hash=$(sha256sum "$root/camera-${layer}734-result/before/$path" | cut -d' ' -f1)
 [[ $name == crm-passive ]] || printf '%s  %s\n' "$hash" "$path" >> "$root/camera-owner734-result/source.sha256"
 [[ $name != crm-native ]] || printf '%s  %s\n' "$hash" "$path" > "$root/camera-rom-report734-result/source.sha256"
done
printf 'unchanged\n' > "$root/drivers/clk/qcom/unchanged.c"
(cd "$root";sha256sum drivers/clk/qcom/unchanged.c) | tee -a "$root/camera-owner734-result/source.sha256" > "$root/camera-owner734-result/retained.sha256"
cp -a "$root" "$work/ledger-bad"
printf 'changed inverse\n' >> "$work/ledger-bad/camera-parent734-result/inverse/drivers/clk/qcom/provider/camcc-sm7675-handoff.h"
if bash "$owner/packaging/native/seal-camera-native7348.sh" "$work/ledger-bad" > "$work/inverse-refusal.log" 2>&1;then exit 1;fi
cp -a "$root" "$work/ledger-tamper"
printf 'changed production\n' >> "$work/ledger-tamper/drivers/clk/qcom/provider/camcc-sm7675-crm-passive.h"
if bash "$owner/packaging/native/seal-camera-native7348.sh" "$work/ledger-tamper" > "$work/post-refusal.log" 2>&1;then exit 1;fi
bash "$owner/packaging/native/seal-camera-native7348.sh" "$root"
[[ $(wc -l < "$root/camera-native7348-result/source.sha256") == 5 ]]
cmp "$root/camera-owner734-result/source.sha256" "$root/camera-native7348-result/owner-current.sha256"
if bash "$owner/packaging/native/seal-camera-native7348.sh" "$root" > "$work/repeat-refusal.log" 2>&1;then exit 1;fi
# Run the actual old projector with a modeled pre-native22 source manifest.
# A previously cached child link must follow the source view, never production.
mkdir -p "$root/camera-full7346/camera-owner734/src/camera/provider" "$root/camera-full7348/camera-parent734/src/camera/native-parent734"
cp "$owner/packaging/native/camera-full5-legacy-view734.sh" "$root/camera-full7346/"
: > "$root/Makefile"
: > "$root/camera-full7346/camera-owner734/src/camera/provider/crm-native734-pre.sha256"
for name in camcc-sm7675.c provider/camcc-sm7675-crm-ccf.h provider/camcc-sm7675-crm-transport.h provider/camcc-sm7675-handoff.h provider/camcc-sm7675-registration.h;do
 path=drivers/clk/qcom/$name
 mkdir -p "$root/camera-owner734-result/inverse/$(dirname "$path")"
 printf 'pre-native22 %s\n' "$name" > "$root/camera-owner734-result/inverse/$path"
 (cd "$root/camera-owner734-result/inverse";sha256sum "$path") >> "$root/camera-full7346/camera-owner734/src/camera/provider/crm-native734-pre.sha256"
 [[ -f $root/$path ]] || cp "$root/camera-owner734-result/inverse/$path" "$root/$path"
done
path=drivers/clk/qcom/provider/camcc-sm7675-crm-passive.h
(cd "$root/camera-parent734-result/inverse";sha256sum "$path") > "$root/camera-full7348/camera-parent734/src/camera/native-parent734/pre.sha256"
view=$(bash "$root/camera-full7346/camera-full5-legacy-view734.sh" "$root")
[[ -L $view/$path ]]
ln -s "$view/$path" "$work/cached-child-passive.h"
if cmp -s "$work/cached-child-passive.h" "$root/camera-parent734-result/inverse/$path";then exit 1;fi
old=$(sha256sum "$root/$path")
for _ in 1 2;do
 next_view=$(bash "$owner/packaging/native/project-camera-native7348.sh" "$root")
 [[ $next_view == "$view" && ! -L $view/$path && $(sha256sum "$root/$path") == "$old" ]]
 cmp "$work/cached-child-passive.h" "$root/camera-parent734-result/inverse/$path"
done
printf 'PASS: full8 actual RPM blocks: build/install/check, missing seal, source/Image/inverse tamper refusal and exact five-file/two-ledger composition; no compilation or hardware\n'

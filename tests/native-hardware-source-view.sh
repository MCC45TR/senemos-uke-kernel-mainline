#!/usr/bin/bash
# Data-only filesystem qualification; no compiler, runtime package or hardware.
set -Eeuo pipefail
project=$(cd -- "$(dirname -- "$0")/.." && pwd)
helper=${1:-$project/packaging/native/native-hardware-legacy-view733.sh}
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
kernel=$work/kernel
state=$kernel/native-generated/native-hardware733
mkdir -p "$kernel/drivers/clk/qcom" "$kernel/arch/arm64/kernel" "$state/before/drivers/clk/qcom"
printf 'source-only fixture\n' > "$kernel/Makefile"
printf 'old native source\n' > "$state/before/drivers/clk/qcom/owner.c"
printf 'new native source\n' > "$kernel/drivers/clk/qcom/owner.c"
printf 'new resource header\n' > "$kernel/drivers/clk/qcom/resource.h"
printf 'unchanged file\n' > "$kernel/drivers/clk/qcom/untouched.h"
printf '\177ELFfixture-not-executable\n' > "$kernel/vmlinux"
printf 'Image fixture, no executable code\n' > "$kernel/Image"
old=$(sha256sum "$state/before/drivers/clk/qcom/owner.c" | cut -d' ' -f1)
new=$(sha256sum "$kernel/drivers/clk/qcom/owner.c" | cut -d' ' -f1)
added=$(sha256sum "$kernel/drivers/clk/qcom/resource.h" | cut -d' ' -f1)
jq -n --arg old "$old" --arg new "$new" --arg added "$added" '[{path:"drivers/clk/qcom/owner.c",before_sha256:$old,after_sha256:$new},{path:"drivers/clk/qcom/resource.h",before_sha256:null,after_sha256:$added}]' > "$state/units.json"
jq -r '.[]|.after_sha256+"  "+.path' "$state/units.json" > "$state/after.sha256"
touch "$state/source-complete"
before=$(sha256sum "$kernel/vmlinux" "$kernel/Image")
view=$(bash "$helper" "$kernel")
cmp "$state/before/drivers/clk/qcom/owner.c" "$view/drivers/clk/qcom/owner.c"
[[ ! -e $view/drivers/clk/qcom/resource.h && ! -L $view/drivers/clk/qcom/resource.h ]]
[[ -L $view/drivers/clk/qcom/untouched.h ]]
if [[ ! -L $view/vmlinux || ! -L $view/Image ]];then
 printf 'ELF/Image must remain original symlinks, never replacement copies\n' >&2
 exit 1
fi
[[ $(realpath "$view/vmlinux") == "$kernel/vmlinux" && $(realpath "$view/Image") == "$kernel/Image" ]]
[[ $(bash "$helper" "$kernel") == "$view" ]]
[[ $(sha256sum "$kernel/vmlinux" "$kernel/Image") == "$before" ]]
printf 'tampered preimage view\n' > "$view/drivers/clk/qcom/owner.c"
if bash "$helper" "$kernel" > "$work/view-tampered.stdout" 2> "$work/view-tampered.stderr";then
 printf 'Tampered preimage view unexpectedly admitted\n' >&2;exit 1
fi
[[ ! -s $work/view-tampered.stdout ]]
cp "$state/before/drivers/clk/qcom/owner.c" "$view/drivers/clk/qcom/owner.c"
[[ $(bash "$helper" "$kernel") == "$view" ]]
printf 'tampered source\n' > "$kernel/drivers/clk/qcom/owner.c"
if bash "$helper" "$kernel" > "$work/tampered.stdout" 2> "$work/tampered.stderr";then
 printf 'Tampered source unexpectedly admitted\n' >&2;exit 1
fi
[[ ! -s $work/tampered.stdout ]]
printf 'Native source view: exact preimage, absent additions, unchanged symlinks, idempotence and postimage-tamper refusal pass; ELF/Image bytes untouched\n'
if [[ ${NATIVE_HARDWARE_VIEW_SKIP_MUTATION:-0} != 1 ]];then
 node - "$helper" "$work/copy-elf-mutant.sh" <<'JS'
const fs=require('fs'),[i,o]=process.argv.slice(2),s=fs.readFileSync(i,'utf8'),old='else ln -s "$entry" "$view/$child";fi';if(s.split(old).length!==2)throw Error('View mutation anchor');fs.writeFileSync(o,s.replace(old,()=> 'else if [[ $child == vmlinux ]];then cp "$entry" "$view/$child";else ln -s "$entry" "$view/$child";fi;fi'));
JS
 if NATIVE_HARDWARE_VIEW_SKIP_MUTATION=1 bash "$0" "$work/copy-elf-mutant.sh" > "$work/mutant.stdout" 2> "$work/mutant.stderr";then
  printf 'ELF-copy mutant unexpectedly admitted\n' >&2;exit 1
 fi
 grep -Fq 'ELF/Image must remain original symlinks' "$work/mutant.stderr"
 printf 'ELF-copy mutation refused by actual source-view fixture\n'
fi

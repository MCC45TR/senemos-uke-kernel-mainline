#!/usr/bin/bash
# COPR only: actual FDT converter and caller, no calibration or device access.
set -Eeuo pipefail
[[ $# == 4 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1");out=$(realpath "$2");owner=$(realpath "$3");result=$(realpath -m "$4")
bash "$owner/src/camera/front-eeprom734/apply.sh" "$kernel" "$owner" "$result"
node - "$kernel/arch/arm64/kernel/uke-abl.c" <<'JS'
const fs=require('fs'),assert=require('assert/strict'),s=fs.readFileSync(process.argv[2],'utf8');
const calls=['ret = uke_camcc_controller_graph(output);','ret = uke_scope_qup_buses(output);','ret = uke_front_eeprom_graph(output);'];
let last=-1;for(const call of calls){assert.equal(s.split(call).length,2);const pos=s.indexOf(call);assert(pos>last);last=pos;}
assert(!s.includes('EEPROM activation awaits an isolated controller boot.'));
assert(s.includes('if (1 >= 1) {\n\tret = uke_camcc_controller_graph(output);'));
JS
model=$result/model
mkdir -p "$model/src/boot" "$model/src/camera/eeprom" "$model/tests/fixtures"
cp "$kernel/arch/arm64/kernel/uke-abl.c" "$model/src/boot/"
cp "$kernel/arch/arm64/kernel/uke-front-eeprom-dt.h" "$model/src/camera/eeprom/"
cp "$kernel/boot-recipe/tests/front-eeprom-fdt731-contract.sh" "$model/tests/"
cp "$kernel/boot-recipe/tests/fixtures/front-eeprom-fdt-check.c" "$model/tests/fixtures/"
for compiler in gcc clang;do
 for mode in plain sanitized;do
  flags=-UNDEBUG
  [[ $mode != sanitized ]] || flags+=' -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer'
  CC=$compiler FRONT_EEPROM_TEST_FLAGS="$flags" bash "$model/tests/front-eeprom-fdt731-contract.sh" >> "$result/results.txt"
 done
done
[[ $(grep -c '^Actual front EEPROM FDT:' "$result/results.txt") == 4 ]]
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCFLAGS=-Werror -j2 arch/arm64/kernel/uke-abl.o
llvm-readelf -h "$out/arch/arm64/kernel/uke-abl.o" | grep -F AArch64
grep -aqF uke-front-calibration "$out/arch/arm64/kernel/uke-abl.o"
sha256sum "$out/arch/arm64/kernel/uke-abl.o" > "$result/native-objects.sha256"
(cd "$kernel";sha256sum -c --strict --quiet "$result/source.sha256")
jq -n '{schema_version:1,compiler_modes:4,actual_arm64_objects:1,controller_then_quarantine_then_front:true,readonly_eeprom_only:true,existing_fdt_refusals_retained:true,physical_device_accessed:false,physical_camera_accepted:false}' > "$result/qualification.json"
cat "$result/results.txt"

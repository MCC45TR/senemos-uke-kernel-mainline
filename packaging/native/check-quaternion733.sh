#!/usr/bin/bash
# Real callbacks, binding and fresh ARM64 objects; no target compilation.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
out=$(realpath -m "${2:?Native output}")
profile=$kernel/native-profile
bash "$profile/src/sensors/apply-quaternion733.sh" "$kernel"
bash "$profile/tests/ssc-quaternion.sh" "$kernel"
dt-doc-validate "$kernel/Documentation/devicetree/bindings/firmware/xiaomi,uke-ssc-sensors.yaml"
node - "$kernel" <<'NODE'
const fs=require('fs'),p=process.argv[2],old=p+'/native-generated/ssc-quaternion733/before',header='arch/arm64/kernel/uke-hardware.h',binding='Documentation/devicetree/bindings/firmware/xiaomi,uke-ssc-sensors.yaml',abi='Documentation/ABI/testing/sysfs-driver-uke-ssc';
const lines=['\t\tUKE_SENSOR("rotation-vector", "ENU rotation vector", "rotv", "SSC firmware fusion"),\n','\t\tUKE_SENSOR("game-rotation-vector", "Relative rotation vector", "game_rv", "SSC firmware fusion"),\n','\t\tUKE_SENSOR("geomagnetic-rotation-vector", "Geomagnetic ENU rotation vector", "geomag_rv", "SSC firmware fusion"),\n'];
let h=fs.readFileSync(p+'/'+header,'utf8');for(const line of lines){if(h.split(line).length!==2)throw Error('Missing or repeated firmware declaration');h=h.replace(line,'');}if(h!==fs.readFileSync(old+'/'+header,'utf8'))throw Error('Unrelated hardware changed');
let b=fs.readFileSync(p+'/'+binding,'utf8').replace('|gravity|rotation-vector|game-rotation-vector|geomagnetic-rotation-vector)$','|gravity)$').replace(', gravity, rotv, game_rv, geomag_rv]',', gravity]');if(b!==fs.readFileSync(old+'/'+binding,'utf8'))throw Error('Unrelated binding changed');
const a=fs.readFileSync(p+'/'+abi,'utf8');if(a.split('from 0 through 12').length!==5||a.replaceAll('from 0 through 12','from 0 through 9')!==fs.readFileSync(old+'/'+abi,'utf8'))throw Error('Unrelated ABI changed');
const driver=fs.readFileSync(p+'/drivers/iio/common/uke-ssc/uke-ssc-iio.c','utf8');if(!driver.includes('static const struct iio_info ssc_iio_info = { .read_raw_multi = ssc_read_raw_multi };'))throw Error('Actual IIO callback table missing');
console.log('Quaternion DT: three firmware declarations, matching binding alternatives and count bounds only; all existing board text retained.');
NODE
(cd "$kernel";sha256sum -c --strict --quiet native-generated/ssc-quaternion733/applied.sha256)
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-14-unstable KCFLAGS=-Werror W=1 -j4 drivers/iio/common/uke-ssc/uke-ssc.o arch/arm64/kernel/uke-abl.o
for object in drivers/iio/common/uke-ssc/uke-ssc arch/arm64/kernel/uke-abl;do llvm-readelf -h "$out/$object.o" | grep -F AArch64;done
llvm-nm "$out/drivers/iio/common/uke-ssc/uke-ssc.o" > "$kernel/native-generated/ssc-quaternion733/ssc.symbols"
for symbol in input_register_device input_event;do grep -Eq "[[:space:]]U[[:space:]]+$symbol$" "$kernel/native-generated/ssc-quaternion733/ssc.symbols";done
printf 'Actual fresh ARM64 SSC/early-DT quaternion objects and retained proximity imports pass; fitted fusion endpoints/frames/heading/power remain unaccepted.\n'

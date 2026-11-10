#!/usr/bin/bash
# Focused actual callback, schema and fresh ARM64 proof; no device requests.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
out=$(realpath -m "${2:?Native output}")
profile=$kernel/native-profile
bash "$profile/src/sensors/apply-gravity733.sh" "$kernel"
bash "$profile/tests/ssc-gravity.sh" "$kernel"
dt-doc-validate "$kernel/Documentation/devicetree/bindings/firmware/xiaomi,uke-ssc-sensors.yaml"
# The public schema must admit only the new logical endpoint beside prior nodes.
node - "$kernel" <<'NODE'
const fs=require('fs'),p=process.argv[2],old=p+'/native-generated/ssc-gravity733/before',driver='drivers/iio/common/uke-ssc/uke-ssc-iio.c',native='arch/arm64/kernel/uke-abl-native.h',binding='Documentation/devicetree/bindings/firmware/xiaomi,uke-ssc-sensors.yaml';
let n=fs.readFileSync(p+'/'+native,'utf8'),b=fs.readFileSync(p+'/'+binding,'utf8');
const line='\t\tUKE_SENSOR("gravity", "Gravity and linear acceleration", "gravity", "SSC firmware fusion"),\n';if(n.split(line).length!==2||n.replace(line,'')!==fs.readFileSync(old+'/'+native,'utf8'))throw Error('Unrelated DT ownership changed');
b=b.replace('|sensor-temperature|gravity)$','|sensor-temperature)$').replace(', sar, sensor_temperature, gravity]',', sar, sensor_temperature]');if(b!==fs.readFileSync(old+'/'+binding,'utf8'))throw Error('Existing binding changed');
for(const path of [driver,native,binding])if(!fs.statSync(p+'/'+path).isFile())throw Error('Missing prepared source');
console.log('Gravity DT: one firmware description and two schema alternatives only; existing sensor/Hall/panel resource text retained.');
NODE
(cd "$kernel";sha256sum -c --strict --quiet native-generated/ssc-gravity733/applied.sha256)
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-13-unstable KCFLAGS=-Werror W=1 -j4 drivers/iio/common/uke-ssc/uke-ssc.o arch/arm64/kernel/uke-abl.o
for object in drivers/iio/common/uke-ssc/uke-ssc arch/arm64/kernel/uke-abl;do
 llvm-readelf -h "$out/$object.o" | grep -F AArch64
done
llvm-nm "$out/drivers/iio/common/uke-ssc/uke-ssc.o" > "$kernel/native-generated/ssc-gravity733/ssc.symbols"
for symbol in input_register_device input_event;do grep -Eq "[[:space:]]U[[:space:]]+$symbol$" "$kernel/native-generated/ssc-gravity733/ssc.symbols";done
printf 'Actual fresh ARM64 SSC/early-DT gravity objects and retained proximity symbols pass; fitted endpoints, units/axes, power and restart/suspend remain physical acceptance.\n'

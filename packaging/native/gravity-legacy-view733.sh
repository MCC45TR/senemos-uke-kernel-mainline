#!/usr/bin/bash
# Data-only authenticated parent projection. Actual objects always stay new.
set -Eeuo pipefail
[[ $# == 1 ]]
kernel=$(realpath "$1")
profile=$kernel/native-profile
work=$kernel/native-generated/ssc-gravity733
[[ -s $work/applied.sha256 ]]
(cd "$kernel";sha256sum -c --strict --quiet "$work/applied.sha256")
inverse=$(mktemp -d)
trap 'find "$inverse" -depth -delete' EXIT
for file in drivers/iio/common/uke-ssc/uke-ssc-iio.c arch/arm64/kernel/uke-hardware.h Documentation/devicetree/bindings/firmware/xiaomi,uke-ssc-sensors.yaml Documentation/ABI/testing/sysfs-driver-uke-ssc;do
 install -Dm644 "$kernel/$file" "$inverse/$file"
done
git -C "$inverse" init -q
for patch in 0013-ssc-gravity-observation-abi.patch 0012-ssc-gravity-native-dt.patch 0011-ssc-gravity-linear-input.patch;do
 git -C "$inverse" apply -R --check --whitespace=error "$profile/src/sensors/$patch"
 git -C "$inverse" apply -R --whitespace=error "$profile/src/sensors/$patch"
done
for file in drivers/iio/common/uke-ssc/uke-ssc-iio.c arch/arm64/kernel/uke-hardware.h Documentation/devicetree/bindings/firmware/xiaomi,uke-ssc-sensors.yaml Documentation/ABI/testing/sysfs-driver-uke-ssc;do
 cmp "$work/before/$file" "$inverse/$file"
done
printf '%s  %s\n' "$(jq -er .driver_before_sha256 "$profile/manifests/ssc-gravity-20261110.json")" "$inverse/drivers/iio/common/uke-ssc/uke-ssc-iio.c" | sha256sum -c --strict --quiet -
view=$(mktemp -d "$kernel/native-generated/gravity-parent-view.XXXXXX")
node - "$kernel" "$view" "$inverse" <<'NODE'
const fs=require('fs'),path=require('path'),[kernel,view,inverse]=process.argv.slice(2);
const changed=['drivers/iio/common/uke-ssc/uke-ssc-iio.c','arch/arm64/kernel/uke-hardware.h','Documentation/devicetree/bindings/firmware/xiaomi,uke-ssc-sensors.yaml','Documentation/ABI/testing/sysfs-driver-uke-ssc'];
function project(relative){
 const source=path.join(kernel,relative),target=path.join(view,relative);
 if(changed.includes(relative)){fs.copyFileSync(path.join(inverse,relative),target);return;}
 if(relative===''||changed.some(p=>p.startsWith(relative+'/'))){
  if(relative)fs.mkdirSync(target);
  for(const name of fs.readdirSync(source)){if(name==='.git')continue;project(relative?relative+'/'+name:name);}
 }else fs.symlinkSync(source,target);
}
project('');
for(const p of changed)if(!fs.readFileSync(path.join(view,p)).equals(fs.readFileSync(path.join(inverse,p))))throw Error('Parent projection changed');
NODE
git -C "$view" init -q
(cd "$kernel";sha256sum -c --strict --quiet "$work/applied.sha256")
printf '%s\n' "$view"
